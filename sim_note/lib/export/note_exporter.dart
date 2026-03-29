import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/note.dart';

final _dateFmt = DateFormat('yyyy-MM-dd HH:mm');

class NoteExporter {
  // ── 텍스트(.md) 내보내기 ──────────────────────────────────
  static Future<void> shareAsText({
    required Note note,
    required String notebookName,
    required List<String> tagNames,
  }) async {
    final content = _buildMarkdown(note, notebookName, tagNames);
    final file    = await _writeTmp('${_safeFilename(note.title)}.md', content);
    await _share([XFile(file.path, mimeType: 'text/plain')], note.title);
  }

  // ── PDF 내보내기 ──────────────────────────────────────────
  static Future<void> shareAsPdf({
    required Note note,
    required String notebookName,
    required List<String> tagNames,
  }) async {
    final html  = _buildHtml(note, notebookName, tagNames);
    final bytes = await Printing.convertHtml(
      format: const PdfPageFormat(
        210 * PdfPageFormat.mm,
        297 * PdfPageFormat.mm,
        marginAll: 18 * PdfPageFormat.mm,
      ),
      html: html,
    );
    final file = await _writeTmpBytes('${_safeFilename(note.title)}.pdf', bytes);
    await _share([XFile(file.path, mimeType: 'application/pdf')], note.title);
  }

  // ── 마크다운 생성 ─────────────────────────────────────────
  static String _buildMarkdown(
      Note note, String notebookName, List<String> tagNames) {
    final buf = StringBuffer();
    buf.writeln('# ${note.title}');
    buf.writeln();
    buf.writeln('- **폴더:** $notebookName');
    buf.writeln('- **작성일:** ${_dateFmt.format(note.createdAt)}');
    buf.writeln('- **수정일:** ${_dateFmt.format(note.updatedAt)}');
    if (tagNames.isNotEmpty) {
      buf.writeln('- **태그:** ${tagNames.join(', ')}');
    }
    buf.writeln();
    buf.writeln('---');
    buf.writeln();
    buf.write(note.body);
    return buf.toString();
  }

  // ── HTML 생성 (PDF 변환용) ────────────────────────────────
  static String _buildHtml(
      Note note, String notebookName, List<String> tagNames) {
    final body = _markdownToHtml(note.body);
    final meta = [
      '📁 $notebookName',
      '📅 ${_dateFmt.format(note.updatedAt)}',
      if (tagNames.isNotEmpty) '🏷 ${tagNames.join(', ')}',
    ].join(' &nbsp;·&nbsp; ');

    return '''<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<style>
  @import url('https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;700&display=swap');
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: "Noto Sans KR", "Apple SD Gothic Neo", sans-serif;
    font-size: 14px; line-height: 1.8; color: #1a1a1a;
    padding: 0 4px;
  }
  h1.title { font-size: 26px; font-weight: 700; margin-bottom: 8px; }
  .meta { font-size: 12px; color: #888; margin-bottom: 16px; }
  hr { border: none; border-top: 1px solid #e0e0e0; margin: 16px 0; }
  h1 { font-size: 22px; font-weight: 700; margin: 20px 0 8px; }
  h2 { font-size: 18px; font-weight: 700; margin: 16px 0 6px; }
  h3 { font-size: 15px; font-weight: 700; margin: 12px 0 4px; }
  p  { margin: 8px 0; }
  ul, ol { margin: 8px 0; padding-left: 24px; }
  li { margin: 3px 0; }
  blockquote {
    border-left: 3px solid #ccc; margin: 10px 0;
    padding-left: 12px; color: #555;
  }
  code {
    background: #f4f4f4; border-radius: 3px;
    padding: 1px 5px; font-family: monospace; font-size: 13px;
  }
  pre {
    background: #f4f4f4; border-radius: 6px;
    padding: 12px; overflow-x: auto; margin: 10px 0;
  }
  pre code { background: none; padding: 0; }
  strong { font-weight: 700; }
  em { font-style: italic; }
</style>
</head>
<body>
  <h1 class="title">${_esc(note.title.isEmpty ? '제목 없음' : note.title)}</h1>
  <div class="meta">$meta</div>
  <hr>
  $body
</body>
</html>''';
  }

  // ── 마크다운 → HTML 변환 ──────────────────────────────────
  static String _markdownToHtml(String md) {
    final lines  = md.split('\n');
    final buf    = StringBuffer();
    bool  inPre  = false;
    bool  inList = false;
    bool  inOl   = false;
    final preBuf = StringBuffer();

    void flushList() {
      if (inList)     { buf.writeln('</ul>'); inList = false; }
      else if (inOl)  { buf.writeln('</ol>'); inOl   = false; }
    }

    for (final raw in lines) {
      // ── 코드 블록 ─────────────────────────────────────────
      if (raw.startsWith('```')) {
        if (!inPre) {
          flushList();
          inPre = true;
          buf.write('<pre><code>');
          preBuf.clear();
        } else {
          buf.write(_esc(preBuf.toString()));
          buf.writeln('</code></pre>');
          inPre = false;
        }
        continue;
      }
      if (inPre) { preBuf.writeln(raw); continue; }

      // ── 헤더 ──────────────────────────────────────────────
      final h3 = _tryHeader(raw, '### ', 'h3');
      if (h3 != null) { flushList(); buf.writeln(h3); continue; }
      final h2 = _tryHeader(raw, '## ', 'h2');
      if (h2 != null) { flushList(); buf.writeln(h2); continue; }
      final h1 = _tryHeader(raw, '# ', 'h1');
      if (h1 != null) { flushList(); buf.writeln(h1); continue; }

      // ── 수평선 ─────────────────────────────────────────────
      if (RegExp(r'^[-*_]{3,}$').hasMatch(raw.trim())) {
        flushList(); buf.writeln('<hr>'); continue;
      }

      // ── 인용 ───────────────────────────────────────────────
      if (raw.startsWith('> ')) {
        flushList();
        buf.writeln('<blockquote>${_inline(raw.substring(2))}</blockquote>');
        continue;
      }

      // ── 순서없는 목록 ──────────────────────────────────────
      final ulMatch = RegExp(r'^[*\-+] (.+)$').firstMatch(raw);
      if (ulMatch != null) {
        if (inOl) { buf.writeln('</ol>'); inOl = false; }
        if (!inList) { buf.write('<ul>'); inList = true; }
        buf.writeln('<li>${_inline(ulMatch.group(1)!)}</li>');
        continue;
      }

      // ── 순서있는 목록 ──────────────────────────────────────
      final olMatch = RegExp(r'^\d+\. (.+)$').firstMatch(raw);
      if (olMatch != null) {
        if (inList) { buf.writeln('</ul>'); inList = false; }
        if (!inOl) { buf.write('<ol>'); inOl = true; }
        buf.writeln('<li>${_inline(olMatch.group(1)!)}</li>');
        continue;
      }

      flushList();

      // ── 빈 줄 ─────────────────────────────────────────────
      if (raw.trim().isEmpty) { buf.writeln('<br>'); continue; }

      // ── 일반 단락 ─────────────────────────────────────────
      buf.writeln('<p>${_inline(raw)}</p>');
    }

    if (inPre)  { buf.write(_esc(preBuf.toString())); buf.writeln('</code></pre>'); }
    if (inList) buf.writeln('</ul>');
    if (inOl)   buf.writeln('</ol>');

    return buf.toString();
  }

  static String? _tryHeader(String line, String prefix, String tag) {
    if (!line.startsWith(prefix)) return null;
    return '<$tag>${_inline(line.substring(prefix.length))}</$tag>';
  }

  /// 인라인 마크다운 변환 (bold, italic, code, 링크 등)
  static String _inline(String text) {
    String s = _esc(text);
    s = s.replaceAllMapped(RegExp(r'\*\*\*(.+?)\*\*\*'),
        (m) => '<strong><em>${m[1]}</em></strong>');
    s = s.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'),
        (m) => '<strong>${m[1]}</strong>');
    s = s.replaceAllMapped(RegExp(r'\*(.+?)\*'),
        (m) => '<em>${m[1]}</em>');
    s = s.replaceAllMapped(RegExp(r'`(.+?)`'),
        (m) => '<code>${m[1]}</code>');
    s = s.replaceAllMapped(RegExp(r'\[(.+?)\]\((.+?)\)'),
        (m) => '<a href="${m[2]}">${m[1]}</a>');
    return s;
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  // ── 공통 유틸 ─────────────────────────────────────────────
  static String _safeFilename(String title) {
    if (title.trim().isEmpty) return '제목없음';
    return title.replaceAll(RegExp(r'[\\/:*?"<>|\n\r]'), '_').trim();
  }

  static Future<File> _writeTmp(String filename, String text) async {
    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(text, flush: true);
    return file;
  }

  static Future<File> _writeTmpBytes(String filename, Uint8List bytes) async {
    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> _share(List<XFile> files, String subject) async {
    await SharePlus.instance.share(
      ShareParams(files: files, subject: subject),
    );
  }
}
