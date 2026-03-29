import 'dart:io';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../models/notebook.dart';
import '../models/tag.dart';
import '../sync/sync_conflict.dart';
import '../sync/sync_log.dart';
import '../sync/sync_protocol.dart';
import '../sync/sync_state_store.dart';

class DbService {
  static late Isar _isar;

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    try {
      _isar = await Isar.open(
        [NoteSchema, NotebookSchema, TagSchema],
        directory: dir.path,
      );
    } catch (e) {
      // 스키마 변경으로 인한 오류 시 DB 파일 삭제 후 재생성
      final dbFile = File('${dir.path}/default.isar');
      final dbLock = File('${dir.path}/default.isar.lock');
      if (await dbFile.exists()) await dbFile.delete();
      if (await dbLock.exists()) await dbLock.delete();
      _isar = await Isar.open(
        [NoteSchema, NotebookSchema, TagSchema],
        directory: dir.path,
      );
    }
  }

  static Isar get isar => _isar;

  // ── Notebook ──────────────────────────────────────────────

  static Future<List<Notebook>> getAllNotebooks() async {
    return _isar.notebooks.where().findAll();
  }

  static Future<Notebook> createNotebook(String name) async {
    final nb = Notebook()..name = name;
    await _isar.writeTxn(() async {
      await _isar.notebooks.put(nb);
    });
    return nb;
  }

  static Future<void> renameNotebook(Id id, String newName) async {
    // 노트북과 소속 노트를 트랜잭션 밖에서 먼저 로드
    final nb = await _isar.notebooks.get(id);
    if (nb == null) return;
    await nb.notes.load();

    await _isar.writeTxn(() async {
      nb.name = newName;
      await _isar.notebooks.put(nb);
      // 소속 노트들의 updatedAt을 갱신해 동기화가 변경을 감지하도록
      final now = DateTime.now();
      for (final note in nb.notes) {
        note.updatedAt = now;
        await _isar.notes.put(note);
      }
    });
  }

  static Future<void> deleteNotebook(Id id) async {
    await _isar.writeTxn(() async {
      await _isar.notebooks.delete(id);
    });
  }

  // ── Note ──────────────────────────────────────────────────

  static Future<List<Note>> getNotesInNotebook(Id notebookId) async {
    final nb = await _isar.notebooks.get(notebookId);
    if (nb == null) return [];
    await nb.notes.load();
    return nb.notes.where((n) => !n.isDeleted).toList();
  }

  static Future<List<Note>> getFavoriteNotes() async {
    return _isar.notes
        .filter()
        .isFavoriteEqualTo(true)
        .and()
        .isDeletedEqualTo(false)
        .findAll();
  }

  static Future<List<Note>> searchNotes(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    return _isar.notes
        .filter()
        .isDeletedEqualTo(false)
        .and()
        .group((q2) => q2
            .titleContains(q, caseSensitive: false)
            .or()
            .bodyContains(q, caseSensitive: false))
        .findAll();
  }

  static Future<Note> createNote({
    required String title,
    required String body,
    required Id notebookId,
  }) async {
    final note = Note()
      ..syncId = const Uuid().v4()
      ..title = title
      ..body = body
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.notes.put(note);
      final nb = await _isar.notebooks.get(notebookId);
      if (nb != null) {
        note.notebook.value = nb;
        await note.notebook.save();
        nb.notes.add(note);
        await nb.notes.save();
      }
    });
    return note;
  }

  static Future<void> updateNote({
    required Id id,
    required String title,
    required String body,
  }) async {
    await _isar.writeTxn(() async {
      final note = await _isar.notes.get(id);
      if (note != null) {
        note.title = title;
        note.body = body;
        note.updatedAt = DateTime.now();
        await _isar.notes.put(note);
      }
    });
  }

  static Future<void> toggleFavorite(Id id) async {
    await _isar.writeTxn(() async {
      final note = await _isar.notes.get(id);
      if (note != null) {
        note.isFavorite = !note.isFavorite;
        note.updatedAt = DateTime.now(); // 동기화가 변경을 감지하도록
        await _isar.notes.put(note);
      }
    });
  }

  static Future<void> deleteNote(Id id) async {
    await _isar.writeTxn(() async {
      final note = await _isar.notes.get(id);
      if (note != null) {
        note.isDeleted = true;
        note.deletedAt = DateTime.now();
        note.updatedAt = DateTime.now();
        await _isar.notes.put(note);
      }
    });
  }

  // ── Tag ───────────────────────────────────────────────────

  static Future<List<Tag>> getAllTags() async {
    return _isar.tags.where().findAll();
  }

  static Future<List<Note>> getNotesByTag(Id tagId) async {
    final tag = await _isar.tags.get(tagId);
    if (tag == null) return [];
    await tag.notes.load();
    return tag.notes.toList();
  }

  static Future<void> addTagToNote(Id noteId, String tagName) async {
    final note = await _isar.notes.get(noteId);
    if (note == null) return;
    await note.tags.load();

    // 트랜잭션 밖에서 태그 조회 (명시적 non-null 타입)
    final Tag tag =
        await _isar.tags.where().nameEqualTo(tagName).findFirst() ??
            (Tag()..name = tagName);

    await _isar.writeTxn(() async {
      await _isar.tags.put(tag);
      note.tags.add(tag);
      await note.tags.save();
      note.updatedAt = DateTime.now(); // 동기화 감지용
      await _isar.notes.put(note);
    });
  }

  static Future<void> removeTagFromNote(Id noteId, Id tagId) async {
    final note = await _isar.notes.get(noteId);
    if (note == null) return;
    await note.tags.load();

    await _isar.writeTxn(() async {
      note.tags.removeWhere((t) => t.id == tagId);
      await note.tags.save();
      note.updatedAt = DateTime.now(); // 동기화 감지용
      await _isar.notes.put(note);
    });
  }

  // ── 동기화 ────────────────────────────────────────────────

  /// 이 기기의 모든 노트를 동기화용 Map 리스트로 반환 (삭제된 것 포함)
  static Future<List<Map<String, dynamic>>> getAllNotesForSync() async {
    final notes = await _isar.notes.where().findAll();
    final result = <Map<String, dynamic>>[];

    for (final note in notes) {
      await note.notebook.load();
      await note.tags.load();

      // syncId 없는 기존 노트는 지금 생성
      if (note.syncId == null) {
        await _isar.writeTxn(() async {
          note.syncId = const Uuid().v4();
          await _isar.notes.put(note);
        });
      }

      final notebookName = note.notebook.value?.name ?? '기본';
      final tagNames = note.tags.map((t) => t.name).toList();
      result.add(noteToMap(note, notebookName, tagNames));
    }
    return result;
  }

  /// 원격 기기에서 받은 노트 목록을 로컬에 병합
  /// - 마지막 동기화 이후 양쪽 모두 수정 → 충돌로 수집
  /// - 한쪽만 수정 → 최신 버전 채택
  /// - 삭제 전파 지원
  static Future<({int changed, List<SyncConflict> conflicts})>
      mergeRemoteNotes(List<Map<String, dynamic>> remote) async {
    int changed = 0;
    final conflicts = <SyncConflict>[];
    final logs = <SyncLogEntry>[];
    final lastSync = await SyncStateStore.getLastSyncAt();

    for (final map in remote) {
      final syncId    = map['syncId'] as String;
      final title     = map['title'] as String;
      final body      = map['body'] as String;
      final favorite  = map['isFavorite'] as bool;
      final isDeleted = map['isDeleted'] as bool? ?? false;
      final createdAt = DateTime.parse(map['createdAt'] as String).toLocal();
      final updatedAt = DateTime.parse(map['updatedAt'] as String).toLocal();
      final nbName    = map['notebookName'] as String? ?? '기본';
      final tagNames  = (map['tags'] as List).cast<String>();

      final existing =
          await _isar.notes.where().syncIdEqualTo(syncId).findFirst();

      if (existing != null) {
        await existing.tags.load(); // 태그 비교를 위해 미리 로드

        final bothModified = lastSync != null &&
            existing.updatedAt.isAfter(lastSync) &&
            updatedAt.isAfter(lastSync) &&
            !_sameContent(existing, map);

        if (bothModified && !isDeleted && !existing.isDeleted) {
          // 충돌 — 사용자 판단 필요
          logs.add(SyncLogEntry(time: DateTime.now(), noteTitle: existing.title.isEmpty ? '(제목 없음)' : existing.title, action: SyncLogAction.conflictResolved));
          await existing.notebook.load();
          final localMap = noteToMap(
            existing,
            existing.notebook.value?.name ?? '기본',
            existing.tags.map((t) => t.name).toList(),
          );
          conflicts.add(SyncConflict(
            syncId: syncId,
            local: localMap,
            remote: map,
          ));
        } else if (updatedAt.isAfter(existing.updatedAt)) {
          // 원격이 더 최신
          await existing.notebook.load();
          final currentNbName = existing.notebook.value?.name ?? '기본';

          await _isar.writeTxn(() async {
            existing
              ..title      = title
              ..body       = body
              ..isFavorite = favorite
              ..isDeleted  = isDeleted
              ..deletedAt  = isDeleted ? (existing.deletedAt ?? updatedAt) : null
              ..updatedAt  = updatedAt;
            await _isar.notes.put(existing);
          });
          if (!isDeleted) {
            // 노트북이 바뀌었으면 재배정
            if (currentNbName != nbName) {
              await _moveNoteToNotebook(existing, nbName);
            }
            await _setTags(existing, tagNames);
            logs.add(SyncLogEntry(time: DateTime.now(), noteTitle: title.isEmpty ? '(제목 없음)' : title, action: SyncLogAction.updated));
          } else {
            logs.add(SyncLogEntry(time: DateTime.now(), noteTitle: title.isEmpty ? '(제목 없음)' : title, action: SyncLogAction.deleted));
          }
          changed++;
        } else if (!isDeleted && !_sameTagList(existing, tagNames)) {
          await _setTags(existing, tagNames);
          logs.add(SyncLogEntry(time: DateTime.now(), noteTitle: title.isEmpty ? '(제목 없음)' : title, action: SyncLogAction.tagChanged));
          changed++;
        }
      } else if (!isDeleted) {
        // 새 노트 — notebook 먼저 조회 (트랜잭션 밖)
        var nb = await _isar.notebooks
            .filter()
            .nameEqualTo(nbName)
            .findFirst();

        late Note note;
        await _isar.writeTxn(() async {
          if (nb == null) {
            nb = Notebook()..name = nbName;
          }
          await _isar.notebooks.put(nb!);

          note = Note()
            ..syncId     = syncId
            ..title      = title
            ..body       = body
            ..isFavorite = favorite
            ..createdAt  = createdAt
            ..updatedAt  = updatedAt;
          await _isar.notes.put(note);

          note.notebook.value = nb;
          await note.notebook.save();
          nb!.notes.add(note);
          await nb!.notes.save();
        });
        // _setTags는 트랜잭션 밖에서 호출
        await note.tags.load();
        await _setTags(note, tagNames);
        logs.add(SyncLogEntry(time: DateTime.now(), noteTitle: title.isEmpty ? '(제목 없음)' : title, action: SyncLogAction.added));
        changed++;
      }
    }
    await SyncLog.append(logs);
    return (changed: changed, conflicts: conflicts);
  }

  /// 충돌 해결: 선택한 버전으로 덮어쓰기
  static Future<void> resolveConflict(
    SyncConflict conflict,
    bool keepLocal,
  ) async {
    if (keepLocal) return; // 로컬 유지는 아무것도 안 해도 됨

    // 원격 버전으로 덮어쓰기
    final map       = conflict.remote;
    final title     = map['title'] as String;
    final body      = map['body'] as String;
    final favorite  = map['isFavorite'] as bool;
    final updatedAt = DateTime.parse(map['updatedAt'] as String).toLocal();
    final tagNames  = (map['tags'] as List).cast<String>();

    final note = await _isar.notes
        .where()
        .syncIdEqualTo(conflict.syncId)
        .findFirst();
    if (note == null) return;

    await _isar.writeTxn(() async {
      note
        ..title      = title
        ..body       = body
        ..isFavorite = favorite
        ..updatedAt  = updatedAt;
      await _isar.notes.put(note);
    });
    await note.tags.load();
    await _setTags(note, tagNames);
  }

  /// 충돌 해결: 둘 다 보관 (원격 버전을 새 노트로 복사)
  static Future<void> resolveConflictKeepBoth(SyncConflict conflict) async {
    final map      = conflict.remote;
    final title    = '${map['title']} (상대 기기)';
    final body     = map['body'] as String;
    final favorite = map['isFavorite'] as bool;
    final nbName   = map['notebookName'] as String? ?? '기본';
    final tagNames = (map['tags'] as List).cast<String>();

    // notebook 조회는 트랜잭션 밖에서
    var nb = await _isar.notebooks
        .filter()
        .nameEqualTo(nbName)
        .findFirst();

    late Note note;
    await _isar.writeTxn(() async {
      if (nb == null) {
        nb = Notebook()..name = nbName;
      }
      await _isar.notebooks.put(nb!);

      note = Note()
        ..syncId     = const Uuid().v4()
        ..title      = title
        ..body       = body
        ..isFavorite = favorite
        ..createdAt  = DateTime.now()
        ..updatedAt  = DateTime.now();
      await _isar.notes.put(note);

      note.notebook.value = nb;
      await note.notebook.save();
      nb!.notes.add(note);
      await nb!.notes.save();
    });
    // _setTags는 트랜잭션 밖에서 호출
    await note.tags.load();
    await _setTags(note, tagNames);
  }

  static bool _sameContent(Note note, Map<String, dynamic> map) {
    final remoteTags = (map['tags'] as List).cast<String>();
    return note.title == map['title'] &&
        note.body == map['body'] &&
        note.isFavorite == map['isFavorite'] &&
        _sameTagList(note, remoteTags);
  }

  static bool _sameTagList(Note note, List<String> remoteTags) {
    final localNames = note.tags.map((t) => t.name).toSet();
    final remoteNames = remoteTags.toSet();
    return localNames.length == remoteNames.length &&
        localNames.containsAll(remoteNames);
  }

  /// 노트를 다른 노트북으로 이동 (없으면 새로 생성)
  static Future<void> _moveNoteToNotebook(Note note, String nbName) async {
    var nb = await _isar.notebooks.filter().nameEqualTo(nbName).findFirst();
    await _isar.writeTxn(() async {
      if (nb == null) {
        nb = Notebook()..name = nbName;
        await _isar.notebooks.put(nb!);
      }
      note.notebook.value = nb;
      await note.notebook.save();
      nb!.notes.add(note);
      await nb!.notes.save();
    });
  }

  /// 태그 이름 목록으로 note에 태그를 연결.
  /// note.tags.load()는 호출 전에 완료되어 있어야 함.
  /// write 트랜잭션 밖에서 호출해야 함.
  static Future<void> _setTags(Note note, List<String> tagNames) async {
    // 1. 트랜잭션 밖에서 태그 객체 조회/생성
    final tags = <Tag>[];
    for (final name in tagNames) {
      var tag = await _isar.tags.where().nameEqualTo(name).findFirst();
      tag ??= Tag()..name = name;
      tags.add(tag);
    }

    // 2. 트랜잭션 안에서 저장 및 연결
    await _isar.writeTxn(() async {
      for (final tag in tags) {
        await _isar.tags.put(tag);
      }
      note.tags.clear();
      note.tags.addAll(tags);
      await note.tags.save();
    });
  }
}
