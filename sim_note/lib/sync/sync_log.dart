import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

enum SyncLogAction { added, updated, deleted, tagChanged, conflictResolved }

class SyncLogEntry {
  final DateTime time;
  final String noteTitle;
  final SyncLogAction action;
  final String? detail; // 기기 이름 등 부가 정보

  SyncLogEntry({
    required this.time,
    required this.noteTitle,
    required this.action,
    this.detail,
  });

  String get actionLabel {
    switch (action) {
      case SyncLogAction.added:           return '추가됨';
      case SyncLogAction.updated:         return '업데이트됨';
      case SyncLogAction.deleted:         return '삭제됨';
      case SyncLogAction.tagChanged:      return '태그 변경';
      case SyncLogAction.conflictResolved:return '충돌 해결';
    }
  }

  Map<String, dynamic> toJson() => {
    'time':       time.toUtc().toIso8601String(),
    'noteTitle':  noteTitle,
    'action':     action.name,
    'detail':     detail,
  };

  factory SyncLogEntry.fromJson(Map<String, dynamic> j) => SyncLogEntry(
    time:       DateTime.parse(j['time'] as String).toLocal(),
    noteTitle:  j['noteTitle'] as String,
    action:     SyncLogAction.values.byName(j['action'] as String),
    detail:     j['detail'] as String?,
  );
}

class SyncLog {
  static const _maxEntries = 200;
  static File? _file;

  static Future<File> _getFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/.simnote_sync_log.json');
    return _file!;
  }

  static Future<List<SyncLogEntry>> load() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return [];
      final list = jsonDecode(await file.readAsString()) as List;
      return list
          .map((e) => SyncLogEntry.fromJson(e as Map<String, dynamic>))
          .toList()
          .reversed
          .toList(); // 최신순
    } catch (_) {
      return [];
    }
  }

  static Future<void> append(List<SyncLogEntry> entries) async {
    if (entries.isEmpty) return;
    try {
      final file = await _getFile();
      List existing = [];
      if (await file.exists()) {
        existing = jsonDecode(await file.readAsString()) as List;
      }
      existing.addAll(entries.map((e) => e.toJson()));
      // 최대 개수 유지 (오래된 것부터 제거)
      if (existing.length > _maxEntries) {
        existing = existing.sublist(existing.length - _maxEntries);
      }
      await file.writeAsString(jsonEncode(existing));
    } catch (_) {}
  }

  static Future<void> clear() async {
    final file = await _getFile();
    if (await file.exists()) await file.delete();
  }
}
