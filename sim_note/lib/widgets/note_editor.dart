import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/note.dart';

class NoteEditor extends StatefulWidget {
  const NoteEditor({super.key});

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _tagController = TextEditingController();
  Note? _loadedNote;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _tagController.dispose();
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

    _syncControllers(note);

    if (note == null) {
      return const Center(
        child: Text(
          '메모를 선택하거나 새 메모를 만드세요',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final dateStr = DateFormat('yyyy년 MM월 dd일 HH:mm').format(note.updatedAt);

    return Column(
      children: [
        // 툴바
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              // 즐겨찾기
              IconButton(
                icon: Icon(
                  note.isFavorite ? Icons.star : Icons.star_outline,
                  color: note.isFavorite ? Colors.amber : null,
                ),
                tooltip: '즐겨찾기',
                onPressed: () => provider.toggleFavorite(note.id),
              ),
              const Spacer(),
              // 저장
              IconButton(
                icon: const Icon(Icons.save_outlined),
                tooltip: '저장 (Ctrl+S)',
                onPressed: () => _save(provider),
              ),
              // 삭제
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: '삭제',
                onPressed: () => _confirmDelete(context, provider, note),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // 제목
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: TextField(
            controller: _titleController,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              hintText: '제목',
              border: InputBorder.none,
            ),
            onSubmitted: (_) => _save(provider),
          ),
        ),

        // 날짜
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              dateStr,
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
          ),
        ),

        // 태그 입력
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: _TagRow(note: note, provider: provider),
        ),

        const Divider(height: 24),

        // 본문
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: TextField(
              controller: _bodyController,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                hintText: '내용을 입력하세요...',
                border: InputBorder.none,
              ),
              style: const TextStyle(fontSize: 15, height: 1.7),
              textAlignVertical: TextAlignVertical.top,
              onChanged: (_) => _save(provider),
            ),
          ),
        ),
      ],
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
              Navigator.pop(context);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  final Note note;
  final AppProvider provider;

  const _TagRow({required this.note, required this.provider});

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();

    return FutureBuilder(
      future: () async {
        await note.tags.load();
        return note.tags.toList();
      }(),
      builder: (context, snapshot) {
        final tags = snapshot.data ?? [];

        return Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ...tags.map(
              (tag) => Chip(
                label: Text('#${tag.name}', style: const TextStyle(fontSize: 12)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
                deleteIconColor: Colors.grey,
                onDeleted: () => provider.removeTagFromNote(note.id, tag.id),
              ),
            ),
            // 태그 추가 입력
            SizedBox(
              width: 120,
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: '태그 추가...',
                  hintStyle: TextStyle(fontSize: 12),
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 12),
                onSubmitted: (value) {
                  final tag = value.replaceAll('#', '').trim();
                  if (tag.isNotEmpty) {
                    provider.addTagToNote(note.id, tag);
                    controller.clear();
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
