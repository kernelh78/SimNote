import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

class SyncCrypto {
  /// PIN + salt 로 32바이트 AES 키 생성 (SHA-256)
  static Uint8List deriveKey(String pin, String salt) {
    final input = utf8.encode('$pin:$salt');
    return Uint8List.fromList(sha256.convert(input).bytes);
  }

  /// 랜덤 16자리 hex salt 생성
  static String randomSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Map → AES-256-CBC 암호화 → base64 문자열 (IV 앞에 포함)
  static String encryptJson(Map<String, dynamic> msg, Uint8List keyBytes) {
    final key = Key(keyBytes);
    final iv  = IV.fromSecureRandom(16);
    final enc = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = enc.encrypt(jsonEncode(msg), iv: iv);
    // IV(base64) + "." + ciphertext(base64)
    return '${iv.base64}.${encrypted.base64}';
  }

  /// base64 문자열 → AES-256-CBC 복호화 → Map
  static Map<String, dynamic> decryptJson(String data, Uint8List keyBytes) {
    final parts = data.split('.');
    if (parts.length != 2) throw '잘못된 암호화 형식';
    final key = Key(keyBytes);
    final iv  = IV.fromBase64(parts[0]);
    final enc = Encrypter(AES(key, mode: AESMode.cbc));
    final decrypted = enc.decrypt64(parts[1], iv: iv);
    return jsonDecode(decrypted) as Map<String, dynamic>;
  }
}
