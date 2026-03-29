import 'dart:async';
import 'dart:io';
// dart:typed_data provided via flutter/foundation.dart
import 'package:flutter/foundation.dart';
import '../database/db_service.dart';
import 'device_identity.dart';
import 'sync_conflict.dart';
import 'sync_crypto.dart';
import 'sync_protocol.dart';
import 'sync_server.dart';
import 'sync_state_store.dart';
import 'trusted_devices.dart';

enum ConnectResult { pinRequired, trusted, pinWrong, error }

class SyncClient {
  static const Duration _timeout = Duration(seconds: 10);

  /// 서버에 연결하고 인증 + 암호화 동기화까지 처리
  static Future<({int changed, List<SyncConflict> conflicts})> connect({
    required String ip,
    int port = SyncServer.port,
    required Future<String?> Function() onPinNeeded,
  }) async {
    final myId   = await DeviceIdentity.getId();
    final myName = Platform.localHostname;

    late Socket socket;
    try {
      socket = await Socket.connect(ip, port, timeout: _timeout);
      debugPrint('[SyncClient] 연결 성공: $ip:$port');
    } catch (e) {
      throw '기기에 연결할 수 없습니다: $e';
    }

    try {
      final incoming = receiveMsg(socket).asBroadcastStream();

      // 1. Hello 전송
      sendMsg(socket, {
        'type':     kHello,
        'deviceId': myId,
        'name':     myName,
      });

      // 2. 서버 응답 수신
      final response     = await incoming.first.timeout(_timeout);
      final responseType = response['type'] as String;
      final serverId     = response['deviceId'] as String? ?? '';

      late Uint8List sessionKey;

      if (responseType == kPinRequired) {
        // 3a. PIN 교환 + 세션 키 파생
        final salt = response['salt'] as String? ?? '';
        final pin  = await onPinNeeded();
        if (pin == null) throw '사용자가 취소했습니다';

        sendMsg(socket, {'type': kPin, 'pin': pin});

        final pinResult = await incoming.first.timeout(_timeout);
        if (pinResult['type'] != kPinOk) throw '잘못된 PIN입니다';

        sessionKey = SyncCrypto.deriveKey(pin, salt);
        await TrustedDevices.trust(serverId, sessionKey);

      } else if (responseType == kTrusted) {
        // 3b. 기존 신뢰 기기 — 저장된 키 사용
        final stored = await TrustedDevices.getKey(serverId);
        if (stored == null || stored.isEmpty) {
          throw '저장된 세션 키가 없습니다. 다시 PIN 인증이 필요합니다.';
        }
        sessionKey = stored;

      } else {
        throw '알 수 없는 응답: $responseType';
      }

      // 4. 동기화 요청 — 암호화 전송
      final myNotes = await DbService.getAllNotesForSync();
      sendEncrypted(socket, {'type': kSyncRequest, 'notes': myNotes}, sessionKey);

      // 5. 암호화된 결과 수신 + 복호화
      final envelope = await incoming.first.timeout(_timeout);
      if (envelope['type'] != kEncrypted) throw '동기화 응답 오류';

      final syncResult   = decryptMsg(envelope, sessionKey);
      final remoteNotes  =
          (syncResult['notes'] as List).cast<Map<String, dynamic>>();
      final result = await DbService.mergeRemoteNotes(remoteNotes);

      await SyncStateStore.setLastSyncAt(DateTime.now());
      debugPrint('[SyncClient] 동기화 완료: ${result.changed}개 변경, '
          '${result.conflicts.length}개 충돌');
      return result;
    } finally {
      socket.destroy();
    }
  }
}
