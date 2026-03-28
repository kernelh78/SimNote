import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/notebook.dart';
import '../models/tag.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // 검색창
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: '검색...',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: provider.search,
            ),
          ),
          const SizedBox(height: 16),

          // 즐겨찾기
          _SidebarItem(
            icon: Icons.star_outline,
            label: '즐겨찾기',
            isSelected: provider.sidebarMode == SidebarMode.favorites,
            onTap: provider.selectFavorites,
          ),
          const SizedBox(height: 8),

          // 폴더 섹션
          _SectionHeader(
            label: '폴더',
            onAdd: () => _showAddNotebookDialog(context, provider),
          ),
          ...provider.notebooks.map(
            (nb) => _NotebookItem(nb: nb, provider: provider),
          ),
          const SizedBox(height: 8),

          // 태그 섹션
          if (provider.allTags.isNotEmpty) ...[
            const _SectionHeader(label: '태그'),
            ...provider.allTags.map(
              (tag) => _TagItem(tag: tag, provider: provider),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddNotebookDialog(BuildContext context, AppProvider provider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('새 폴더'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '폴더 이름'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                provider.createNotebook(controller.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('만들기'),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 18),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      selected: isSelected,
      selectedTileColor:
          Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      onTap: onTap,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final VoidCallback? onAdd;

  const _SectionHeader({required this.label, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (onAdd != null)
            InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(4),
              child: const Icon(Icons.add, size: 16),
            ),
        ],
      ),
    );
  }
}

class _NotebookItem extends StatelessWidget {
  final Notebook nb;
  final AppProvider provider;

  const _NotebookItem({required this.nb, required this.provider});

  @override
  Widget build(BuildContext context) {
    final isSelected =
        provider.sidebarMode == SidebarMode.notebook &&
        provider.selectedNotebook?.id == nb.id;

    return ListTile(
      dense: true,
      leading: const Icon(Icons.folder_outlined, size: 18),
      title: Text(nb.name, style: const TextStyle(fontSize: 14)),
      selected: isSelected,
      selectedTileColor:
          Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      onTap: () => provider.selectNotebook(nb),
      trailing: PopupMenuButton<String>(
        iconSize: 16,
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'rename', child: Text('이름 변경')),
          const PopupMenuItem(value: 'delete', child: Text('삭제')),
        ],
        onSelected: (action) {
          if (action == 'rename') _showRenameDialog(context);
          if (action == 'delete') provider.deleteNotebook(nb.id);
        },
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: nb.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('폴더 이름 변경'),
        content: TextField(
          controller: controller,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                provider.renameNotebook(nb.id, controller.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('변경'),
          ),
        ],
      ),
    );
  }
}

class _TagItem extends StatelessWidget {
  final Tag tag;
  final AppProvider provider;

  const _TagItem({required this.tag, required this.provider});

  @override
  Widget build(BuildContext context) {
    final isSelected =
        provider.sidebarMode == SidebarMode.tag &&
        provider.selectedTag?.id == tag.id;

    return ListTile(
      dense: true,
      leading: const Icon(Icons.tag, size: 18),
      title: Text(tag.name, style: const TextStyle(fontSize: 14)),
      selected: isSelected,
      selectedTileColor:
          Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      onTap: () => provider.selectTag(tag),
    );
  }
}
