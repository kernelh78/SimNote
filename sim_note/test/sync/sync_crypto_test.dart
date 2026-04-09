import 'package:flutter_test/flutter_test.dart';
import 'package:sim_note/sync/sync_crypto.dart';

void main() {
  group('SyncCrypto', () {
    test('암호화 후 복호화하면 원문 반환', () {
      final key      = SyncCrypto.deriveKey('123456', 'abc123');
      final original = {'type': 'test', 'value': '안녕하세요 Hello 123'};
      final enc      = SyncCrypto.encryptJson(original, key);
      final dec      = SyncCrypto.decryptJson(enc, key);
      expect(dec['type'],  equals('test'));
      expect(dec['value'], equals('안녕하세요 Hello 123'));
    });

    test('같은 PIN + salt는 항상 같은 키 생성', () {
      final key1 = SyncCrypto.deriveKey('123456', 'mysalt');
      final key2 = SyncCrypto.deriveKey('123456', 'mysalt');
      expect(key1, equals(key2));
    });

    test('다른 PIN은 다른 키 생성', () {
      final key1 = SyncCrypto.deriveKey('123456', 'mysalt');
      final key2 = SyncCrypto.deriveKey('654321', 'mysalt');
      expect(key1, isNot(equals(key2)));
    });

    test('다른 salt는 다른 키 생성', () {
      final key1 = SyncCrypto.deriveKey('123456', 'salt_a');
      final key2 = SyncCrypto.deriveKey('123456', 'salt_b');
      expect(key1, isNot(equals(key2)));
    });

    test('동일 메시지 반복 암호화 시 다른 결과 (랜덤 IV)', () {
      final key  = SyncCrypto.deriveKey('pin', 'salt');
      final msg  = {'hello': 'world'};
      final enc1 = SyncCrypto.encryptJson(msg, key);
      final enc2 = SyncCrypto.encryptJson(msg, key);
      expect(enc1, isNot(equals(enc2)));
    });

    test('다른 키로 복호화 시 예외 발생', () {
      final key1 = SyncCrypto.deriveKey('123456', 'salt1');
      final key2 = SyncCrypto.deriveKey('654321', 'salt2');
      final enc  = SyncCrypto.encryptJson({'msg': 'secret'}, key1);
      expect(() => SyncCrypto.decryptJson(enc, key2), throwsA(anything));
    });

    test('잘못된 형식(점 없음)은 예외 발생', () {
      final key = SyncCrypto.deriveKey('pin', 'salt');
      expect(
        () => SyncCrypto.decryptJson('invalid_no_dot', key),
        throwsA(anything),
      );
    });

    test('빈 Map 암호화/복호화', () {
      final key = SyncCrypto.deriveKey('000000', 'salt');
      final enc = SyncCrypto.encryptJson({}, key);
      final dec = SyncCrypto.decryptJson(enc, key);
      expect(dec, isEmpty);
    });

    test('중첩 구조 Map 암호화/복호화', () {
      final key = SyncCrypto.deriveKey('pin', 'salt');
      final msg = {
        'type': 'sync',
        'notes': [
          {'id': '1', 'title': '노트 제목', 'body': '내용'},
        ],
      };
      final enc = SyncCrypto.encryptJson(msg, key);
      final dec = SyncCrypto.decryptJson(enc, key);
      expect(dec['type'], equals('sync'));
      expect((dec['notes'] as List).length, equals(1));
    });

    test('randomSalt는 32자 소문자 hex', () {
      final salt = SyncCrypto.randomSalt();
      expect(salt.length, equals(32));
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(salt), isTrue);
    });

    test('randomSalt 두 번 호출 시 다른 값', () {
      final s1 = SyncCrypto.randomSalt();
      final s2 = SyncCrypto.randomSalt();
      expect(s1, isNot(equals(s2)));
    });

    test('deriveKey 결과는 32바이트 (AES-256)', () {
      final key = SyncCrypto.deriveKey('pin', 'salt');
      expect(key.length, equals(32));
    });
  });
}
