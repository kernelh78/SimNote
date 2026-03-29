import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../sync/sync_conflict.dart';

final _dateFmt = DateFormat('MM/dd HH:mm');

/// 동기화 충돌 해결 다이얼로그
/// 반환값: 'local' | 'remote' | 'both'
Future<String?> showConflictDialog(
  BuildContext context,
  SyncConflict conflict,
) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ConflictDialog(conflict: conflict),
  );
}

class _ConflictDialog extends StatefulWidget {
  final SyncConflict conflict;
  const _ConflictDialog({required this.conflict});

  @override
  State<_ConflictDialog> createState() => _ConflictDialogState();
}

class _ConflictDialogState extends State<_ConflictDialog> {
  int _selected = 0; // 0=local, 1=remote

  @override
  Widget build(BuildContext context) {
    final c = widget.conflict;
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('동기화 충돌'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${c.title}" 노트를 양쪽 기기에서 모두 수정했습니다.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            // 내 버전
            _VersionCard(
              label: '내 버전',
              updatedAt: c.localUpdatedAt,
              body: c.localBody,
              selected: _selected == 0,
              color: theme.colorScheme.primaryContainer,
              onTap: () => setState(() => _selected = 0),
            ),
            const SizedBox(height: 8),
            // 상대 버전
            _VersionCard(
              label: '상대 기기 버전',
              updatedAt: c.remoteUpdatedAt,
              body: c.remoteBody,
              selected: _selected == 1,
              color: theme.colorScheme.secondaryContainer,
              onTap: () => setState(() => _selected = 1),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'both'),
          child: const Text('둘 다 유지'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, _selected == 0 ? 'local' : 'remote'),
          child: const Text('선택한 버전 유지'),
        ),
      ],
    );
  }
}

class _VersionCard extends StatelessWidget {
  final String label;
  final DateTime updatedAt;
  final String body;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _VersionCard({
    required this.label,
    required this.updatedAt,
    required this.body,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (selected)
                  Icon(Icons.check_circle,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary),
                if (selected) const SizedBox(width: 4),
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                Text(_dateFmt.format(updatedAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              body.isEmpty ? '(내용 없음)' : body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
