import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/note.dart';

class NoteList extends StatelessWidget {
  final VoidCallback? onNoteTap;

  const NoteList({super.key, this.onNoteTap});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final notes = provider.currentNotes;

    return Column(
      children: [
        // 헤더
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _title(provider),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (provider.sidebarMode == SidebarMode.notebook &&
                  provider.selectedNotebook != null)
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  tooltip: '새 메모',
                  onPressed: provider.createNote,
                ),
            ],
          ),
        ),
        const Divider(height: 1),

        // 목록
        Expanded(
          child: notes.isEmpty
              ? const Center(
                  child: Text(
                    '메모가 없습니다',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.separated(
                  itemCount: notes.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) => _NoteListItem(
                    note: notes[index],
                    provider: provider,
                    onTap: onNoteTap,
                  ),
                ),
        ),
      ],
    );
  }

  String _title(AppProvider p) {
    if (p.searchQuery.isNotEmpty) return '검색 결과';
    if (p.sidebarMode == SidebarMode.favorites) return '즐겨찾기';
    if (p.sidebarMode == SidebarMode.tag && p.selectedTag != null) {
      return '#${p.selectedTag!.name}';
    }
    return p.selectedNotebook?.name ?? '';
  }
}

class _NoteListItem extends StatelessWidget {
  final Note note;
  final AppProvider provider;
  final VoidCallback? onTap;

  const _NoteListItem({
    required this.note,
    required this.provider,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = provider.selectedNote?.id == note.id;
    final dateStr = DateFormat('MM.dd HH:mm').format(note.updatedAt);

    return InkWell(
      onTap: () {
        provider.selectNote(note);
        onTap?.call();
      },
      child: Container(
        color: isSelected
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4)
            : null,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    note.title.isEmpty ? '제목 없음' : note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => provider.toggleFavorite(note.id),
                  child: Icon(
                    note.isFavorite ? Icons.star : Icons.star_outline,
                    size: 16,
                    color: note.isFavorite ? Colors.amber : Colors.grey[400],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              note.body.isEmpty ? '내용 없음' : note.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              dateStr,
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}
