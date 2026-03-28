import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../database/db_service.dart';
import 'device_identity.dart';
import 'sync_protocol.dart';
import 'sync_server.dart';
import 'trusted_devices.dart';

enum ConnectResult { pinRequired, trusted, pinWrong, error }

class SyncClient {
  static const Duration _timeout = Duration(seconds: 10);

  /// 서버에 연결하고 인증 단계까지 처리
  /// [onPinNeeded] : PIN 입력이 필요할 때 호출 — Future<String?>을 반환 (null이면 취소)
  /// 반환값 : 동기화된 노트 수, 실패 시 예외 throw
  static Future<int> connect({
    required String ip,
    int port = SyncServer.port, // 항상 고정 포트 사용
    required Future<String?> Function() onPinNeeded,
  }) async {
    final myId   = await DeviceIdentity.getId();
    final myName = Platform.localHostname;

    late Socket socket;
    try {
      socket = await Socket.connect(
        ip, port,
        timeout: _timeout,
      );
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
      final response = await incoming.first.timeout(_timeout);
      final responseType = response['type'] as String;
      final serverId = response['deviceId'] as String? ?? '';

      if (responseType == kPinRequired) {
        // 3. PIN 입력 요청
        final pin = await onPinNeeded();
        if (pin == null) throw '사용자가 취소했습니다';

        sendMsg(socket, {'type': kPin, 'pin': pin});

        final pinResult = await incoming.first.timeout(_timeout);
        if (pinResult['type'] != kPinOk) throw '잘못된 PIN입니다';

        await TrustedDevices.trust(serverId);
      } else if (responseType != kTrusted) {
        throw '알 수 없는 응답: $responseType';
      }

      // 4. 동기화 요청
      final myNotes = await DbService.getAllNotesForSync();
      sendMsg(socket, {'type': kSyncRequest, 'notes': myNotes});

      // 5. 병합 결과 수신
      final syncResult = await incoming.first.timeout(_timeout);
      if (syncResult['type'] != kSyncResult) throw '동기화 응답 오류';

      final remoteNotes =
          (syncResult['notes'] as List).cast<Map<String, dynamic>>();
      final changed = await DbService.mergeRemoteNotes(remoteNotes);

      debugPrint('[SyncClient] 동기화 완료: $changed개 변경');
      return changed;
    } finally {
      socket.destroy();
    }
  }
}
