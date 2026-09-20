import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:test_money/models/transaction.dart';
import 'package:test_money/services/bank_statement_parser.dart';

void main() {
  test('debug PNB PDF extraction', () {
    final doc = PdfDocument();
    final page = doc.pages.add();
    final font = PdfStandardFont(PdfFontFamily.helvetica, 9);

    // Draw header
    page.graphics.drawString('PUNJAB NATIONAL BANK', font, bounds: const Rect.fromLTWH(40, 20, 300, 15));
    page.graphics.drawString('Account No: 0123000100987654', font, bounds: const Rect.fromLTWH(40, 35, 300, 15));

    // Draw Table Header
    page.graphics.drawString('Date', font, bounds: const Rect.fromLTWH(40, 60, 60, 15));
    page.graphics.drawString('Instrument ID', font, bounds: const Rect.fromLTWH(105, 60, 60, 15));
    page.graphics.drawString('Amount(INR)', font, bounds: const Rect.fromLTWH(170, 60, 60, 15));
    page.graphics.drawString('Type', font, bounds: const Rect.fromLTWH(235, 60, 30, 15));
    page.graphics.drawString('Balance', font, bounds: const Rect.fromLTWH(270, 60, 60, 15));
    page.graphics.drawString('Remarks', font, bounds: const Rect.fromLTWH(335, 60, 200, 15));

    // Draw Rows
    final rows = [
      ['16/09/2026', '', '70.0', 'DR', '7805.05', 'UPI/DR/662588224268/Lalit Ku/PPIW/7070963001@fam/P'],
      ['16/09/2026', '', '60.0', 'DR', '7875.05', 'UPI/DR/662586061704/PARVEEN/PUNB/7042106 194@ibl/Pa'],
      ['15/09/2026', '', '20.0', 'DR', '7935.05', 'UPI/DR/662483905643/Vinod Ku/YESB/paytmqr6exel5@p/'],
    ];

    double y = 80;
    for (final r in rows) {
      page.graphics.drawString(r[0], font, bounds: Rect.fromLTWH(40, y, 60, 15));
      if (r[1].isNotEmpty) page.graphics.drawString(r[1], font, bounds: Rect.fromLTWH(105, y, 60, 15));
      page.graphics.drawString(r[2], font, bounds: Rect.fromLTWH(170, y, 60, 15));
      page.graphics.drawString(r[3], font, bounds: Rect.fromLTWH(235, y, 30, 15));
      page.graphics.drawString(r[4], font, bounds: Rect.fromLTWH(270, y, 60, 15));
      page.graphics.drawString(r[5], font, bounds: Rect.fromLTWH(335, y, 200, 15));
      y += 20;
    }

    final bytes = Uint8List.fromList(doc.saveSync());
    doc.dispose();

    // Now inspect raw text and visual text
    final doc2 = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(doc2);
    final rawText = extractor.extractText();
    final textLines = extractor.extractTextLines();
    final rawResult = BankStatementParser.parseStatementText(rawText);
    expect(rawResult.transactions.length, 3);
    expect(rawResult.transactions[0].description, contains('Lalit'));
    expect(rawResult.transactions[0].description, isNot(contains('7805.05')));

    // Test Case 1: Line has Date, Amount, Type, Balance, but Remarks is on next line
    final case1Text = '''
PUNJAB NATIONAL BANK
Account No: 0123000100987654
Date Instrument ID Amount(INR) Type Balance Remarks
16/09/2026 70.0 DR 7805.05
UPI/DR/662588224268/Lalit
Ku/PPIW/7070963001@fam/P
16/09/2026 60.0 DR 7875.05
UPI/DR/662586061704/PARVEEN/PUNB/7042106
194@ibl/Pa
''';
    final res1 = BankStatementParser.parseStatementText(case1Text);

    // Test Case 5: Single line separated tokens (no empty lines)
    final case5Text = '''
PUNJAB NATIONAL BANK
Account No: 0123000100987654
Date Instrument ID Amount(INR) Type Balance Remarks
16/09/2026
70.0
DR
7805.05
UPI/DR/662588224268/Lalit Ku/PPIW/7070963001@fam/P
16/09/2026
60.0
DR
7875.05
UPI/DR/662586061704/PARVEEN/PUNB/7042106 194@ibl/Pa
''';
    final res5 = BankStatementParser.parseStatementText(case5Text);

    // Test Case 4: PDF drawn COLUMN BY COLUMN (like real Finacle / JasperReports)
    final docCol = PdfDocument();
    final pageCol = docCol.pages.add();
    final fontCol = PdfStandardFont(PdfFontFamily.helvetica, 9);
    pageCol.graphics.drawString('PUNJAB NATIONAL BANK', fontCol, bounds: const Rect.fromLTWH(40, 20, 300, 15));
    pageCol.graphics.drawString('Account No: 0123000100987654', fontCol, bounds: const Rect.fromLTWH(40, 35, 300, 15));

    // Headers
    pageCol.graphics.drawString('Date', fontCol, bounds: const Rect.fromLTWH(40, 60, 60, 15));
    pageCol.graphics.drawString('Instrument ID', fontCol, bounds: const Rect.fromLTWH(105, 60, 60, 15));
    pageCol.graphics.drawString('Amount(INR)', fontCol, bounds: const Rect.fromLTWH(170, 60, 60, 15));
    pageCol.graphics.drawString('Type', fontCol, bounds: const Rect.fromLTWH(235, 60, 30, 15));
    pageCol.graphics.drawString('Balance', fontCol, bounds: const Rect.fromLTWH(270, 60, 60, 15));
    pageCol.graphics.drawString('Remarks', fontCol, bounds: const Rect.fromLTWH(335, 60, 200, 15));

    // Column 1: Dates
    pageCol.graphics.drawString('16/09/2026', fontCol, bounds: const Rect.fromLTWH(40, 85, 60, 15));
    pageCol.graphics.drawString('16/09/2026', fontCol, bounds: const Rect.fromLTWH(40, 115, 60, 15));
    pageCol.graphics.drawString('15/09/2026', fontCol, bounds: const Rect.fromLTWH(40, 145, 60, 15));

    // Column 3: Amounts
    pageCol.graphics.drawString('70.0', fontCol, bounds: const Rect.fromLTWH(170, 85, 60, 15));
    pageCol.graphics.drawString('60.0', fontCol, bounds: const Rect.fromLTWH(170, 115, 60, 15));
    pageCol.graphics.drawString('20.0', fontCol, bounds: const Rect.fromLTWH(170, 145, 60, 15));

    // Column 4: Types
    pageCol.graphics.drawString('DR', fontCol, bounds: const Rect.fromLTWH(235, 85, 30, 15));
    pageCol.graphics.drawString('DR', fontCol, bounds: const Rect.fromLTWH(235, 115, 30, 15));
    pageCol.graphics.drawString('DR', fontCol, bounds: const Rect.fromLTWH(235, 145, 30, 15));

    // Column 5: Balances
    pageCol.graphics.drawString('7805.05', fontCol, bounds: const Rect.fromLTWH(270, 85, 60, 15));
    pageCol.graphics.drawString('7875.05', fontCol, bounds: const Rect.fromLTWH(270, 115, 60, 15));
    pageCol.graphics.drawString('7935.05', fontCol, bounds: const Rect.fromLTWH(270, 145, 60, 15));

    // Column 6: Remarks (multi-line in each cell)
    pageCol.graphics.drawString('UPI/DR/662588224268/Lalit', fontCol, bounds: const Rect.fromLTWH(335, 80, 200, 12));
    pageCol.graphics.drawString('Ku/PPIW/7070963001@fam/P', fontCol, bounds: const Rect.fromLTWH(335, 92, 200, 12));

    pageCol.graphics.drawString('UPI/DR/662586061704/PARVEEN/PUNB/7042106', fontCol, bounds: const Rect.fromLTWH(335, 110, 200, 12));
    pageCol.graphics.drawString('194@ibl/Pa', fontCol, bounds: const Rect.fromLTWH(335, 122, 200, 12));

    pageCol.graphics.drawString('UPI/DR/662483905643/Vinod', fontCol, bounds: const Rect.fromLTWH(335, 140, 200, 12));
    pageCol.graphics.drawString('Ku/YESB/paytmqr6exel5@p/', fontCol, bounds: const Rect.fromLTWH(335, 152, 200, 12));

    final colBytes = Uint8List.fromList(docCol.saveSync());
    docCol.dispose();

    final colRes = BankStatementParser.parsePdfBytes(colBytes);


    final result = BankStatementParser.parsePdfBytes(bytes);
    expect(result.bankName, 'Punjab National Bank');
    expect(result.transactions.length, 3);
    expect(result.transactions[0].amount, 70.0);
    expect(result.transactions[0].balance, 7805.05);
    expect(result.transactions[0].description, contains('Lalit'));
    expect(result.transactions[0].description, isNot(contains('7805.05')));

    expect(result.transactions[1].amount, 60.0);
    expect(result.transactions[1].balance, 7875.05);
    expect(result.transactions[1].description, contains('PARVEEN'));
    expect(result.transactions[1].description, isNot(contains('7875.05')));

    // Also assert Case 1 and Case 5
    expect(res1.transactions[0].description, contains('Lalit'));
    expect(res1.transactions[0].description, isNot(contains('7805.05')));

    expect(res5.transactions[0].description, contains('Lalit'));
    expect(res5.transactions[0].description, isNot(contains('7805.05')));

    expect(colRes.transactions[0].description, contains('Lalit'));
    expect(colRes.transactions[0].description, isNot(contains('7805.05')));
  });
}
