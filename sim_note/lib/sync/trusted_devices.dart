import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// 신뢰 기기 목록과 기기별 세션 키를 관리
/// - 세션 키: flutter_secure_storage (iOS Keychain / Android Keystore / macOS Keychain)
/// - 차단 목록: 민감 정보 없으므로 기존 파일 저장 유지
class TrustedDevices {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    mOptions: MacOsOptions(),
    iOptions: IOSOptions(),
  );
  static const _keyPrefix = 'simnote_key_';

  static Map<String, String>? _cache;   // deviceId → keyHex (인메모리 캐시)
  static Map<String, String>? _blocked; // deviceId → deviceName
  static bool _migrated = false;

  // ── 구 버전 파일 → SecureStorage 마이그레이션 ─────────────

  static Future<void> _ensureMigrated() async {
    if (_migrated) return;
    _migrated = true;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final oldFile = File('${dir.path}/.simnote_trusted.json');
      if (!await oldFile.exists()) return;

      final raw = jsonDecode(await oldFile.readAsString());
      if (raw is Map) {
        for (final entry in raw.entries) {
          final deviceId = entry.key as String;
          final keyHex   = entry.value as String;
          if (keyHex.isNotEmpty) {
            await _storage.write(key: '$_keyPrefix$deviceId', value: keyHex);
          }
        }
      }
      await oldFile.delete();
    } catch (_) {}
  }

  // ── 신뢰 기기 ─────────────────────────────────────────────

  static Future<bool> isTrusted(String deviceId) async {
    final data = await _load();
    return data.containsKey(deviceId);
  }

  /// 기기를 신뢰 목록에 추가하고 세션 키를 Keychain에 저장
  static Future<void> trust(String deviceId, Uint8List sessionKey) async {
    final hex = _toHex(sessionKey);
    _cache ??= {};
    _cache![deviceId] = hex;
    await _storage.write(key: '$_keyPrefix$deviceId', value: hex);
  }

  /// 저장된 세션 키 반환 (없으면 null)
  static Future<Uint8List?> getKey(String deviceId) async {
    final data = await _load();
    final hex  = data[deviceId];
    if (hex == null || hex.isEmpty) return null;
    return _fromHex(hex);
  }

  static Future<Map<String, String>> _load() async {
    if (_cache != null) return _cache!;
    await _ensureMigrated();
    try {
      final all  = await _storage.readAll();
      _cache = {};
      for (final entry in all.entries) {
        if (entry.key.startsWith(_keyPrefix)) {
          final deviceId = entry.key.substring(_keyPrefix.length);
          _cache![deviceId] = entry.value;
        }
      }
    } catch (_) {
      _cache = {};
    }
    return _cache!;
  }

  // ── 차단 목록 ─────────────────────────────────────────────

  static Future<bool> isBlocked(String deviceId) async {
    final blocked = await _loadBlocked();
    return blocked.containsKey(deviceId);
  }

  static Future<void> block(String deviceId, {String name = ''}) async {
    final blocked = await _loadBlocked();
    blocked[deviceId] = name;
    await _saveBlocked(blocked);
  }

  static Future<void> unblock(String deviceId) async {
    final blocked = await _loadBlocked();
    blocked.remove(deviceId);
    await _saveBlocked(blocked);
  }

  /// 차단된 기기 목록 반환 (deviceId → 기기 이름)
  static Future<Map<String, String>> getBlockedDevices() async {
    return Map<String, String>.from(await _loadBlocked());
  }

  static Future<Map<String, String>> _loadBlocked() async {
    if (_blocked != null) return _blocked!;
    try {
      final file = await _blockedFile();
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString());
        if (raw is Map) {
          _blocked = Map<String, String>.from(raw.cast<String, String>());
          return _blocked!;
        }
        // 이전 형식(List) 마이그레이션 — 이름 없이 ID만 저장된 경우
        if (raw is List) {
          _blocked = {for (final id in raw) id as String: ''};
          return _blocked!;
        }
      }
    } catch (_) {}
    _blocked = {};
    return _blocked!;
  }

  static Future<void> _saveBlocked(Map<String, String> blocked) async {
    _blocked = blocked;
    await (await _blockedFile()).writeAsString(jsonEncode(blocked));
  }

  static Future<File> _blockedFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/.simnote_blocked.json');
  }

  // ── 유틸리티 ──────────────────────────────────────────────

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
