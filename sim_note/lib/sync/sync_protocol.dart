import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/note.dart';

// ── 메시지 타입 상수 ────────────────────────────────────────
const kHello        = 'hello';
const kPinRequired  = 'pin_required';
const kTrusted      = 'trusted';
const kPin          = 'pin';
const kPinOk        = 'pin_ok';
const kPinWrong     = 'pin_wrong';
const kSyncRequest  = 'sync_request';
const kSyncResult   = 'sync_result';
const kError        = 'error';

// ── JSON-Lines 송수신 헬퍼 ──────────────────────────────────

void sendMsg(Socket socket, Map<String, dynamic> msg) {
  socket.write('${jsonEncode(msg)}\n');
}

/// 소켓에서 한 줄(= 메시지 1개)씩 읽어 스트림으로 반환
Stream<Map<String, dynamic>> receiveMsg(Socket socket) {
  return socket
      .cast<List<int>>()
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .where((line) => line.trim().isNotEmpty)
      .map((line) => jsonDecode(line) as Map<String, dynamic>);
}

// ── 노트 직렬화 ─────────────────────────────────────────────

Map<String, dynamic> noteToMap(
  Note note,
  String notebookName,
  List<String> tagNames,
) {
  return {
    'syncId':        note.syncId ?? const Uuid().v4(),
    'notebookName':  notebookName,
    'title':         note.title,
    'body':          note.body,
    'isFavorite':    note.isFavorite,
    'createdAt':     note.createdAt.toUtc().toIso8601String(),
    'updatedAt':     note.updatedAt.toUtc().toIso8601String(),
    'tags':          tagNames,
  };
}
