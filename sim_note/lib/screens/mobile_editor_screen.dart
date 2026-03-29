import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/note.dart';
import '../widgets/note_tag_row.dart';

class MobileEditorScreen extends StatefulWidget {
  const MobileEditorScreen({super.key});

  @override
  State<MobileEditorScreen> createState() => _MobileEditorScreenState();
}

class _MobileEditorScreenState extends State<MobileEditorScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  Note? _loadedNote;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _syncControllers(Note? note) {
    if (note?.id != _loadedNote?.id) {
      _loadedNote = note;
      _titleController.text = note?.title ?? '';
      _bodyController.text = note?.body ?? '';
    }
  }

  void _save(AppProvider provider) {
    final note = provider.selectedNote;
    if (note == null) return;
    provider.saveNote(note.id, _titleController.text, _bodyController.text);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final note = provider.selectedNote;

    if (note == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('메모를 찾을 수 없습니다')),
      );
    }

    _syncControllers(note);

    final dateStr = DateFormat('yyyy.MM.dd HH:mm').format(note.updatedAt);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          note.title.isEmpty ? '새 메모' : note.title,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: Icon(
              note.isFavorite ? Icons.star : Icons.star_outline,
              color: note.isFavorite ? Colors.amber : null,
            ),
            onPressed: () => provider.toggleFavorite(note.id),
          ),
          PopupMenuButton<String>(
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'delete', child: Text('삭제')),
            ],
            onSelected: (action) {
              if (action == 'delete') _confirmDelete(context, provider, note);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 제목
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: TextField(
              controller: _titleController,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                hintText: '제목',
                border: InputBorder.none,
              ),
              onChanged: (_) => _save(provider),
            ),
          ),

          // 날짜
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                dateStr,
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ),
          ),

          // 태그
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: NoteTagRow(note: note, provider: provider),
          ),

          const Divider(height: 20),

          // 본문
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: TextField(
                controller: _bodyController,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  hintText: '내용을 입력하세요...',
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 16, height: 1.7),
                textAlignVertical: TextAlignVertical.top,
                onChanged: (_) => _save(provider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    AppProvider provider,
    Note note,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('메모 삭제'),
        content: const Text('이 메모를 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteNote(note.id);
              Navigator.pop(context); // 다이얼로그
              Navigator.pop(context); // 편집기 화면
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
