/// 동기화 충돌 정보
class SyncConflict {
  final String syncId;
  final Map<String, dynamic> local;
  final Map<String, dynamic> remote;

  const SyncConflict({
    required this.syncId,
    required this.local,
    required this.remote,
  });

  String get title => local['title'] as String? ?? '(제목 없음)';
  String get localBody => local['body'] as String? ?? '';
  String get remoteBody => remote['body'] as String? ?? '';
  DateTime get localUpdatedAt =>
      DateTime.parse(local['updatedAt'] as String).toLocal();
  DateTime get remoteUpdatedAt =>
      DateTime.parse(remote['updatedAt'] as String).toLocal();
}
