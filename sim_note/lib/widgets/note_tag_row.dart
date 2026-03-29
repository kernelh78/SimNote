import 'package:flutter/material.dart';
import '../models/note.dart';
import '../providers/app_provider.dart';

/// 태그 표시 + 추가 위젯. NoteEditor와 MobileEditorScreen 공용.
class NoteTagRow extends StatefulWidget {
  final Note note;
  final AppProvider provider;

  const NoteTagRow({super.key, required this.note, required this.provider});

  @override
  State<NoteTagRow> createState() => _NoteTagRowState();
}

class _NoteTagRowState extends State<NoteTagRow> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List _tags = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  @override
  void didUpdateWidget(NoteTagRow old) {
    super.didUpdateWidget(old);
    if (!identical(old.note, widget.note)) {
      _loadTags();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    await widget.note.tags.load();
    if (mounted) setState(() => _tags = widget.note.tags.toList());
  }

  Future<void> _addTag(String value) async {
    final name = value.replaceAll('#', '').trim();
    if (name.isEmpty) return;
    _controller.clear();
    if (mounted) setState(() => _showSuggestions = false);
    await widget.provider.addTagToNote(widget.note.id, name);
    await _loadTags();
  }

  @override
  Widget build(BuildContext context) {
    final tagIds = _tags.map((t) => t.id).toSet();
    final suggestions = widget.provider.allTags
        .where((t) => !tagIds.contains(t.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ..._tags.map(
              (tag) => Chip(
                label: Text('#${tag.name}',
                    style: const TextStyle(fontSize: 12)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
                deleteIconColor: Colors.grey,
                onDeleted: () async {
                  await widget.provider
                      .removeTagFromNote(widget.note.id, tag.id);
                  await _loadTags();
                },
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    decoration: const InputDecoration(
                      hintText: '태그 추가...',
                      hintStyle: TextStyle(fontSize: 12),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 12),
                    onTap: () => setState(() => _showSuggestions = true),
                    onSubmitted: _addTag,
                  ),
                ),
                InkWell(
                  onTap: () => _addTag(_controller.text),
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.add, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (_showSuggestions && suggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                Text('기존 태그:',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ...suggestions.map(
                  (tag) => GestureDetector(
                    onTap: () async {
                      await widget.provider
                          .addTagToNote(widget.note.id, tag.name);
                      await _loadTags();
                      if (mounted) setState(() => _showSuggestions = false);
                    },
                    child: Chip(
                      label: Text('#${tag.name}',
                          style: const TextStyle(fontSize: 11)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _showSuggestions = false),
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('닫기', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
