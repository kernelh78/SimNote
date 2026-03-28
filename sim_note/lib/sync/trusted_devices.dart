import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 한 번 PIN 인증을 통과한 기기 ID 목록을 파일로 저장
class TrustedDevices {
  static Set<String>? _ids;

  static Future<bool> isTrusted(String deviceId) async {
    final ids = await _load();
    return ids.contains(deviceId);
  }

  static Future<void> trust(String deviceId) async {
    final ids = await _load();
    if (ids.add(deviceId)) await _save(ids);
  }

  static Future<Set<String>> _load() async {
    if (_ids != null) return _ids!;
    try {
      final file = await _file();
      if (await file.exists()) {
        final list = jsonDecode(await file.readAsString()) as List;
        _ids = list.cast<String>().toSet();
        return _ids!;
      }
    } catch (_) {}
    _ids = {};
    return _ids!;
  }

  static Future<void> _save(Set<String> ids) async {
    _ids = ids;
    final file = await _file();
    await file.writeAsString(jsonEncode(ids.toList()));
  }

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/.simnote_trusted.json');
  }
}
