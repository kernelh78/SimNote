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

typedef OnPinRequired = void Function(String pin, String clientName);
typedef OnSyncDone    = void Function(int count, List<SyncConflict> conflicts);
typedef OnError       = void Function(String msg);

class SyncServer {
  static const int port = 8765;

  ServerSocket? _server;
  OnPinRequired? onPinRequired;
  OnSyncDone?    onSyncDone;
  OnError?       onError;

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
    debugPrint('[SyncServer] 연결: ${client.remoteAddress.address}');
    final myId = await DeviceIdentity.getId();
    String? pendingPin;
    String? pendingSalt;
    String? pendingClientId;
    Uint8List? sessionKey;

    try {
      await for (final msg in receiveMsg(client)) {
        final type = msg['type'] as String;
        debugPrint('[SyncServer] 수신: $type');

        switch (type) {
          case kHello:
            final clientId   = msg['deviceId'] as String;
            final clientName = msg['name'] as String? ?? '알 수 없는 기기';
            pendingClientId  = clientId;

            if (await TrustedDevices.isTrusted(clientId)) {
              sessionKey = await TrustedDevices.getKey(clientId);
              sendMsg(client, {'type': kTrusted, 'deviceId': myId});
            } else {
              pendingPin  = _generatePin();
              pendingSalt = SyncCrypto.randomSalt();
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
              sessionKey = SyncCrypto.deriveKey(entered, pendingSalt);
              await TrustedDevices.trust(pendingClientId, sessionKey);
              sendMsg(client, {'type': kPinOk});
            } else {
              sendMsg(client, {'type': kPinWrong});
            }
            pendingPin  = null;
            pendingSalt = null;

          case kEncrypted:
            if (sessionKey == null) {
              sendMsg(client, {'type': kError, 'message': '세션 키 없음'});
              break;
            }
            final inner = decryptMsg(msg, sessionKey);
            final innerType = inner['type'] as String;

            if (innerType == kSyncRequest) {
              final remote =
                  (inner['notes'] as List).cast<Map<String, dynamic>>();
              final result = await DbService.mergeRemoteNotes(remote);

              final myNotes = await DbService.getAllNotesForSync();
              sendEncrypted(client,
                  {'type': kSyncResult, 'notes': myNotes}, sessionKey);

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
      client.destroy();
    }
  }

  String _generatePin() {
    final rng = Random.secure();
    return List.generate(6, (_) => rng.nextInt(10)).join();
  }
}
