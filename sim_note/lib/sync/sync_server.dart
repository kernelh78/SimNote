import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../database/db_service.dart';
import 'device_identity.dart';
import 'sync_protocol.dart';
import 'trusted_devices.dart';

typedef OnPinRequired = void Function(String pin, String clientName);
typedef OnSyncDone    = void Function(int count);
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
    String? pendingClientId;

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
              sendMsg(client, {'type': kTrusted, 'deviceId': myId});
            } else {
              pendingPin = _generatePin();
              sendMsg(client, {'type': kPinRequired, 'deviceId': myId});
              onPinRequired?.call(pendingPin!, clientName);
            }

          case kPin:
            final entered = msg['pin'] as String;
            if (entered == pendingPin && pendingClientId != null) {
              await TrustedDevices.trust(pendingClientId!);
              sendMsg(client, {'type': kPinOk});
            } else {
              sendMsg(client, {'type': kPinWrong});
            }
            pendingPin = null;

          case kSyncRequest:
            final remote = (msg['notes'] as List).cast<Map<String, dynamic>>();
            final changed = await DbService.mergeRemoteNotes(remote);

            // 내 전체 노트를 응답으로 보냄
            final myNotes = await DbService.getAllNotesForSync();
            sendMsg(client, {'type': kSyncResult, 'notes': myNotes});

            onSyncDone?.call(changed);
            await client.close();
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
