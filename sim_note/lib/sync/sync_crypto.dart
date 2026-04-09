import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

/// SimNote 동기화용 암호화 유틸리티
///
/// 알고리즘:
/// - 키 파생: SHA-256(`PIN:salt`) → 32바이트 AES-256 키
/// - 암호화: AES-256-CBC, 매 암호화마다 16바이트 랜덤 IV 생성
/// - 포맷:   `base64(IV).base64(ciphertext)` (점으로 구분)
class SyncCrypto {
  /// PIN과 salt로 32바이트 AES-256 키를 파생한다.
  ///
  /// SHA-256(`'$pin:$salt'`)을 사용하며, 결과는 항상 32바이트다.
  /// [salt]는 [randomSalt]로 생성한 hex 문자열을 사용한다.
  static Uint8List deriveKey(String pin, String salt) {
    final input = utf8.encode('$pin:$salt');
    return Uint8List.fromList(sha256.convert(input).bytes);
  }

  /// 암호화에 사용할 랜덤 16바이트 hex salt를 생성한다.
  ///
  /// 결과는 32자 소문자 hex 문자열이다.
  static String randomSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// [msg]를 [keyBytes]로 AES-256-CBC 암호화한다.
  ///
  /// 매 호출마다 새로운 16바이트 IV를 생성하므로,
  /// 같은 입력이라도 결과 문자열은 다르다.
  ///
  /// 반환 형식: `base64(IV).base64(ciphertext)`
  static String encryptJson(Map<String, dynamic> msg, Uint8List keyBytes) {
    final key = Key(keyBytes);
    final iv  = IV.fromSecureRandom(16);
    final enc = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = enc.encrypt(jsonEncode(msg), iv: iv);
    return '${iv.base64}.${encrypted.base64}';
  }

  /// [data] 문자열을 [keyBytes]로 AES-256-CBC 복호화한다.
  ///
  /// [data]는 [encryptJson]이 반환한 `IV.ciphertext` 형식이어야 한다.
  /// 잘못된 형식이거나 키가 맞지 않으면 예외를 던진다.
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
