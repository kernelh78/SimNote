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

  static Future<Map<String, dynamic>> _read() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return {};
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<void> _write(Map<String, dynamic> data) async {
    final file = await _getFile();
    await file.writeAsString(jsonEncode(data));
  }

  static Future<DateTime?> getLastSyncAt() async {
    final data = await _read();
    final ts = data['lastSyncAt'] as String?;
    return ts != null ? DateTime.parse(ts) : null;
  }

  static Future<void> setLastSyncAt(DateTime time) async {
    final data = await _read();
    data['lastSyncAt'] = time.toUtc().toIso8601String();
    await _write(data);
  }

  static Future<bool> getAutoSync() async {
    final data = await _read();
    return data['autoSync'] as bool? ?? false;
  }

  static Future<void> setAutoSync(bool enabled) async {
    final data = await _read();
    data['autoSync'] = enabled;
    await _write(data);
  }
}
