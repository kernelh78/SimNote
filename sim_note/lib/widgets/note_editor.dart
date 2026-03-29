import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/note.dart';
import 'note_tag_row.dart';
import 'sync_panel.dart';

class NoteEditor extends StatefulWidget {
  const NoteEditor({super.key});

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  final _titleController = TextEditingController();
  final _bodyController  = TextEditingController();
  Note? _loadedNote;
  bool _preview = false;

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
      _bodyController.text  = note?.body  ?? '';
      _preview = false;
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
    final note     = provider.selectedNote;

    _syncControllers(note);

    if (note == null) {
      return Column(
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: const Row(children: [Spacer(), SyncButton()]),
          ),
          const Divider(height: 1),
          const Expanded(
            child: Center(
              child: Text('메모를 선택하거나 새 메모를 만드세요',
                  style: TextStyle(color: Colors.grey)),
            ),
          ),
        ],
      );
    }

    final dateStr = DateFormat('yyyy년 MM월 dd일 HH:mm').format(note.updatedAt);

    return Column(
      children: [
        // ── 툴바 ─────────────────────────────────────────────
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                icon: Icon(note.isFavorite ? Icons.star : Icons.star_outline,
                    color: note.isFavorite ? Colors.amber : null),
                tooltip: '즐겨찾기',
                onPressed: () => provider.toggleFavorite(note.id),
              ),
              const Spacer(),
              // 미리보기 토글
              IconButton(
                icon: Icon(_preview ? Icons.edit_outlined : Icons.visibility_outlined),
                tooltip: _preview ? '편집 모드' : '미리보기',
                onPressed: () {
                  if (!_preview) _save(provider);
                  setState(() => _preview = !_preview);
                },
              ),
              if (!_preview)
                IconButton(
                  icon: const Icon(Icons.save_outlined),
                  tooltip: '저장 (Ctrl+S)',
                  onPressed: () => _save(provider),
                ),
              if (!_preview)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '삭제',
                  onPressed: () => _confirmDelete(context, provider, note),
                ),
              const SyncButton(),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── 제목 / 날짜 / 태그 (항상 표시) ──────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
          child: _preview
              ? Text(_titleController.text,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600))
              : TextField(
                  controller: _titleController,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(hintText: '제목', border: InputBorder.none),
                  onSubmitted: (_) => _save(provider),
                ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(dateStr,
              style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
          child: NoteTagRow(note: note, provider: provider),
        ),
        const Divider(height: 20),

        // ── 본문: 편집 or 마크다운 미리보기 ──────────────────
        Expanded(
          child: _preview
              ? Markdown(
                  data: _bodyController.text.isEmpty
                      ? '*내용이 없습니다*'
                      : _bodyController.text,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    p:          const TextStyle(fontSize: 15, height: 1.7),
                    h1:         const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    h2:         const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    h3:         const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    code:       TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                  backgroundColor: Theme.of(context)
                                      .colorScheme.surfaceContainerHighest,
                                ),
                    blockquote: TextStyle(color: Colors.grey[600], fontSize: 15, height: 1.7),
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                    child: TextField(
                      controller: _bodyController,
                      maxLines: null,
                      decoration: const InputDecoration(
                        hintText: '내용을 입력하세요...\n\n마크다운을 지원합니다:\n# 제목  **굵게**  *기울임*  `코드`',
                        border: InputBorder.none,
                      ),
                      style: const TextStyle(fontSize: 15, height: 1.7),
                      onChanged: (_) => _save(provider),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, AppProvider provider, Note note) {
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
