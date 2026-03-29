import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 마지막 동기화 시각을 파일에 저장/불러오기
class SyncStateStore {
  static File? _file;

  static Future<File> _getFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/.simnote_sync_state.json');
    return _file!;
  }

  static Future<DateTime?> getLastSyncAt() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return null;
      final data = jsonDecode(await file.readAsString());
      final ts = data['lastSyncAt'] as String?;
      return ts != null ? DateTime.parse(ts) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setLastSyncAt(DateTime time) async {
    final file = await _getFile();
    await file.writeAsString(
      jsonEncode({'lastSyncAt': time.toUtc().toIso8601String()}),
    );
  }
}
