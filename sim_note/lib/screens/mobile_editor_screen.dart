import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../export/note_exporter.dart';
import '../providers/app_provider.dart';
import '../models/note.dart';
import '../widgets/note_tag_row.dart';
import '../widgets/formatting_toolbar.dart';

class MobileEditorScreen extends StatefulWidget {
  const MobileEditorScreen({super.key});

  @override
  State<MobileEditorScreen> createState() => _MobileEditorScreenState();
}

class _MobileEditorScreenState extends State<MobileEditorScreen> {
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

  Future<void> _export(BuildContext ctx, Note note, String type) async {
    await note.notebook.load();
    await note.tags.load();
    final nbName   = note.notebook.value?.name ?? '기본';
    final tagNames = note.tags.map((t) => t.name).toList();
    try {
      if (type == 'pdf') {
        await NoteExporter.shareAsPdf(
            note: note, notebookName: nbName, tagNames: tagNames);
      } else {
        await NoteExporter.shareAsText(
            note: note, notebookName: nbName, tagNames: tagNames);
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text('내보내기 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final note     = provider.selectedNote;

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
          // 미리보기 토글
          IconButton(
            icon: Icon(_preview ? Icons.edit_outlined : Icons.visibility_outlined),
            tooltip: _preview ? '편집 모드' : '미리보기',
            onPressed: () {
              if (!_preview) _save(provider);
              setState(() => _preview = !_preview);
            },
          ),
          IconButton(
            icon: Icon(
              note.isFavorite ? Icons.star : Icons.star_outline,
              color: note.isFavorite ? Colors.amber : null,
            ),
            onPressed: () => provider.toggleFavorite(note.id),
          ),
          PopupMenuButton<String>(
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pdf',    child: Text('PDF로 내보내기')),
              PopupMenuItem(value: 'text',   child: Text('텍스트로 내보내기')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'delete', child: Text('삭제')),
            ],
            onSelected: (action) {
              if (action == 'delete') {
                _confirmDelete(context, provider, note);
              } else {
                _export(context, note, action);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 제목 ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: _preview
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_titleController.text,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w600)),
                  )
                : TextField(
                    controller: _titleController,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      hintText: '제목',
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => _save(provider),
                  ),
          ),

          // ── 날짜 ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(dateStr,
                  style: TextStyle(fontSize: 12, color: Colors.grey[400])),
            ),
          ),

          // ── 태그 ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: NoteTagRow(note: note, provider: provider),
          ),

          const Divider(height: 20),
          if (!_preview)
            FormattingToolbar(
              controller: _bodyController,
              onChanged: () => _save(provider),
            ),
          if (!_preview) const Divider(height: 1),

          // ── 본문: 편집 or 마크다운 미리보기 ──────────────
          Expanded(
            child: _preview
                ? Markdown(
                    data: _bodyController.text.isEmpty
                        ? '*내용이 없습니다*'
                        : _bodyController.text,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    styleSheet:
                        MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                      p:    const TextStyle(fontSize: 16, height: 1.7),
                      h1:   const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      h2:   const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      h3:   const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      code: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        backgroundColor: Theme.of(context)
                            .colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: 20, right: 20,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                    ),
                    child: TextField(
                      controller: _bodyController,
                      maxLines: null,
                      decoration: const InputDecoration(
                        hintText: '내용을 입력하세요...\n\n마크다운을 지원합니다:\n# 제목  **굵게**  *기울임*  `코드`',
                        border: InputBorder.none,
                      ),
                      style: const TextStyle(fontSize: 16, height: 1.7),
                      onChanged: (_) => _save(provider),
                    ),
                  ),
          ),
        ],
      ),
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
