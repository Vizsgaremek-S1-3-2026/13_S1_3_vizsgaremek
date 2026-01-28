import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:intl/intl.dart';

class PdfService {
  static Future<Uint8List> generateGradesReport({
    required String quizTitle,
    required String groupName,
    required List<Map<String, dynamic>> students,
    required Map<String, dynamic> stats,
    Map<String, dynamic>? quizData,
    // Toggle Configuration
    bool includeStats = true,
    bool includeStudentList = true,
    bool includeStudentDetails = false,
    bool includeQuestions = false,
    bool includeWarnings = false,
    String warningLayout = 'grouped',
    required Map<String, dynamic> options,
  }) async {
    final pdf = pw.Document();

    // Extract Options
    final orientation = options['orientation'] == 'landscape'
        ? pw.PageOrientation.landscape
        : pw.PageOrientation.portrait;
    final compactMode = options['compactMode'] == true;
    final rowNumbering = options['rowNumbering'] == true;
    final stripedRows = options['stripedRows'] == true;
    final showBorders = options['showBorders'] == true;
    final anonymize = options['anonymize'] == true;
    final showSignature = options['signature'] == true;
    final showTimestamp = options['timestamp'] == true;
    final showCoverPage = options['coverPage'] == true;
    final showAnswerKey = options['answerKey'] == true;
    final onlyIncorrect = options['onlyIncorrect'] == true;
    final customNote = options['customNote'] as String? ?? '';
    final showStudentId = options['showStudentId'] == true;
    final watermarkText = options['watermark'] as String? ?? '';
    final showPageNumbers = options['pageNumbers'] == true;
    final passFail = options['passFail'] == true;
    final pageSizeStr = options['pageSize'] as String? ?? 'a4';
    final grayscale = options['grayscale'] == true;
    final showPoints = options['showPoints'] == true;
    final hideCorrect = options['hideCorrect'] == true;

    // Load Logo
    pw.ImageProvider? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/logo/logo_2.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {
      // Fallback
    }

    // Fonts
    final fontBase = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final theme = pw.ThemeData.withFont(base: fontBase, bold: fontBold);

    final pdfPageFormat = pageSizeStr == 'letter'
        ? PdfPageFormat.letter
        : PdfPageFormat.a4;

    final pageTheme = pw.PageTheme(
      theme: theme,
      pageFormat: orientation == pw.PageOrientation.landscape
          ? pdfPageFormat.landscape
          : pdfPageFormat,
      orientation: orientation,
      margin: compactMode
          ? const pw.EdgeInsets.all(16)
          : const pw.EdgeInsets.all(32),
      buildBackground: (context) => watermarkText.isNotEmpty
          ? pw.FullPage(
              ignoreMargins: true,
              child: pw.Opacity(
                opacity: 0.1,
                child: pw.Center(
                  child: pw.Transform.rotate(
                    angle: -0.5,
                    child: pw.Text(
                      watermarkText,
                      style: pw.TextStyle(
                        fontSize: 60,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : pw.Container(),
    );

    // Helpers
    PdfColor getStatusColor(bool positive) {
      if (grayscale) return PdfColors.grey700;
      return positive ? PdfColors.green : PdfColors.red;
    }

    PdfColor getGradeColor(dynamic grade) {
      if (grade == null) return PdfColors.black;
      if (grayscale) return PdfColors.black;
      switch (grade) {
        case 1:
          return PdfColors.red;
        case 2:
          return PdfColors.orange;
        case 3:
          return PdfColors.amber;
        case 4:
          return PdfColors.lime700;
        case 5:
          return PdfColors.green;
        default:
          return PdfColors.black;
      }
    }

    String formatTime() =>
        DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    pw.Widget buildFooter(pw.Context context) {
      return pw.Column(
        children: [
          if (customNote.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(
                customNote,
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (showTimestamp)
                pw.Text(
                  'Generálva: ${formatTime()}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
                ),
              if (showPageNumbers)
                pw.Text(
                  'Oldal ${context.pageNumber} / ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
                ),
            ],
          ),
        ],
      );
    }

    pw.Widget buildHeader(String title) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'cQuizy Admin Report',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey,
                    ),
                  ),
                  pw.Text(
                    quizTitle,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    groupName,
                    style: const pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              if (logoImage != null) pw.Image(logoImage, width: 40, height: 40),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(color: PdfColors.pink400, thickness: 1.5),
          pw.SizedBox(height: 20),
        ],
      );
    }

    String getStudentName(Map<String, dynamic> s, int index) {
      if (anonymize) {
        return 'Tanuló #${index + 1}';
      }
      return showStudentId && s['id'] != null
          ? '${s['name']} (${s['id']})'
          : s['name'];
    }

    // 0. Cover Page
    if (showCoverPage) {
      pdf.addPage(
        pw.Page(
          pageTheme: pageTheme,
          build: (context) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                if (logoImage != null)
                  pw.Image(logoImage, width: 80, height: 80),
                pw.SizedBox(height: 20),
                pw.Text(
                  quizTitle,
                  style: pw.TextStyle(
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  groupName,
                  style: const pw.TextStyle(
                    fontSize: 18,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 40),
                pw.Text(
                  'Tanári Jelentés',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Generálva: ${formatTime()}',
                  style: const pw.TextStyle(
                    fontSize: 14,
                    color: PdfColors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 1. Overview Page (Stats + List)

    if (includeStats || includeStudentList) {
      pdf.addPage(
        pw.MultiPage(
          pageTheme: pageTheme,
          footer: buildFooter,
          header: (context) => buildHeader('Eredmények Összesítése'),
          build: (context) => [
            if (includeStats) ...[
              pw.Text(
                'Statisztika',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Összesen', '${students.length} fő'),
                    _buildStatItem(
                      'Átlag',
                      (stats['average'] is double)
                          ? (stats['average'] as double).toStringAsFixed(2)
                          : '-',
                    ),
                    _buildStatItem(
                      'Beadta',
                      '${stats['submitted'] ?? 0} fő',
                      color: getStatusColor(true),
                    ),
                    _buildStatItem(
                      'Hiányzik',
                      '${(stats['total'] ?? 0) - (stats['submitted'] ?? 0)} fő',
                      color: getStatusColor(false),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Jegyek Eloszlása',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey100,
                    ),
                    children: [
                      _buildTableCell('Jegy', isHead: true),
                      _buildTableCell('1', isHead: true),
                      _buildTableCell('2', isHead: true),
                      _buildTableCell('3', isHead: true),
                      _buildTableCell('4', isHead: true),
                      _buildTableCell('5', isHead: true),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildTableCell('Darab', isHead: true),
                      _buildTableCell(
                        '${(stats['distribution'] as Map)[1] ?? 0}',
                      ),
                      _buildTableCell(
                        '${(stats['distribution'] as Map)[2] ?? 0}',
                      ),
                      _buildTableCell(
                        '${(stats['distribution'] as Map)[3] ?? 0}',
                      ),
                      _buildTableCell(
                        '${(stats['distribution'] as Map)[4] ?? 0}',
                      ),
                      _buildTableCell(
                        '${(stats['distribution'] as Map)[5] ?? 0}',
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
            ],

            if (includeStudentList) ...[
              pw.Text(
                'Tanulók Listája',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: showBorders
                    ? pw.TableBorder.all(color: PdfColors.grey300, width: 0.5)
                    : null,
                columnWidths: {
                  if (rowNumbering) 0: const pw.FixedColumnWidth(30),
                  if (rowNumbering)
                    1: const pw.FlexColumnWidth(3)
                  else
                    0: const pw.FlexColumnWidth(3),
                  if (rowNumbering)
                    2: const pw.FlexColumnWidth(1)
                  else
                    1: const pw.FlexColumnWidth(1),
                  if (rowNumbering)
                    3: const pw.FlexColumnWidth(1)
                  else
                    2: const pw.FlexColumnWidth(1),
                  if (rowNumbering)
                    4: const pw.FlexColumnWidth(1)
                  else
                    3: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      if (rowNumbering) _buildTableCell('#', isHead: true),
                      _buildTableCell('Név', isHead: true),
                      _buildTableCell('Jegy', isHead: true),
                      _buildTableCell('Pont', isHead: true),
                      _buildTableCell('Százalék', isHead: true),
                    ],
                  ),
                  ...students.asMap().entries.map((entry) {
                    final index = entry.key;
                    final s = entry.value;
                    final grade = s['grade']?.toString() ?? '-';
                    final score = s['score']?.toString() ?? '0';
                    final max = s['maxScore']?.toString() ?? '100';
                    final pct = _calculatePercent(s['score'], s['maxScore']);
                    final pctVal = int.tryParse(pct) ?? 0;

                    final isPass = pctVal >= 40; // Example pass threshold
                    final rowColor = stripedRows && index % 2 == 1
                        ? (grayscale ? PdfColors.grey100 : PdfColors.grey100)
                        : PdfColors.white;

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: rowColor),
                      children: [
                        if (rowNumbering) _buildTableCell('${index + 1}.'),
                        _buildTableCell(getStudentName(s, index)),
                        pw.Container(
                          alignment: pw.Alignment.center,
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            grade,
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: getGradeColor(s['grade']),
                            ),
                          ),
                        ),
                        _buildTableCell(showPoints ? '$score / $max' : '- / -'),
                        pw.Container(
                          alignment: pw.Alignment.centerLeft,
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            '$pct%',
                            style: passFail
                                ? pw.TextStyle(
                                    color: grayscale
                                        ? PdfColors.black
                                        : (isPass
                                              ? PdfColors.green700
                                              : PdfColors.red700),
                                    fontWeight: pw.FontWeight.bold,
                                  )
                                : null,
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              if (showSignature) ...[
                pw.SizedBox(height: 50),
                pw.Row(
                  children: [
                    pw.Spacer(),
                    pw.Column(
                      children: [
                        pw.Container(
                          width: 200,
                          height: 1,
                          color: PdfColors.black,
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          'Tanár Aláírása',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      );
    }

    // 2. Detailed Responses
    if (includeStudentDetails &&
        quizData != null &&
        quizData['blocks'] != null) {
      int idx = 0;
      for (var s in students) {
        if (s['status'] == 'submitted' ||
            s['status'] == 'closed' ||
            s['mock_answers'] != null) {
          final answers =
              s['mock_answers'] as List<Map<String, dynamic>>? ?? [];

          // Filter Incorrect
          final displayAnswers = onlyIncorrect
              ? answers.where((a) => a['is_correct'] != true).toList()
              : answers;

          pdf.addPage(
            pw.MultiPage(
              pageTheme: pageTheme,
              header: (context) =>
                  buildHeader('Részletes Válaszok: ${getStudentName(s, idx)}'),
              footer: buildFooter,
              build: (context) => [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Tanuló: ${getStudentName(s, idx)}',
                      style: const pw.TextStyle(fontSize: 16),
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Jegy: ${s['grade'] ?? '-'}',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        pw.Text(
                          '${s['score']} / ${s['maxScore']} pont (${_calculatePercent(s['score'], s['maxScore'])}%)',
                          style: const pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Válaszok (${onlyIncorrect ? "Csak hibás" : "Összes"}):',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                if (displayAnswers.isEmpty)
                  pw.Text(
                    onlyIncorrect
                        ? 'Nincs hibás válasz! Szép munka!'
                        : 'Nincsenek elérhető válaszok.',
                    /*style: const pw.TextStyle(
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.grey,
                    ),*/
                  )
                else
                  ...displayAnswers.map((ans) {
                    final correct = ans['is_correct'] == true;
                    final showCorrectness = !hideCorrect;

                    final borderColor = showCorrectness
                        ? (grayscale
                              ? PdfColors.grey600
                              : (correct
                                    ? PdfColors.green200
                                    : PdfColors.red200))
                        : PdfColors.grey400;
                    final bgColor = showCorrectness
                        ? (grayscale
                              ? PdfColors.grey100
                              : (correct ? PdfColors.green50 : PdfColors.red50))
                        : PdfColors.white;

                    return pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 12),
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderColor),
                        color: bgColor,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            '${ans['question_text'] ?? 'Kérdés'}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            children: [
                              pw.Text(
                                'Válasz: ',
                                style: const pw.TextStyle(
                                  fontSize: 10,
                                  color: PdfColors.grey700,
                                ),
                              ),
                              pw.Text(
                                '${ans['answer_text']}',
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                          if (showCorrectness && !correct)
                            pw.Text(
                              'Hibás válasz',
                              style: pw.TextStyle(
                                color: grayscale
                                    ? PdfColors.black
                                    : PdfColors.red,
                                fontSize: 10,
                                fontStyle: pw.FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          );
        }
        idx++;
      }
    }

    // 3. Statuses Section (formerly Warnings)
    if (includeWarnings) {
      // Include all students, not just warnings
      final statusList = students;

      if (warningLayout == 'grouped') {
        final Map<String, List<dynamic>> groupedInfo = {};
        for (var s in statusList) {
          final status = s['status'] as String? ?? 'idle';
          if (groupedInfo[status] == null) groupedInfo[status] = [];
          groupedInfo[status]!.add(s);
        }
        groupedInfo.forEach((status, list) {
          pdf.addPage(
            pw.MultiPage(
              pageTheme: pageTheme,
              header: (c) =>
                  buildHeader('Státuszok: ${_translateStatus(status)}'),
              footer: buildFooter,
              build: (c) => [
                pw.Text(
                  'Státusz: ${_translateStatus(status)}',
                  style: const pw.TextStyle(fontSize: 16),
                ),
                pw.SizedBox(height: 10),
                ...list
                    .map((s) => pw.Bullet(text: getStudentName(s, -1)))
                    .toList(),
              ],
            ),
          );
        });
      } else {
        pdf.addPage(
          pw.MultiPage(
            pageTheme: pageTheme,
            header: (c) => buildHeader('Tanulói Státuszok'),
            footer: buildFooter,
            build: (c) => [
              pw.Text(
                'ABC sorrendben',
                style: const pw.TextStyle(fontSize: 16),
              ),
              pw.SizedBox(height: 10),
              ...statusList
                  .map(
                    (s) => pw.Row(
                      children: [
                        pw.Expanded(child: pw.Text(getStudentName(s, -1))),
                        pw.Text(
                          _translateStatus(s['status']),
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color:
                                (s['status'] == 'submitted' ||
                                    s['status'] == 'closed')
                                ? (grayscale
                                      ? PdfColors.black
                                      : PdfColors.green)
                                : (grayscale ? PdfColors.black : PdfColors.red),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ],
          ),
        );
      }
    }

    // 4. Questions List
    if (includeQuestions && quizData != null && quizData['blocks'] != null) {
      final blocks = List<Map<String, dynamic>>.from(quizData['blocks']);
      pdf.addPage(
        pw.MultiPage(
          pageTheme: pageTheme,
          header: (c) => buildHeader('Kérdések Listája'),
          footer: buildFooter,
          build: (c) => [
            ...blocks.asMap().entries.map((e) {
              final q = e.value;
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${e.key + 1}. ${q['question']}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    if (q['answers'] != null)
                      ...(q['answers'] as List).map((a) {
                        final isCorrect = a['is_correct'] == true;
                        final showMarker = !hideCorrect;
                        return pw.Bullet(
                          text:
                              '${a['text']} ${showMarker && isCorrect ? '(Helyes)' : ''}',
                          bulletColor: showMarker && isCorrect
                              ? (grayscale ? PdfColors.black : PdfColors.green)
                              : PdfColors.black,
                          style: pw.TextStyle(
                            fontWeight: showMarker && isCorrect
                                ? pw.FontWeight.bold
                                : pw.FontWeight.normal,
                            color: showMarker && isCorrect && !grayscale
                                ? PdfColors.green700
                                : PdfColors.black,
                          ),
                        );
                      }),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    }

    // 5. Answer Key (New)
    if (showAnswerKey && quizData != null && quizData['blocks'] != null) {
      final blocks = List<Map<String, dynamic>>.from(quizData['blocks']);
      pdf.addPage(
        pw.MultiPage(
          pageTheme: pageTheme,
          header: (c) => buildHeader('Megoldókulcs'),
          footer: buildFooter,
          build: (c) => [
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableCell('Kérdés #', isHead: true),
                    _buildTableCell('Helyes válasz(ok)', isHead: true),
                  ],
                ),
                ...blocks.asMap().entries.map((e) {
                  final q = e.value;
                  final correctAnswers =
                      (q['answers'] as List?)
                          ?.where((a) => a['is_correct'] == true)
                          .map((a) => a['text'])
                          .join(', ') ??
                      '-';

                  return pw.TableRow(
                    children: [
                      _buildTableCell('${e.key + 1}.'),
                      _buildTableCell(correctAnswers),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      );
    }

    return pdf.save();
  }

  static pw.Widget _buildStatItem(
    String label,
    String value, {
    PdfColor color = PdfColors.black,
  }) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
      ],
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isHead = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHead ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 10,
        ),
      ),
    );
  }

  static String _calculatePercent(dynamic score, dynamic max) {
    final s = score is int ? score : 0;
    final m = max is int ? max : 100;
    if (m == 0) return '0';
    return ((s / m) * 100).round().toString();
  }

  static String _translateStatus(String? status) {
    switch (status) {
      case 'submitted':
        return 'Rendben';
      case 'closed':
        return 'Rendben';
      case 'idle':
        return 'Inaktív';
      case 'blocked':
        return 'Letiltva';
      case 'cheat_suspected':
        return 'Csalás gyanú';
      default:
        return status ?? '-';
    }
  }
}
