import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import '../database/db_service.dart';
import '../models/note.dart';
import '../models/notebook.dart';
import '../models/tag.dart';

enum SidebarMode { notebook, favorites, tag }

class AppProvider extends ChangeNotifier {
  List<Notebook> notebooks = [];
  List<Note> currentNotes = [];
  List<Tag> allTags = [];

  Note? selectedNote;
  Notebook? selectedNotebook;
  Tag? selectedTag;
  SidebarMode sidebarMode = SidebarMode.notebook;

  String searchQuery = '';

  // ── 초기 로드 ─────────────────────────────────────────────

  Future<void> load() async {
    notebooks = await DbService.getAllNotebooks();
    allTags = await DbService.getAllTags();

    if (notebooks.isNotEmpty) {
      await selectNotebook(notebooks.first);
    }
    notifyListeners();
  }

  // ── 사이드바 선택 ─────────────────────────────────────────

  Future<void> selectNotebook(Notebook nb) async {
    selectedNotebook = nb;
    selectedTag = null;
    sidebarMode = SidebarMode.notebook;
    currentNotes = await DbService.getNotesInNotebook(nb.id);
    selectedNote = null;
    notifyListeners();
  }

  Future<void> selectFavorites() async {
    selectedNotebook = null;
    selectedTag = null;
    sidebarMode = SidebarMode.favorites;
    currentNotes = await DbService.getFavoriteNotes();
    selectedNote = null;
    notifyListeners();
  }

  Future<void> selectTag(Tag tag) async {
    selectedNotebook = null;
    selectedTag = tag;
    sidebarMode = SidebarMode.tag;
    currentNotes = await DbService.getNotesByTag(tag.id);
    selectedNote = null;
    notifyListeners();
  }

  void selectNote(Note note) {
    selectedNote = note;
    notifyListeners();
  }

  // ── 검색 ──────────────────────────────────────────────────

  Future<void> search(String query) async {
    searchQuery = query;
    if (query.trim().isEmpty) {
      await _refreshCurrentList();
    } else {
      currentNotes = await DbService.searchNotes(query);
      selectedNote = null;
    }
    notifyListeners();
  }

  // ── Notebook CRUD ─────────────────────────────────────────

  Future<void> createNotebook(String name) async {
    final nb = await DbService.createNotebook(name);
    notebooks = await DbService.getAllNotebooks();
    await selectNotebook(nb);
  }

  Future<void> renameNotebook(Id id, String newName) async {
    await DbService.renameNotebook(id, newName);
    notebooks = await DbService.getAllNotebooks();
    notifyListeners();
  }

  Future<void> deleteNotebook(Id id) async {
    await DbService.deleteNotebook(id);
    notebooks = await DbService.getAllNotebooks();
    selectedNotebook = null;
    currentNotes = [];
    selectedNote = null;
    if (notebooks.isNotEmpty) await selectNotebook(notebooks.first);
    notifyListeners();
  }

  // ── Note CRUD ─────────────────────────────────────────────

  Future<void> createNote() async {
    if (selectedNotebook == null) return;
    final note = await DbService.createNote(
      title: '',
      body: '',
      notebookId: selectedNotebook!.id,
    );
    currentNotes = await DbService.getNotesInNotebook(selectedNotebook!.id);
    selectedNote = note;
    notifyListeners();
  }

  Future<void> saveNote(Id id, String title, String body) async {
    await DbService.updateNote(id: id, title: title, body: body);
    await _refreshCurrentList();
  }

  Future<void> toggleFavorite(Id id) async {
    await DbService.toggleFavorite(id);
    await _refreshCurrentList();
    if (selectedNote?.id == id) {
      selectedNote = currentNotes.where((n) => n.id == id).firstOrNull;
    }
  }

  Future<void> deleteNote(Id id) async {
    await DbService.deleteNote(id);
    selectedNote = null;
    await _refreshCurrentList();
  }

  // ── Tag ───────────────────────────────────────────────────

  Future<void> addTagToNote(Id noteId, String tagName) async {
    await DbService.addTagToNote(noteId, tagName);
    allTags = await DbService.getAllTags();
    await _refreshCurrentList();
    if (selectedNote?.id == noteId) {
      selectedNote = currentNotes.where((n) => n.id == noteId).firstOrNull;
    }
  }

  Future<void> removeTagFromNote(Id noteId, Id tagId) async {
    await DbService.removeTagFromNote(noteId, tagId);
    allTags = await DbService.getAllTags();
    await _refreshCurrentList();
  }

  // ── 내부 헬퍼 ─────────────────────────────────────────────

  Future<void> _refreshCurrentList() async {
    switch (sidebarMode) {
      case SidebarMode.notebook:
        if (selectedNotebook != null) {
          currentNotes =
              await DbService.getNotesInNotebook(selectedNotebook!.id);
        }
      case SidebarMode.favorites:
        currentNotes = await DbService.getFavoriteNotes();
      case SidebarMode.tag:
        if (selectedTag != null) {
          currentNotes = await DbService.getNotesByTag(selectedTag!.id);
        }
    }
    notifyListeners();
  }
}
