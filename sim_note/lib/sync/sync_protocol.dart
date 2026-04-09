import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import 'sync_crypto.dart';

// ── 암호화 송수신 헬퍼 ──────────────────────────────────────

/// [msg]를 [key]로 암호화해 `{type: encrypted, data: ...}` 형태로 전송한다.
void sendEncrypted(Socket socket, Map<String, dynamic> msg, Uint8List key) {
  final payload = SyncCrypto.encryptJson(msg, key);
  sendMsg(socket, {'type': kEncrypted, 'data': payload});
}

/// `{type: encrypted, data: ...}` 봉투를 복호화해 내부 메시지를 반환한다.
///
/// [envelope]의 `type`이 [kEncrypted]가 아니면 예외를 던진다.
Map<String, dynamic> decryptMsg(Map<String, dynamic> envelope, Uint8List key) {
  if (envelope['type'] != kEncrypted) throw '암호화된 메시지가 아닙니다';
  return SyncCrypto.decryptJson(envelope['data'] as String, key);
}

// ── 메시지 타입 상수 ────────────────────────────────────────
//
// 클라이언트 → 서버:
//   kHello       : 연결 시작. 페이로드: {deviceId, name}
//   kPin         : PIN 입력. 페이로드: {pin}
//   kEncrypted   : 암호화된 내부 메시지 (kSyncRequest 포함)
//
// 서버 → 클라이언트:
//   kPinRequired : 최초 연결, PIN 인증 필요. 페이로드: {deviceId, salt}
//   kTrusted     : 신뢰 기기, 바로 동기화. 페이로드: {deviceId}
//   kPinOk       : PIN 인증 성공.
//   kPinWrong    : PIN 불일치.
//   kRejected    : 연결 거부. 페이로드: {reason: 'blocked'|'busy'|'denied'|'pin_expired'|'pin_failed'}
//   kEncrypted   : 암호화된 내부 메시지 (kSyncResult 포함)
//   kError       : 서버 오류. 페이로드: {message}
//
// 암호화 내부 메시지:
//   kSyncRequest : 클라이언트의 노트 전송. 페이로드: {type, notes: List<NoteMap>}
//   kSyncResult  : 서버의 노트 응답. 페이로드: {type, notes: List<NoteMap>}

/// 클라이언트가 서버에 처음 보내는 인사 메시지
const kHello        = 'hello';
/// 서버가 PIN 인증을 요청할 때
const kPinRequired  = 'pin_required';
/// 서버가 기존 신뢰 기기임을 확인했을 때
const kTrusted      = 'trusted';
/// 클라이언트가 PIN을 전송할 때
const kPin          = 'pin';
/// PIN 인증 성공
const kPinOk        = 'pin_ok';
/// PIN 불일치
const kPinWrong     = 'pin_wrong';
/// 클라이언트 → 서버: 노트 목록 전송 (암호화 내부)
const kSyncRequest  = 'sync_request';
/// 서버 → 클라이언트: 병합 후 노트 목록 응답 (암호화 내부)
const kSyncResult   = 'sync_result';
/// AES-256-CBC 암호화 봉투. 페이로드: {data: "IV.ciphertext"}
const kEncrypted    = 'encrypted';
/// 서버 오류 메시지
const kError        = 'error';
/// 연결 거부. reason: blocked | busy | denied | pin_expired | pin_failed
const kRejected     = 'rejected';

// ── JSON-Lines 송수신 헬퍼 ──────────────────────────────────

/// [msg]를 JSON-Lines 형식(`JSON\n`)으로 [socket]에 전송한다.
void sendMsg(Socket socket, Map<String, dynamic> msg) {
  socket.write('${jsonEncode(msg)}\n');
}

/// 소켓에서 한 줄(= 메시지 1개)씩 읽어 스트림으로 반환한다.
///
/// JSON-Lines 방식: 메시지마다 `\n`으로 구분된다.
/// 빈 줄은 무시한다.
Stream<Map<String, dynamic>> receiveMsg(Socket socket) {
  return socket
      .cast<List<int>>()
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .where((line) => line.trim().isNotEmpty)
      .map((line) => jsonDecode(line) as Map<String, dynamic>);
}

// ── 노트 직렬화 ─────────────────────────────────────────────

/// [note]를 동기화용 Map으로 직렬화한다.
///
/// 날짜는 모두 UTC ISO-8601 문자열로 변환한다.
/// 반환된 Map은 [kSyncRequest] / [kSyncResult] 페이로드의 `notes` 배열 원소다.
///
/// 필드:
/// - `syncId`       : 기기 간 노트를 식별하는 UUID
/// - `notebookName` : 소속 노트북 이름 (없으면 '기본')
/// - `title`        : 제목
/// - `body`         : 본문
/// - `isFavorite`   : 즐겨찾기 여부
/// - `isDeleted`    : 소프트 삭제 여부
/// - `deletedAt`    : 삭제 시각 (UTC ISO-8601, null 가능)
/// - `createdAt`    : 생성 시각 (UTC ISO-8601)
/// - `updatedAt`    : 최종 수정 시각 (UTC ISO-8601)
/// - `tags`         : 태그 이름 목록
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
    'isDeleted':     note.isDeleted,
    'deletedAt':     note.deletedAt?.toUtc().toIso8601String(),
    'createdAt':     note.createdAt.toUtc().toIso8601String(),
    'updatedAt':     note.updatedAt.toUtc().toIso8601String(),
    'tags':          tagNames,
  };
}
