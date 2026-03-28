import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/notebook.dart';
import '../models/tag.dart';
import '../widgets/note_list.dart';
import '../widgets/sync_panel.dart';
import '../screens/mobile_editor_screen.dart';

class MobileLayout extends StatelessWidget {
  const MobileLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTitle(provider)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearch(context, provider),
          ),
          const SyncButton(),
        ],
      ),
      drawer: Drawer(
        child: _MobileSidebar(provider: provider),
      ),
      body: NoteList(
        onNoteTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(
                value: provider,
                child: const MobileEditorScreen(),
              ),
            ),
          );
        },
      ),
      floatingActionButton:
          provider.sidebarMode == SidebarMode.notebook &&
                  provider.selectedNotebook != null
              ? FloatingActionButton(
                  onPressed: () async {
                    await provider.createNote();
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider.value(
                            value: provider,
                            child: const MobileEditorScreen(),
                          ),
                        ),
                      );
                    }
                  },
                  child: const Icon(Icons.add),
                )
              : null,
    );
  }

  String _currentTitle(AppProvider p) {
    if (p.searchQuery.isNotEmpty) return '검색 결과';
    if (p.sidebarMode == SidebarMode.favorites) return '즐겨찾기';
    if (p.sidebarMode == SidebarMode.tag && p.selectedTag != null) {
      return '#${p.selectedTag!.name}';
    }
    return p.selectedNotebook?.name ?? 'SimNote';
  }

  void _showSearch(BuildContext context, AppProvider provider) {
    showSearch(
      context: context,
      delegate: _NoteSearchDelegate(provider: provider),
    );
  }
}

class _NoteSearchDelegate extends SearchDelegate<void> {
  final AppProvider provider;

  _NoteSearchDelegate({required this.provider});

  @override
  String get searchFieldLabel => '메모 검색...';

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            provider.search('');
          },
        ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          provider.search('');
          close(context, null);
        },
      );

  @override
  Widget buildResults(BuildContext context) {
    provider.search(query);
    return _SearchResults(provider: provider);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    provider.search(query);
    return _SearchResults(provider: provider);
  }
}

class _SearchResults extends StatelessWidget {
  final AppProvider provider;

  const _SearchResults({required this.provider});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: provider,
      child: NoteList(
        onNoteTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(
                value: provider,
                child: const MobileEditorScreen(),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── 사이드바 (Drawer 안에 들어가는 버전) ──────────────────────

class _MobileSidebar extends StatelessWidget {
  final AppProvider provider;

  const _MobileSidebar({required this.provider});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Text(
              'SimNote',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(),

          // 즐겨찾기
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: const Text('즐겨찾기'),
            selected: provider.sidebarMode == SidebarMode.favorites,
            onTap: () {
              provider.selectFavorites();
              Navigator.pop(context);
            },
          ),

          const SizedBox(height: 8),

          // 폴더 섹션
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '폴더',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: () => _showAddNotebookDialog(context),
                ),
              ],
            ),
          ),
          ...provider.notebooks.map(
            (nb) => _NotebookTile(nb: nb, provider: provider),
          ),

          // 태그 섹션
          if (provider.allTags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
              child: Text(
                '태그',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ...provider.allTags.map(
              (tag) => _TagTile(tag: tag, provider: provider),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddNotebookDialog(BuildContext context) {
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

class _NotebookTile extends StatelessWidget {
  final Notebook nb;
  final AppProvider provider;

  const _NotebookTile({required this.nb, required this.provider});

  @override
  Widget build(BuildContext context) {
    final isSelected =
        provider.sidebarMode == SidebarMode.notebook &&
        provider.selectedNotebook?.id == nb.id;

    return ListTile(
      leading: const Icon(Icons.folder_outlined),
      title: Text(nb.name),
      selected: isSelected,
      onTap: () {
        provider.selectNotebook(nb);
        Navigator.pop(context);
      },
      trailing: PopupMenuButton<String>(
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'rename', child: Text('이름 변경')),
          const PopupMenuItem(value: 'delete', child: Text('삭제')),
        ],
        onSelected: (action) {
          if (action == 'rename') _showRenameDialog(context);
          if (action == 'delete') {
            provider.deleteNotebook(nb.id);
            Navigator.pop(context);
          }
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
        content: TextField(controller: controller, autofocus: true),
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

class _TagTile extends StatelessWidget {
  final Tag tag;
  final AppProvider provider;

  const _TagTile({required this.tag, required this.provider});

  @override
  Widget build(BuildContext context) {
    final isSelected =
        provider.sidebarMode == SidebarMode.tag &&
        provider.selectedTag?.id == tag.id;

    return ListTile(
      leading: const Icon(Icons.tag),
      title: Text(tag.name),
      selected: isSelected,
      onTap: () {
        provider.selectTag(tag);
        Navigator.pop(context);
      },
    );
  }
}
