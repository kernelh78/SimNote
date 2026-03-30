import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
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
    final regularFont = await PdfGoogleFonts.notoSansKRRegular();
    final boldFont    = await PdfGoogleFonts.notoSansKRBold();

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: const PdfPageFormat(
          210 * PdfPageFormat.mm,
          297 * PdfPageFormat.mm,
          marginAll: 18 * PdfPageFormat.mm,
        ),
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        build: (ctx) => _buildPdfWidgets(note, notebookName, tagNames),
      ),
    );

    final bytes = await doc.save();
    final file  = await _writeTmpBytes('${_safeFilename(note.title)}.pdf', bytes);
    await _share([XFile(file.path, mimeType: 'application/pdf')], note.title);
  }

  // ── PDF 위젯 빌드 ─────────────────────────────────────────
  static List<pw.Widget> _buildPdfWidgets(
      Note note, String notebookName, List<String> tagNames) {
    final widgets = <pw.Widget>[];

    // 제목
    widgets.add(pw.Text(
      note.title.isEmpty ? '제목 없음' : note.title,
      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
    ));
    widgets.add(pw.SizedBox(height: 6));

    // 메타 정보
    final metaParts = [
      '폴더: $notebookName',
      '수정일: ${_dateFmt.format(note.updatedAt)}',
      if (tagNames.isNotEmpty) '태그: ${tagNames.join(', ')}',
    ];
    widgets.add(pw.Text(
      metaParts.join('   ·   '),
      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
    ));
    widgets.add(pw.SizedBox(height: 10));
    widgets.add(pw.Divider(color: PdfColors.grey300));
    widgets.add(pw.SizedBox(height: 10));

    // 본문 파싱
    widgets.addAll(_parseMd(note.body));

    return widgets;
  }

  // ── 마크다운 → pw.Widget 변환 ────────────────────────────
  static List<pw.Widget> _parseMd(String md) {
    final result = <pw.Widget>[];
    final lines  = md.split('\n');
    bool  inPre  = false;
    final preBuf = StringBuffer();
    final listBuf = <String>[];
    bool  isBulletList = false;
    bool  isOrderedList = false;
    int   orderIndex = 0;

    void flushList() {
      if (listBuf.isEmpty) return;
      if (isBulletList) {
        for (final item in listBuf) {
          result.add(pw.Padding(
            padding: const pw.EdgeInsets.only(left: 12, bottom: 2),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('• ', style: const pw.TextStyle(fontSize: 12)),
                pw.Expanded(child: pw.Text(item, style: const pw.TextStyle(fontSize: 12))),
              ],
            ),
          ));
        }
      } else {
        for (int i = 0; i < listBuf.length; i++) {
          result.add(pw.Padding(
            padding: const pw.EdgeInsets.only(left: 12, bottom: 2),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('${i + orderIndex}.  ', style: const pw.TextStyle(fontSize: 12)),
                pw.Expanded(child: pw.Text(listBuf[i], style: const pw.TextStyle(fontSize: 12))),
              ],
            ),
          ));
        }
      }
      listBuf.clear();
      isBulletList = false;
      isOrderedList = false;
    }

    for (final raw in lines) {
      // 코드 블록
      if (raw.startsWith('```')) {
        if (!inPre) {
          flushList();
          inPre = true;
          preBuf.clear();
        } else {
          result.add(pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              preBuf.toString().trimRight(),
              style: pw.TextStyle(
                fontSize: 10,
                font: pw.Font.courier(),
              ),
            ),
          ));
          result.add(pw.SizedBox(height: 6));
          inPre = false;
        }
        continue;
      }
      if (inPre) { preBuf.writeln(raw); continue; }

      // 헤더
      if (raw.startsWith('### ')) {
        flushList();
        result.add(pw.SizedBox(height: 6));
        result.add(pw.Text(raw.substring(4),
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)));
        result.add(pw.SizedBox(height: 4));
        continue;
      }
      if (raw.startsWith('## ')) {
        flushList();
        result.add(pw.SizedBox(height: 8));
        result.add(pw.Text(raw.substring(3),
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)));
        result.add(pw.SizedBox(height: 4));
        continue;
      }
      if (raw.startsWith('# ')) {
        flushList();
        result.add(pw.SizedBox(height: 10));
        result.add(pw.Text(raw.substring(2),
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)));
        result.add(pw.SizedBox(height: 6));
        continue;
      }

      // 수평선
      if (RegExp(r'^[-*_]{3,}$').hasMatch(raw.trim())) {
        flushList();
        result.add(pw.Divider(color: PdfColors.grey300));
        continue;
      }

      // 인용
      if (raw.startsWith('> ')) {
        flushList();
        result.add(pw.Container(
          padding: const pw.EdgeInsets.only(left: 10, top: 4, bottom: 4),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              left: pw.BorderSide(color: PdfColors.grey400, width: 3),
            ),
          ),
          child: pw.Text(raw.substring(2),
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
        ));
        result.add(pw.SizedBox(height: 4));
        continue;
      }

      // 순서없는 목록
      final ulMatch = RegExp(r'^[*\-+] (.+)$').firstMatch(raw);
      if (ulMatch != null) {
        if (isOrderedList) { flushList(); }
        isBulletList = true;
        listBuf.add(ulMatch.group(1)!);
        continue;
      }

      // 순서있는 목록
      final olMatch = RegExp(r'^(\d+)\. (.+)$').firstMatch(raw);
      if (olMatch != null) {
        if (isBulletList) { flushList(); }
        if (!isOrderedList) {
          isOrderedList = true;
          orderIndex = int.parse(olMatch.group(1)!);
        }
        listBuf.add(olMatch.group(2)!);
        continue;
      }

      flushList();

      // 빈 줄
      if (raw.trim().isEmpty) {
        result.add(pw.SizedBox(height: 6));
        continue;
      }

      // 일반 단락 — 굵게/기울임 처리
      result.add(_richText(raw));
      result.add(pw.SizedBox(height: 4));
    }

    if (inPre && preBuf.isNotEmpty) {
      result.add(pw.Text(preBuf.toString(),
          style: pw.TextStyle(font: pw.Font.courier(), fontSize: 10)));
    }
    flushList();

    return result;
  }

  /// 인라인 굵게(**text**) 처리
  static pw.Widget _richText(String text) {
    // 단순화: **bold** 와 일반 텍스트를 RichText로 분리
    final spans  = <pw.TextSpan>[];
    final reg    = RegExp(r'\*\*(.+?)\*\*');
    int   cursor = 0;

    for (final m in reg.allMatches(text)) {
      if (m.start > cursor) {
        spans.add(pw.TextSpan(
          text: text.substring(cursor, m.start),
          style: const pw.TextStyle(fontSize: 12),
        ));
      }
      spans.add(pw.TextSpan(
        text: m.group(1),
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ));
      cursor = m.end;
    }
    if (cursor < text.length) {
      spans.add(pw.TextSpan(
        text: text.substring(cursor),
        style: const pw.TextStyle(fontSize: 12),
      ));
    }

    return pw.RichText(text: pw.TextSpan(children: spans));
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

  // ── 공통 유틸 ─────────────────────────────────────────────
  static String _safeFilename(String title) {
    if (title.trim().isEmpty) return '제목없음';
    return title.replaceAll(RegExp(r'[\\/:*?"<>|\n\r]'), '_').trim();
  }

  static Future<File> _writeTmp(String filename, String text) async {
    final dir = await getTemporaryDirectory();
    await Directory(dir.path).create(recursive: true);
    final file = File('${dir.path}/$filename');
    await file.writeAsString(text, flush: true);
    return file;
  }

  static Future<File> _writeTmpBytes(String filename, Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    await Directory(dir.path).create(recursive: true);
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
