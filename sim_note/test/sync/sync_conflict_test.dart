import 'package:flutter_test/flutter_test.dart';
import 'package:sim_note/sync/sync_conflict.dart';

void main() {
  final now   = DateTime.utc(2026, 4, 9, 10, 0, 0);
  final later = DateTime.utc(2026, 4, 9, 11, 0, 0);

  SyncConflict makeConflict({
    String  localTitle  = '로컬 제목',
    String  remoteTitle = '원격 제목',
    String  localBody   = '로컬 내용',
    String  remoteBody  = '원격 내용',
    DateTime? localAt,
    DateTime? remoteAt,
  }) {
    return SyncConflict(
      syncId: 'test-sync-id-001',
      local: {
        'title':     localTitle,
        'body':      localBody,
        'updatedAt': (localAt ?? now).toIso8601String(),
        'isFavorite': false,
        'tags':      <String>[],
      },
      remote: {
        'title':     remoteTitle,
        'body':      remoteBody,
        'updatedAt': (remoteAt ?? later).toIso8601String(),
        'isFavorite': false,
        'tags':      <String>[],
      },
    );
  }

  group('SyncConflict', () {
    test('syncId가 올바르게 저장됨', () {
      final c = makeConflict();
      expect(c.syncId, equals('test-sync-id-001'));
    });

    test('title은 로컬 제목 반환', () {
      final c = makeConflict(localTitle: '내 노트 제목');
      expect(c.title, equals('내 노트 제목'));
    });

    test('로컬 제목이 빈 문자열이면 기본값 반환', () {
      final c = makeConflict(localTitle: '');
      expect(c.title, equals('(제목 없음)'));
    });

    test('localBody 정상 반환', () {
      final c = makeConflict(localBody: '내 내용입니다');
      expect(c.localBody, equals('내 내용입니다'));
    });

    test('remoteBody 정상 반환', () {
      final c = makeConflict(remoteBody: '상대방 내용입니다');
      expect(c.remoteBody, equals('상대방 내용입니다'));
    });

    test('localUpdatedAt ISO 문자열 파싱 정상', () {
      final c = makeConflict(localAt: now);
      expect(c.localUpdatedAt.year,  equals(2026));
      expect(c.localUpdatedAt.month, equals(4));
      expect(c.localUpdatedAt.day,   equals(9));
    });

    test('remoteUpdatedAt이 localUpdatedAt보다 나중', () {
      final c = makeConflict(localAt: now, remoteAt: later);
      expect(c.remoteUpdatedAt.isAfter(c.localUpdatedAt), isTrue);
    });

    test('local과 remote에 독립된 내용이 저장됨', () {
      final c = makeConflict(
        localTitle: '내 제목', remoteTitle: '상대 제목',
        localBody:  '내 내용', remoteBody:  '상대 내용',
      );
      expect(c.local['title'],  equals('내 제목'));
      expect(c.remote['title'], equals('상대 제목'));
      expect(c.localBody,  equals('내 내용'));
      expect(c.remoteBody, equals('상대 내용'));
    });

    test('빈 body는 빈 문자열로 처리', () {
      final c = SyncConflict(
        syncId: 'id',
        local:  {'title': 'T', 'updatedAt': now.toIso8601String()},
        remote: {'title': 'T', 'updatedAt': later.toIso8601String()},
      );
      expect(c.localBody,  equals(''));
      expect(c.remoteBody, equals(''));
    });
  });
}
