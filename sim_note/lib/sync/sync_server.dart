import 'dart:async';
import 'dart:io';
import 'dart:math';
// dart:typed_data provided via flutter/foundation.dart
import 'package:flutter/foundation.dart';
import '../database/db_service.dart';
import 'device_identity.dart';
import 'sync_conflict.dart';
import 'sync_crypto.dart';
import 'sync_protocol.dart';
import 'sync_state_store.dart';
import 'trusted_devices.dart';

typedef OnPinRequired   = void Function(String pin, String clientName);
typedef OnSyncDone      = void Function(int count, List<SyncConflict> conflicts);
typedef OnError         = void Function(String msg);
/// 알 수 없는 기기 연결 시도 알림.
/// UI에서 허용(true) 또는 차단(false)을 결정하면 Future를 완료시킴.
typedef OnUnknownDevice = Future<bool> Function(String deviceId, String deviceName);
/// 현재 다른 연결을 처리 중인지 반환. true면 새 연결 거부.
typedef IsBusy = bool Function();

class SyncServer {
  static const int port = 8765;

  ServerSocket?   _server;
  OnPinRequired?  onPinRequired;
  OnSyncDone?     onSyncDone;
  OnError?        onError;
  OnUnknownDevice? onUnknownDevice;
  IsBusy?         isBusy;

  Future<void> start() async {
    await stop();
    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      debugPrint('[SyncServer] 서버 시작: 포트 $port');
      _server!.listen(_handleConnection, onError: (e) {
        debugPrint('[SyncServer] 서버 오류: $e');
      });
    } catch (e) {
      debugPrint('[SyncServer] 서버 시작 실패: $e');
    }
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
  }

  Future<void> _handleConnection(Socket client) async {
    // 이미 다른 연결을 처리 중이면 즉시 거부 (레이스 컨디션 방지)
    if (isBusy?.call() == true) {
      debugPrint('[SyncServer] 바쁜 상태 — 연결 거부: ${client.remoteAddress.address}');
      try {
        sendMsg(client, {'type': kRejected, 'reason': 'busy'});
        await client.close();
      } catch (_) {}
      client.destroy();
      return;
    }
    debugPrint('[SyncServer] 연결: ${client.remoteAddress.address}');
    final myId = await DeviceIdentity.getId();
    String? pendingPin;
    String? pendingSalt;
    String? pendingClientId;
    Uint8List? sessionKey;
    int pinAttempts = 0;         // 잘못된 PIN 시도 횟수
    Timer? pinExpiry;            // PIN 5분 만료 타이머

    try {
      await for (final msg in receiveMsg(client)) {
        final type = msg['type'] as String;
        debugPrint('[SyncServer] 수신: $type');


        switch (type) {
          case kHello:
            final clientId   = msg['deviceId'] as String;
            final clientName = msg['name'] as String? ?? '알 수 없는 기기';
            pendingClientId  = clientId;

            // 1. 차단된 기기 즉시 거부
            if (await TrustedDevices.isBlocked(clientId)) {
              debugPrint('[SyncServer] 차단된 기기 접근 거부: $clientName ($clientId)');
              sendMsg(client, {'type': kRejected, 'reason': 'blocked'});
              await client.close();
              return;
            }

            final storedKey  = await TrustedDevices.getKey(clientId);
            final hasValidKey = storedKey != null && storedKey.isNotEmpty;

            if (hasValidKey) {
              // 2. 신뢰 기기 → 바로 연결
              sessionKey = storedKey;
              sendMsg(client, {'type': kTrusted, 'deviceId': myId});
            } else {
              // 3. 알 수 없는 기기 → UI에서 허용/차단 결정 대기
              final allowed = await _askUnknownDevice(clientId, clientName);
              if (!allowed) {
                debugPrint('[SyncServer] 사용자가 차단: $clientName');
                sendMsg(client, {'type': kRejected, 'reason': 'denied'});
                await client.close();
                return;
              }

              // 허용 → PIN 흐름 진행
              pendingPin  = _generatePin();
              pendingSalt = SyncCrypto.randomSalt();
              pinAttempts = 0;
              // PIN 5분 후 자동 만료
              pinExpiry?.cancel();
              pinExpiry = Timer(const Duration(minutes: 5), () {
                debugPrint('[SyncServer] PIN 만료 — 연결 종료');
                try { sendMsg(client, {'type': kRejected, 'reason': 'pin_expired'}); } catch (_) {}
                client.destroy();
              });
              sendMsg(client, {
                'type':     kPinRequired,
                'deviceId': myId,
                'salt':     pendingSalt,
              });
              onPinRequired?.call(pendingPin, clientName);
            }

          case kPin:
            final entered = msg['pin'] as String;
            if (entered == pendingPin &&
                pendingSalt != null &&
                pendingClientId != null) {
              pinExpiry?.cancel();
              pinExpiry  = null;
              sessionKey = SyncCrypto.deriveKey(entered, pendingSalt);
              await TrustedDevices.trust(pendingClientId, sessionKey);
              sendMsg(client, {'type': kPinOk});
              pendingPin  = null;
              pendingSalt = null;
            } else {
              pinAttempts++;
              debugPrint('[SyncServer] 잘못된 PIN ($pinAttempts/3)');
              if (pinAttempts >= 3) {
                // 3회 실패 — 연결 차단
                debugPrint('[SyncServer] PIN 3회 실패 — 연결 종료');
                pinExpiry?.cancel();
                sendMsg(client, {'type': kRejected, 'reason': 'pin_failed'});
                await client.close();
                return;
              }
              sendMsg(client, {'type': kPinWrong});
            }

          case kEncrypted:
            if (sessionKey == null) {
              sendMsg(client, {'type': kError, 'message': '세션 키 없음'});
              break;
            }
            final inner     = decryptMsg(msg, sessionKey);
            final innerType = inner['type'] as String;

            if (innerType == kSyncRequest) {
              final remote =
                  (inner['notes'] as List).cast<Map<String, dynamic>>();
              final result = await DbService.mergeRemoteNotes(remote);

              final myNotes = await DbService.getAllNotesForSync();
              sendEncrypted(
                  client, {'type': kSyncResult, 'notes': myNotes}, sessionKey);

              await SyncStateStore.setLastSyncAt(DateTime.now());
              onSyncDone?.call(result.changed, result.conflicts);
              await client.close();
            }
        }
      }
    } catch (e) {
      debugPrint('[SyncServer] 처리 오류: $e');
      onError?.call('연결 오류: $e');
    } finally {
      pinExpiry?.cancel();
      client.destroy();
    }
  }

  /// UI 콜백이 없으면 기본값 허용 (기존 동작 유지)
  Future<bool> _askUnknownDevice(String deviceId, String deviceName) async {
    final cb = onUnknownDevice;
    if (cb == null) return true;
    return cb(deviceId, deviceName);
  }

  String _generatePin() {
    final rng = Random.secure();
    return List.generate(6, (_) => rng.nextInt(10)).join();
  }
}
