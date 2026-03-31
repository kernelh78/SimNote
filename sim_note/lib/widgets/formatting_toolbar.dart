import 'package:flutter/material.dart';

class FormattingToolbar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;

  const FormattingToolbar({
    required this.controller,
    required this.onChanged,
    super.key,
  });

  // ── 인라인 감싸기 (Bold, Italic, Strikethrough, Mono) ──────────
  void _wrap(String prefix, String suffix) {
    final sel = controller.selection;
    if (!sel.isValid) return;
    final text = controller.text;
    final selected = sel.textInside(text);
    final newText = text.replaceRange(sel.start, sel.end, '$prefix$selected$suffix');
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: sel.start + prefix.length + selected.length + suffix.length,
      ),
    );
    onChanged();
  }

  // ── 줄 접두어 설정 (제목, 목록, 인용 등) ──────────────────────
  void _setLinePrefix(String prefix) {
    final text = controller.text;
    final offset = controller.selection.baseOffset.clamp(0, text.length);
    final lineStart = text.lastIndexOf('\n', offset - 1) + 1;
    final lineEnd = text.indexOf('\n', offset);
    final line = text.substring(lineStart, lineEnd == -1 ? text.length : lineEnd);
    // 기존 마크다운 접두어 제거
    final cleaned = line.replaceFirst(RegExp(r'^(#{1,3} |> |- |– |\d+\. )'), '');
    final newLine = '$prefix$cleaned';
    final newText = text.replaceRange(lineStart, lineStart + line.length, newLine);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: lineStart + newLine.length,
      ),
    );
    onChanged();
  }

  // ── 표 삽입 ────────────────────────────────────────────────────
  void _insertTable() {
    const table = '\n| 열1 | 열2 | 열3 |\n|-----|-----|-----|\n| 내용 | 내용 | 내용 |\n';
    final offset = controller.selection.baseOffset.clamp(0, controller.text.length);
    final newText = controller.text.replaceRange(offset, offset, table);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: offset + table.length),
    );
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface;

    return SizedBox(
      height: 36,
      child: Row(
        children: [
          const SizedBox(width: 8),

          // ── 굵게 ───────────────────────────────────────────────
          _ToolbarButton(
            onPressed: () => _wrap('**', '**'),
            tooltip: '굵게',
            child: Text('B',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14, color: color)),
          ),

          // ── 기울임 ─────────────────────────────────────────────
          _ToolbarButton(
            onPressed: () => _wrap('*', '*'),
            tooltip: '기울임',
            child: Text('I',
                style: TextStyle(
                    fontStyle: FontStyle.italic, fontSize: 14, color: color)),
          ),

          // ── 취소선 ─────────────────────────────────────────────
          _ToolbarButton(
            onPressed: () => _wrap('~~', '~~'),
            tooltip: '취소선',
            child: Text('S',
                style: TextStyle(
                    decoration: TextDecoration.lineThrough,
                    fontSize: 14,
                    color: color)),
          ),

          // ── 구분선 ─────────────────────────────────────────────
          const SizedBox(width: 4),
          VerticalDivider(width: 1, thickness: 1, color: theme.dividerColor),
          const SizedBox(width: 4),

          // ── 문단 스타일 팝업 ───────────────────────────────────
          PopupMenuButton<String>(
            tooltip: '문단 스타일',
            offset: const Offset(0, 36),
            onSelected: (value) {
              switch (value) {
                case 'h1':     _setLinePrefix('# ');
                case 'h2':     _setLinePrefix('## ');
                case 'h3':     _setLinePrefix('### ');
                case 'body':   _setLinePrefix('');
                case 'mono':   _wrap('`', '`');
                case 'bullet': _setLinePrefix('- ');
                case 'dash':   _setLinePrefix('– ');
                case 'num':    _setLinePrefix('1. ');
                case 'quote':  _setLinePrefix('> ');
              }
            },
            itemBuilder: (_) => [
              _styleItem('h1',     '제목',         const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              _styleItem('h2',     '머리말',       const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              _styleItem('h3',     '부머리말',     const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              _styleItem('body',   '본문',         const TextStyle(fontSize: 13)),
              _styleItem('mono',   '모노 스타일',  const TextStyle(fontSize: 13, fontFamily: 'monospace')),
              const PopupMenuDivider(),
              _styleItem('bullet', '• 구분점 목록', const TextStyle(fontSize: 13)),
              _styleItem('dash',   '– 대시 목록',  const TextStyle(fontSize: 13)),
              _styleItem('num',    '1. 번호 목록', const TextStyle(fontSize: 13)),
              _styleItem('quote',  '| 블록 인용',  TextStyle(fontSize: 13, color: Colors.grey[600])),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Aa', style: TextStyle(fontSize: 13, color: color)),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down, size: 16, color: color),
                ],
              ),
            ),
          ),

          // ── 구분선 ─────────────────────────────────────────────
          const SizedBox(width: 4),
          VerticalDivider(width: 1, thickness: 1, color: theme.dividerColor),
          const SizedBox(width: 4),

          // ── 표 삽입 ────────────────────────────────────────────
          _ToolbarButton(
            onPressed: _insertTable,
            tooltip: '표 삽입',
            child: Icon(Icons.table_chart_outlined, size: 16, color: color),
          ),

          const Spacer(),
        ],
      ),
    );
  }

  PopupMenuItem<String> _styleItem(String value, String label, TextStyle style) {
    return PopupMenuItem<String>(
      value: value,
      child: Text(label, style: style),
    );
  }
}

// ── 툴바 버튼 헬퍼 위젯 ────────────────────────────────────────────
class _ToolbarButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String tooltip;
  final Widget child;

  const _ToolbarButton({
    required this.onPressed,
    required this.tooltip,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: child,
        ),
      ),
    );
  }
}
