import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// 신뢰 기기 목록과 기기별 세션 키를 파일로 저장
class TrustedDevices {
  static Map<String, String>? _data;     // deviceId → keyHex
  static Set<String>?          _blocked; // 차단된 deviceId 목록

  static Future<bool> isTrusted(String deviceId) async {
    final data = await _load();
    return data.containsKey(deviceId);
  }

  // ── 차단 목록 ────────────────────────────────────────────

  static Future<bool> isBlocked(String deviceId) async {
    final blocked = await _loadBlocked();
    return blocked.contains(deviceId);
  }

  static Future<void> block(String deviceId) async {
    final blocked = await _loadBlocked();
    blocked.add(deviceId);
    await _saveBlocked(blocked);
  }

  static Future<void> unblock(String deviceId) async {
    final blocked = await _loadBlocked();
    blocked.remove(deviceId);
    await _saveBlocked(blocked);
  }

  static Future<List<String>> getBlockedIds() async {
    final blocked = await _loadBlocked();
    return blocked.toList();
  }

  static Future<Set<String>> _loadBlocked() async {
    if (_blocked != null) return _blocked!;
    try {
      final file = await _blockedFile();
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString());
        if (raw is List) {
          _blocked = Set<String>.from(raw.cast<String>());
          return _blocked!;
        }
      }
    } catch (_) {}
    _blocked = {};
    return _blocked!;
  }

  static Future<void> _saveBlocked(Set<String> blocked) async {
    _blocked = blocked;
    await (await _blockedFile()).writeAsString(jsonEncode(blocked.toList()));
  }

  static Future<File> _blockedFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/.simnote_blocked.json');
  }

  /// 기기를 신뢰 목록에 추가하고 세션 키를 저장
  static Future<void> trust(String deviceId, Uint8List sessionKey) async {
    final data = await _load();
    data[deviceId] = _toHex(sessionKey);
    await _save(data);
  }

  /// 저장된 세션 키 반환 (없으면 null)
  static Future<Uint8List?> getKey(String deviceId) async {
    final data = await _load();
    final hex = data[deviceId];
    if (hex == null) return null;
    return _fromHex(hex);
  }

  static Future<Map<String, String>> _load() async {
    if (_data != null) return _data!;
    try {
      final file = await _file();
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString());
        if (raw is Map) {
          _data = Map<String, String>.from(raw);
          return _data!;
        }
        // 이전 형식(List) 마이그레이션
        if (raw is List) {
          _data = {for (final id in raw) id as String: ''};
          return _data!;
        }
      }
    } catch (_) {}
    _data = {};
    return _data!;
  }

  static Future<void> _save(Map<String, String> data) async {
    _data = data;
    await (await _file()).writeAsString(jsonEncode(data));
  }

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/.simnote_trusted.json');
  }

  static String _toHex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List _fromHex(String hex) {
    if (hex.isEmpty) return Uint8List(0);
    return Uint8List.fromList([
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16)
    ]);
  }
}
