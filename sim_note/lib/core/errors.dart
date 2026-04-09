/// SimNote 앱 전용 에러 타입
///
/// 모든 에러는 [userMessage]를 갖는다 — 사용자에게 직접 보여줄 수 있는 메시지.
/// [technical]은 로그/디버그 전용으로 UI에 노출하지 않는다.
class SimNoteError implements Exception {
  final String userMessage;
  final String? technical;

  const SimNoteError(this.userMessage, {this.technical});

  @override
  String toString() => userMessage;
}

/// 동기화 관련 에러 (소켓 연결, PIN 인증, 프로토콜)
class SyncError extends SimNoteError {
  const SyncError(super.userMessage, {super.technical});
}

/// 암호화/복호화 에러
class CryptoError extends SimNoteError {
  const CryptoError(super.userMessage, {super.technical});
}

/// 파일/스토리지 에러
class StorageError extends SimNoteError {
  const StorageError(super.userMessage, {super.technical});
}
