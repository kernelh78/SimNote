import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../models/notebook.dart';
import '../models/tag.dart';
import '../sync/sync_protocol.dart';

class DbService {
  static late Isar _isar;

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [NoteSchema, NotebookSchema, TagSchema],
      directory: dir.path,
    );
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
    await _isar.writeTxn(() async {
      final nb = await _isar.notebooks.get(id);
      if (nb != null) {
        nb.name = newName;
        await _isar.notebooks.put(nb);
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
    return nb.notes.toList();
  }

  static Future<List<Note>> getFavoriteNotes() async {
    return _isar.notes.filter().isFavoriteEqualTo(true).findAll();
  }

  static Future<List<Note>> searchNotes(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    return _isar.notes
        .filter()
        .titleContains(q, caseSensitive: false)
        .or()
        .bodyContains(q, caseSensitive: false)
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
        await _isar.notes.put(note);
      }
    });
  }

  static Future<void> deleteNote(Id id) async {
    await _isar.writeTxn(() async {
      await _isar.notes.delete(id);
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
    await _isar.writeTxn(() async {
      final note = await _isar.notes.get(noteId);
      if (note == null) return;

      var tag = await _isar.tags.where().nameEqualTo(tagName).findFirst();
      tag ??= Tag()..name = tagName;
      await _isar.tags.put(tag);

      await note.tags.load();
      note.tags.add(tag);
      await note.tags.save();
    });
  }

  static Future<void> removeTagFromNote(Id noteId, Id tagId) async {
    await _isar.writeTxn(() async {
      final note = await _isar.notes.get(noteId);
      if (note == null) return;
      await note.tags.load();
      note.tags.removeWhere((t) => t.id == tagId);
      await note.tags.save();
    });
  }

  // ── 동기화 ────────────────────────────────────────────────

  /// 이 기기의 모든 노트를 동기화용 Map 리스트로 반환
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
  /// 규칙: syncId가 같으면 updatedAt이 더 최신인 것을 유지
  static Future<int> mergeRemoteNotes(
    List<Map<String, dynamic>> remote,
  ) async {
    int changed = 0;

    for (final map in remote) {
      final syncId    = map['syncId'] as String;
      final title     = map['title'] as String;
      final body      = map['body'] as String;
      final favorite  = map['isFavorite'] as bool;
      final createdAt = DateTime.parse(map['createdAt'] as String).toLocal();
      final updatedAt = DateTime.parse(map['updatedAt'] as String).toLocal();
      final nbName    = map['notebookName'] as String? ?? '기본';
      final tagNames  = (map['tags'] as List).cast<String>();

      // 로컬에서 같은 syncId 노트 찾기
      final existing =
          await _isar.notes.where().syncIdEqualTo(syncId).findFirst();

      if (existing != null) {
        // 원격이 더 최신이면 업데이트
        if (updatedAt.isAfter(existing.updatedAt)) {
          await _isar.writeTxn(() async {
            existing
              ..title      = title
              ..body       = body
              ..isFavorite = favorite
              ..updatedAt  = updatedAt;
            await _isar.notes.put(existing);
            await _setTags(existing, tagNames);
          });
          changed++;
        }
      } else {
        // 새 노트 — 노트북 찾거나 생성
        await _isar.writeTxn(() async {
          var nb = await _isar.notebooks
              .filter()
              .nameEqualTo(nbName)
              .findFirst();
          nb ??= Notebook()..name = nbName;
          await _isar.notebooks.put(nb);

          final note = Note()
            ..syncId     = syncId
            ..title      = title
            ..body       = body
            ..isFavorite = favorite
            ..createdAt  = createdAt
            ..updatedAt  = updatedAt;
          await _isar.notes.put(note);

          note.notebook.value = nb;
          await note.notebook.save();
          nb.notes.add(note);
          await nb.notes.save();

          await _setTags(note, tagNames);
        });
        changed++;
      }
    }
    return changed;
  }

  static Future<void> _setTags(Note note, List<String> tagNames) async {
    await note.tags.load();
    note.tags.clear();
    for (final name in tagNames) {
      var tag = await _isar.tags.where().nameEqualTo(name).findFirst();
      tag ??= Tag()..name = name;
      await _isar.tags.put(tag);
      note.tags.add(tag);
    }
    await note.tags.save();
  }
}
