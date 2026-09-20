import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';

import '../models/transaction.dart';

class PdfPasswordProtectedException implements Exception {
  final String message;
  PdfPasswordProtectedException([this.message = 'This bank statement is password protected.']);
  @override
  String toString() => message;
}

class PdfInvalidPasswordException implements Exception {
  final String message;
  PdfInvalidPasswordException([this.message = 'The password entered is incorrect.']);
  @override
  String toString() => message;
}

class PdfParsingException implements Exception {
  final String message;
  PdfParsingException(this.message);
  @override
  String toString() => message;
}

class ParsedBankTransaction {
  final String id;
  DateTime date;
  String description;
  final String rawDescription;
  double amount;
  TransactionType type;
  String category;
  String? referenceNo;
  double? balance;
  bool isSelected;

  ParsedBankTransaction({
    required this.id,
    required this.date,
    required this.description,
    required this.rawDescription,
    required this.amount,
    required this.type,
    required this.category,
    this.referenceNo,
    this.balance,
    this.isSelected = true,
  });

  Transaction toTransaction({required String accountId}) {
    return Transaction(
      id: id,
      amount: amount,
      type: type,
      category: category,
      date: date,
      note: description,
      accountId: accountId,
    );
  }
}

class BankStatementResult {
  final String bankName;
  final String? accountNumber;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? openingBalance;
  final double? closingBalance;
  final List<ParsedBankTransaction> transactions;
  final String rawText;

  BankStatementResult({
    required this.bankName,
    this.accountNumber,
    this.startDate,
    this.endDate,
    this.openingBalance,
    this.closingBalance,
    required this.transactions,
    required this.rawText,
  });
}

class _RawTxnCandidate {
  final DateTime date;
  String rawDesc;
  final String fullLine;
  final List<RegExpMatch> amountMatches;
  final String afterDate;
  final String? typeMarker;

  _RawTxnCandidate({
    required this.date,
    required this.rawDesc,
    required this.fullLine,
    required this.amountMatches,
    required this.afterDate,
    this.typeMarker,
  });
}

class BankStatementParser {
  static const _uuid = Uuid();

  static final _datePattern = RegExp(
    r'(?<!\d)(\d{1,2}\s*[/-]\s*\d{1,2}\s*[/-]\s*\d{2,4}|\d{1,2}\s*[\s/-]\s*[A-Za-z]{3}\s*[\s/-]\s*\d{2,4}|\d{1,2}\.\d{1,2}\.\d{2,4}|\d{4}-\d{2}-\d{2})(?!\d)',
  );

  static final _amountPattern = RegExp(
    r'(?<!\d)(?:-)?(?:\d{1,3}(?:,\d{2,3})*|\d+)\.\d{1,2}(?:\s*\(?(?:DR|CR|Dr|Cr|debit|credit)\)?)?(?!\d)',
  );

  /// Reads PDF bytes, decrypts if password is provided, and parses bank transactions.
  static BankStatementResult parsePdfBytes(Uint8List bytes, {String? password}) {
    PdfDocument document;
    try {
      document = PdfDocument(inputBytes: bytes, password: password);
    } catch (e) {
      final err = e.toString().toLowerCase();
      if (err.contains('password') ||
          err.contains('encrypt') ||
          err.contains('security') ||
          err.contains('protected')) {
        if (password != null && password.isNotEmpty) {
          throw PdfInvalidPasswordException();
        } else {
          throw PdfPasswordProtectedException();
        }
      }
      throw PdfParsingException('Failed to open PDF document: $e');
    }

    try {
      final PdfTextExtractor extractor = PdfTextExtractor(document);
      final StringBuffer visualBuffer = StringBuffer();
      final StringBuffer rawBuffer = StringBuffer();
      final pageCount = document.pages.count;

      for (int i = 0; i < pageCount; i++) {
        // 1. Extract raw streaming text (cleanest natural reading order)
        try {
          final raw = extractor.extractText(startPageIndex: i, endPageIndex: i);
          rawBuffer.writeln(raw);
        } catch (_) {}

        // 2. Extract layout-aware visual lines (crucial for column-drawn PDF tables)
        try {
          final lines = extractor.extractTextLines(startPageIndex: i, endPageIndex: i);
          if (lines.isNotEmpty) {
            visualBuffer.writeln(_reconstructVisualRows(lines));
          }
        } catch (_) {}
      }

      final rawText = rawBuffer.toString();
      final visualText = visualBuffer.toString();

      if (rawText.trim().isEmpty && visualText.trim().isEmpty) {
        throw PdfParsingException('No readable text could be extracted from this PDF. It might be a scanned image.');
      }

      BankStatementResult? rawResult;
      BankStatementResult? visualResult;

      // 1. Attempt parsing raw text stream
      if (rawText.trim().isNotEmpty) {
        try {
          final res = parseStatementText(rawText);
          if (res.transactions.isNotEmpty) {
            rawResult = res;
          }
        } catch (_) {}
      }

      // 2. Attempt parsing visual layout-reconstructed text
      if (visualText.trim().isNotEmpty) {
        try {
          final res = parseStatementText(visualText);
          if (res.transactions.isNotEmpty) {
            visualResult = res;
          }
        } catch (_) {}
      }

      // 3. Pick the superior result based on transaction count and description quality
      if (rawResult != null && visualResult != null) {
        // Count meaningful descriptions (not fallback names like Bank Expense/Deposit, and not numbers)
        int scoreResult(BankStatementResult r) {
          return r.transactions.where((t) {
            final d = t.description.trim();
            return d.isNotEmpty &&
                d != 'Bank Expense' &&
                d != 'Deposit' &&
                !RegExp(r'^\d+(\.\d+)?$').hasMatch(d) &&
                d.length > 3;
          }).length;
        }

        final rawScore = scoreResult(rawResult);
        final visualScore = scoreResult(visualResult);

        if (visualScore > rawScore) {
          return visualResult;
        } else if (rawScore > visualScore) {
          return rawResult;
        } else if (visualResult.transactions.length >= rawResult.transactions.length) {
          return visualResult;
        } else {
          return rawResult;
        }
      }

      if (rawResult != null) return rawResult;
      if (visualResult != null) return visualResult;

      return parseStatementText(rawText.isNotEmpty ? rawText : visualText);
    } finally {
      document.dispose();
    }
  }

  /// Clusters TextLines with similar vertical positions into horizontal rows,
  /// sorted from left to right. This reconstructs rows in table-based banking PDFs.
  static String _reconstructVisualRows(List<TextLine> textLines) {
    if (textLines.isEmpty) return '';

    // Sort by vertical position (top) then horizontal position (left)
    final List<TextLine> sortedLines = List.from(textLines)
      ..sort((a, b) {
        final topDiff = a.bounds.top.compareTo(b.bounds.top);
        if (topDiff != 0) return topDiff;
        return a.bounds.left.compareTo(b.bounds.left);
      });

    final List<List<TextLine>> visualRows = [];
    final List<double> rowAnchorMids = [];

    for (final line in sortedLines) {
      final text = line.text.trim();
      if (text.isEmpty) continue;

      final lineMid = (line.bounds.top + line.bounds.bottom) / 2;
      bool added = false;

      // Search recent visual rows from bottom up
      final searchCount = visualRows.length > 6 ? 6 : visualRows.length;
      for (int r = visualRows.length - 1; r >= visualRows.length - searchCount; r--) {
        final anchorMid = rowAnchorMids[r];

        // Baseline tolerance (5.5 points) against anchor, with horizontal collision check
        // ensures different columns of the same row merge, but lines in the same column stay separate.
        if ((lineMid - anchorMid).abs() <= 5.5) {
          final overlapsHorizontally = visualRows[r].any((existing) {
            return !(line.bounds.right <= existing.bounds.left + 2 ||
                     line.bounds.left >= existing.bounds.right - 2);
          });
          if (!overlapsHorizontally) {
            visualRows[r].add(line);
            added = true;
            break;
          }
        }
      }

      if (!added) {
        visualRows.add([line]);
        rowAnchorMids.add(lineMid);
      }
    }

    final StringBuffer buffer = StringBuffer();
    for (final row in visualRows) {
      row.sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
      final rowText = row.map((l) => l.text.trim()).join(' ');
      if (rowText.isNotEmpty) {
        buffer.writeln(rowText);
      }
    }
    return buffer.toString();
  }

  /// Parses raw or reconstructed text extracted from a bank statement.
  static BankStatementResult parseStatementText(String text) {
    final bankName = detectBank(text);
    final accountNumber = detectAccountNumber(text);
    final transactions = _parseTransactions(text, bankName);

    if (transactions.isEmpty) {
      throw PdfParsingException(
        'No transactions could be detected. Please ensure the document is a supported bank statement.',
      );
    }

    DateTime? startDate;
    DateTime? endDate;
    double? openingBalance = detectOpeningBalance(text);
    double? closingBalance;

    if (transactions.isNotEmpty) {
      final sortedByDate = List<ParsedBankTransaction>.from(transactions)
        ..sort((a, b) => a.date.compareTo(b.date));
      startDate = sortedByDate.first.date;
      endDate = sortedByDate.last.date;

      // If opening balance was not explicitly stated in header, compute from earliest transaction
      if (openingBalance == null) {
        final firstTxn = sortedByDate.first;
        if (firstTxn.balance != null && firstTxn.balance! > 0) {
          if (firstTxn.type == TransactionType.expense) {
            openingBalance = firstTxn.balance! + firstTxn.amount;
          } else {
            openingBalance = (firstTxn.balance! - firstTxn.amount).clamp(0.0, double.infinity);
          }
        }
      }

      final lastTxn = sortedByDate.last;
      closingBalance = lastTxn.balance;
    }

    return BankStatementResult(
      bankName: bankName,
      accountNumber: accountNumber,
      startDate: startDate,
      endDate: endDate,
      openingBalance: openingBalance,
      closingBalance: closingBalance,
      transactions: transactions,
      rawText: text,
    );
  }

  /// Attempts to extract explicit opening balance from statement headers.
  static double? detectOpeningBalance(String text) {
    final match = RegExp(
      r'(?:Opening\s*(?:Balance|Bal)|B\/F\s*(?:Balance)?|Brought\s*Forward)(?:\s+as\s+on\s+[^:\n]+)?[:\s\-]*([0-9,]+\.[0-9]{1,2})',
      caseSensitive: false,
    ).firstMatch(text);
    if (match != null) {
      return _parseAmount(match.group(1)!);
    }
    return null;
  }

  /// Detects the bank name from statement header keywords, IFSC prefixes, and URLs.
  static String detectBank(String text) {
    // Search the header section (first 5000 characters) for bank logos, IFSC, URLs, and branch details
    final headerUpper = (text.length > 5000 ? text.substring(0, 5000) : text).toUpperCase();
    final fullUpper = text.toUpperCase();

    // 1. Full bank names anywhere in header or document (strict full names)
    if (fullUpper.contains('PUNJAB NATIONAL')) return 'Punjab National Bank';
    if (fullUpper.contains('STATE BANK OF INDIA')) return 'State Bank of India';
    if (fullUpper.contains('HDFC BANK')) return 'HDFC Bank';
    if (fullUpper.contains('ICICI BANK')) return 'ICICI Bank';
    if (fullUpper.contains('AXIS BANK')) return 'Axis Bank';
    if (fullUpper.contains('KOTAK MAHINDRA') || fullUpper.contains('KOTAK BANK')) return 'Kotak Mahindra Bank';
    if (fullUpper.contains('BANK OF BARODA')) return 'Bank of Baroda';
    if (fullUpper.contains('CANARA BANK')) return 'Canara Bank';
    if (fullUpper.contains('UNION BANK OF INDIA')) return 'Union Bank of India';
    if (fullUpper.contains('INDIAN BANK')) return 'Indian Bank';
    if (fullUpper.contains('YES BANK')) return 'Yes Bank';
    if (fullUpper.contains('INDUSIND BANK')) return 'IndusInd Bank';
    if (fullUpper.contains('IDFC FIRST BANK') || fullUpper.contains('IDFC FIRST')) return 'IDFC First Bank';

    // 2. Header-specific matching (domains, official acronyms, branch IFSC prefixes)
    // Note: NEVER match 3-4 letter acronyms or IFSC prefixes across the entire document
    // because UPI transaction narrations contain other banks' IFSC prefixes (e.g. UTIB, YESB, PUNB, SBIN)
    // and handles (e.g. @sbi, @okaxis, @okhdfcbank).
    if (headerUpper.contains('PUNB') ||
        headerUpper.contains('PNB') ||
        headerUpper.contains('PNBINDIA') ||
        headerUpper.contains('NETPNB') ||
        headerUpper.contains('MPASSBOOK') ||
        headerUpper.contains('PNB ONE')) {
      return 'Punjab National Bank';
    }
    if (headerUpper.contains('ONLINESBI') ||
        headerUpper.contains('SBIN0') ||
        RegExp(r'\bSBI\b').hasMatch(headerUpper)) {
      return 'State Bank of India';
    }
    if (headerUpper.contains('HDFCBANK') || headerUpper.contains('HDFC0')) {
      return 'HDFC Bank';
    }
    if (headerUpper.contains('ICICIBANK') || headerUpper.contains('ICIC0')) {
      return 'ICICI Bank';
    }
    if (headerUpper.contains('AXISBANK') || headerUpper.contains('UTIB0')) {
      return 'Axis Bank';
    }
    if (headerUpper.contains('KOTAK.COM') || headerUpper.contains('KKBK0')) {
      return 'Kotak Mahindra Bank';
    }
    if (headerUpper.contains('BARB0')) return 'Bank of Baroda';
    if (headerUpper.contains('CNRB0')) return 'Canara Bank';
    if (headerUpper.contains('UBIN0')) return 'Union Bank of India';
    if (headerUpper.contains('IDFB0')) return 'IDFC First Bank';
    if (headerUpper.contains('YESB0')) return 'Yes Bank';
    if (headerUpper.contains('INDB0')) return 'IndusInd Bank';

    // 3. Fallback: If document body consistently features PNB IFSC code in remarks
    if (fullUpper.contains('/PUNB/') || fullUpper.contains('@PUNB')) {
      return 'Punjab National Bank';
    }

    return 'Bank Statement';
  }

  /// Checks if a line contains summary, balance-forwarding, or metadata headers that
  /// should NOT be parsed as financial transactions.
  static bool _isNonTransactionLine(String line) {
    final upper = line.toUpperCase().trim();
    if (upper.isEmpty) return true;

    final nonTxnPatterns = [
      RegExp(r'\b(OPENING|CLOSING|OP|CL)\s*(BALANCE|BAL)\b'),
      RegExp(r'\b(BROUGHT|CARRIED)\s*FORWARD\b'),
      RegExp(r'\b(B\/F|C\/F|B\s*\/\s*F|C\s*\/\s*F)\b'),
      RegExp(r'\b(TOTAL|GRAND\s*TOTAL|TOTAL\s*DEBIT|TOTAL\s*CREDIT|TOTAL\s*AMOUNT)\b'),
      RegExp(r'\b(AVAILABLE|SWEEP|MOD|UNCLEARED)\s*(BALANCE|BAL)\b'),
      RegExp(r'\b(SANCTION|DRAWING|OVERDRAFT|CREDIT)\s*(LIMIT|POWER|OD)\b'),
      RegExp(r'\b(STATEMENT\s*SUMMARY|TRANSACTION\s*SUMMARY|ACCOUNT\s*SUMMARY)\b'),
      RegExp(r'\b(PAGE\s*(?:NO|NUMBER)?[:.\s]*\d+)\b'),
      RegExp(r'\b(DISCLAIMER|COMPUTER\s*GENERATED|TOLL\s*FREE|BRANCH\s*CODE)\b'),
      RegExp(r'^(DATE\s+.*AMOUNT|DATE\s+.*PARTICULARS|DATE\s+.*NARATION|DATE\s+.*DESCRIPTION|S\.?NO\s+)'),
    ];

    for (final pattern in nonTxnPatterns) {
      if (pattern.hasMatch(upper)) {
        return true;
      }
    }
    return false;
  }

  /// Attempts to find masked or partial account numbers.
  static String? detectAccountNumber(String text) {
    final header = text.length > 5000 ? text.substring(0, 5000) : text;
    final match = RegExp(
      r'(?:(?:Savings?|Current|Primary)?\s*(?:Account|A\/c|A\/C|Acc)\s*(?:No\.?|Number|#|Id)?|Account\s*ID)[:.\s-]*([X\d]{6,20})',
      caseSensitive: false,
    ).firstMatch(header);
    if (match != null) return match.group(1);

    final fallback = RegExp(
      r'(?:Account\s*(?:No|Number|#|Id)?|A\/c\s*(?:No|Number|#)?|Acc\s*No)[:.\s]*([X\d]{6,20})',
      caseSensitive: false,
    ).firstMatch(text);
    return fallback?.group(1);
  }

  static double? _getCandidateBalance(_RawTxnCandidate cand) {
    if (cand.amountMatches.length >= 2) {
      return _parseAmount(cand.amountMatches.last.group(0)!);
    }
    return null;
  }

  static List<ParsedBankTransaction> _parseTransactions(String text, String bankName) {
    final lines = text.split(RegExp(r'\r?\n'));
    final List<_RawTxnCandidate> candidates = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Reject non-transaction rows (opening/closing balance, totals, limits, summaries)
      if (_isNonTransactionLine(line)) {
        continue;
      }

      final dateMatch = _datePattern.firstMatch(line);
      if (dateMatch == null) {
        // Multi-line continuation:
        // Check if this line contains balance or amount before appending to description!
        if (candidates.isNotEmpty &&
            line.length > 2 &&
            !line.startsWith('Page') &&
            !line.startsWith('Statement')) {
          final last = candidates.last;
          final lineAmounts = _amountPattern.allMatches(line).toList();
          final isPureAmountLine = RegExp(
            r'^(?:INR|Rs\.?)?\s*[-+]?\d{1,3}(?:,\d{2,3})*(?:\.\d{1,2})?(?:\s*(?:DR|CR|Cr|Dr|\(DR\)|\(CR\)))?$',
            caseSensitive: false,
          ).hasMatch(line.trim());

          if (isPureAmountLine && lineAmounts.isNotEmpty) {
            // This is a wrapped balance/amount line, NOT a description!
            if (last.amountMatches.length < 2) {
              last.amountMatches.addAll(lineAmounts);
            }
          } else if (!RegExp(r'^\d+$').hasMatch(line)) {
            // If the line starts with an amount followed by remarks (e.g. "7805.05 UPI/DR/..."):
            if (last.amountMatches.length < 2 &&
                lineAmounts.isNotEmpty &&
                line.startsWith(lineAmounts.first.group(0)!)) {
              last.amountMatches.add(lineAmounts.first);
              final stripped = line.substring(lineAmounts.first.end).trim();
              if (stripped.isNotEmpty && last.rawDesc.length < 200) {
                last.rawDesc = '${last.rawDesc} $stripped'.trim();
              }
            } else if (last.rawDesc.length < 200) {
              last.rawDesc = '${last.rawDesc} $line'.trim();
            }
          }
        }
        continue;
      }

      // Check if prefix before date is either empty or a serial number (e.g. "1", "01.", "S.No 1", "*")
      final prefix = line.substring(0, dateMatch.start).trim();
      final isPrefixSerial = prefix.isEmpty ||
          RegExp(r'^(?:S\.?No\.?[:\s]*|Txn\s*No\.?[:\s]*)?\d{1,5}[.\s|)]*$', caseSensitive: false).hasMatch(prefix) ||
          RegExp(r'^[#*\-•]$').hasMatch(prefix);

      if (!isPrefixSerial) {
        // The date occurred far into the line (e.g., inside header, address, or summary)
        continue;
      }

      final dateStr = dateMatch.group(1)!;
      final parsedDate = _parseDate(dateStr);
      if (parsedDate == null) continue;

      var afterDate = line.substring(dateMatch.end).trim();

      // Strip optional time right after first date if present: e.g. "14:23:45" or "02:30 PM"
      afterDate = afterDate.replaceFirst(RegExp(r'^\d{1,2}:\d{2}(?::\d{2})?(?:\s*[APap][Mm])?\s*'), '').trim();

      // Check if there is a second date immediately following (e.g. Value Date in Axis / PNB / SBI)
      final secondDateMatch = _datePattern.firstMatch(afterDate);
      if (secondDateMatch != null && secondDateMatch.start < 6) {
        afterDate = afterDate.substring(secondDateMatch.end).trim();
        afterDate = afterDate.replaceFirst(RegExp(r'^\d{1,2}:\d{2}(?::\d{2})?(?:\s*[APap][Mm])?\s*'), '').trim();
      }

      // Look for amounts on the line
      var amountMatches = _amountPattern.allMatches(afterDate).toList();

      // If no amount found, or if amounts/remarks wrapped across subsequent lines,
      // look ahead up to 5 lines to collect all components of this transaction
      for (int lookAhead = 1; lookAhead <= 5 && i + lookAhead < lines.length; lookAhead++) {
        final nextLine = lines[i + lookAhead].trim();
        if (nextLine.isEmpty) continue;
        if (_isNonTransactionLine(nextLine)) break;

        final nextDateMatch = _datePattern.firstMatch(nextLine);
        if (nextDateMatch != null) {
          final nextPrefix = nextLine.substring(0, nextDateMatch.start).trim();
          final isNextTxn = nextPrefix.isEmpty ||
              RegExp(r'^(?:S\.?No\.?[:\s]*|Txn\s*No\.?[:\s]*)?\d{1,5}[.\s|)]*$', caseSensitive: false).hasMatch(nextPrefix) ||
              RegExp(r'^[#*\-•]$').hasMatch(nextPrefix);
          if (isNextTxn) break;
        }

        final nextAmounts = _amountPattern.allMatches(nextLine).toList();
        final isPureAmount = RegExp(
          r'^(?:INR|Rs\.?)?\s*[-+]?\d{1,3}(?:,\d{2,3})*(?:\.\d{1,2})?(?:\s*(?:DR|CR|Cr|Dr|\(DR\)|\(CR\)))?$',
          caseSensitive: false,
        ).hasMatch(nextLine);

        if (amountMatches.length < 2 && nextAmounts.isNotEmpty) {
          afterDate = '$afterDate $nextLine';
          amountMatches = _amountPattern.allMatches(afterDate).toList();
          i += lookAhead;
          lookAhead = 0;
        } else if (amountMatches.isEmpty) {
          afterDate = '$afterDate $nextLine';
          amountMatches = _amountPattern.allMatches(afterDate).toList();
          i += lookAhead;
          lookAhead = 0;
        } else if (!isPureAmount &&
            (nextLine.toUpperCase().contains('UPI') ||
                nextLine.toUpperCase().contains('TRANSFER') ||
                nextLine.length > 5)) {
          afterDate = '$afterDate $nextLine';
          i += lookAhead;
          lookAhead = 0;
          break;
        }
      }

      if (amountMatches.isEmpty) continue;

      final firstAmountMatch = amountMatches.first;
      final lastAmountMatch = amountMatches.last;

      final textBeforeFirst = afterDate.substring(0, firstAmountMatch.start).trim();
      final textAfterLast = afterDate.substring(lastAmountMatch.end).trim();
      final textBetween = amountMatches.length >= 2
          ? afterDate.substring(firstAmountMatch.end, lastAmountMatch.start).trim()
          : '';

      // Determine where the description is:
      // In Finacle / PNB layout (Date | Inst ID | Amount | Type | Balance | Remarks),
      // textBeforeFirst is empty or just an instrument ID/cheque number,
      // and textAfterLast contains the full narration/payee (e.g. "UPI/DR/662.../Lalit").
      // In SBI / HDFC layout (Date | Narration | Cheque | Amount | Balance),
      // textBeforeFirst contains the narration, and textAfterLast is empty or short.
      String rawDesc;
      if (textAfterLast.isNotEmpty &&
          (textBeforeFirst.isEmpty ||
              RegExp(r'^\d{1,12}$').hasMatch(textBeforeFirst) ||
              RegExp(r'^(?:DR|CR|\(DR\)|\(CR\))$', caseSensitive: false).hasMatch(textBeforeFirst) ||
              textAfterLast.toUpperCase().contains('UPI') ||
              textAfterLast.toUpperCase().contains('TRANSFER') ||
              textAfterLast.length > textBeforeFirst.length + 5)) {
        rawDesc = textAfterLast;
      } else {
        rawDesc = textBeforeFirst;
        // Strip trailing cheque/reference noise before amounts (e.g. 6-digit cheque number "000000")
        rawDesc = rawDesc.replaceAll(RegExp(r'\s+(?:CHQ|REF)?[:\s\-#]*\d{4,12}$', caseSensitive: false), '').trim();
      }

      // Never treat a bare amount or balance number as a transaction description
      if (RegExp(r'^(?:INR|Rs\.?)?\s*[-+]?\d+(?:\.\d{1,2})?(?:\s*(?:DR|CR|Cr|Dr))?$', caseSensitive: false).hasMatch(rawDesc.trim())) {
        rawDesc = '';
      }

      // Check for explicit DR / CR markers between amounts or before amounts
      String? typeMarker;
      if (RegExp(r'\b(DR|\(DR\)|DEBIT)\b', caseSensitive: false).hasMatch(textBetween)) {
        typeMarker = 'DR';
      } else if (RegExp(r'\b(CR|\(CR\)|CREDIT)\b', caseSensitive: false).hasMatch(textBetween)) {
        typeMarker = 'CR';
      } else if (RegExp(r'\b(DR|\(DR\)|DEBIT)\b', caseSensitive: false).hasMatch(textBeforeFirst)) {
        typeMarker = 'DR';
      } else if (RegExp(r'\b(CR|\(CR\)|CREDIT)\b', caseSensitive: false).hasMatch(textBeforeFirst)) {
        typeMarker = 'CR';
      }

      candidates.add(_RawTxnCandidate(
        date: parsedDate,
        rawDesc: rawDesc,
        fullLine: line,
        amountMatches: amountMatches,
        afterDate: afterDate,
        typeMarker: typeMarker,
      ));
    }

    if (candidates.isEmpty) return [];

    // Determine statement chronological ordering (oldest-first vs newest-first)
    bool isDescending = false;
    if (candidates.length >= 2) {
      if (candidates.first.date.isAfter(candidates.last.date)) {
        isDescending = true;
      }
    }

    final List<ParsedBankTransaction> results = [];

    for (int k = 0; k < candidates.length; k++) {
      final cand = candidates[k];
      final parsedAmounts = cand.amountMatches.map((m) => _parseAmount(m.group(0)!)).toList();
      final firstRawMatch = cand.amountMatches.first.group(0)!;
      final txnHasExplicitDr = RegExp(r'\(?DR\)?', caseSensitive: false).hasMatch(firstRawMatch);
      final txnHasExplicitCr = RegExp(r'\(?CR\)?', caseSensitive: false).hasMatch(firstRawMatch);

      final hasDrMarker = txnHasExplicitDr ||
          cand.typeMarker == 'DR' ||
          RegExp(r'\b(DR|\(DR\)|DEBIT|WDL|ATM-WDL|WITHDRAWAL)\b', caseSensitive: false).hasMatch(cand.rawDesc);
      final hasCrMarker = txnHasExplicitCr ||
          cand.typeMarker == 'CR' ||
          RegExp(r'\b(CR|\(CR\)|CREDIT|DEP|DEPOSIT|REFUND|SALARY|INTEREST)\b', caseSensitive: false).hasMatch(cand.rawDesc);

      double? debitAmount;
      double? creditAmount;
      double? balance;

      if (parsedAmounts.length >= 3) {
        // [Debit, Credit, Balance]
        final val1 = parsedAmounts[0];
        final val2 = parsedAmounts[1];
        balance = parsedAmounts[2];

        if (val1 > 0 && val2 == 0) {
          debitAmount = val1;
        } else if (val2 > 0 && val1 == 0) {
          creditAmount = val2;
        } else if (hasCrMarker && !hasDrMarker) {
          creditAmount = val2 > 0 ? val2 : val1;
        } else if (hasDrMarker && !hasCrMarker) {
          debitAmount = val1 > 0 ? val1 : val2;
        } else {
          debitAmount = val1 > 0 ? val1 : val2;
        }
      } else if (parsedAmounts.length == 2) {
        // [TxnAmount, Balance]
        final val1 = parsedAmounts[0];
        balance = parsedAmounts[1];

        // 1. First priority: explicit type marker from column layout (e.g. Amount DR Balance)
        if (cand.typeMarker == 'DR') {
          debitAmount = val1;
        } else if (cand.typeMarker == 'CR') {
          creditAmount = val1;
        }

        // 2. Second priority: mathematical delta against chronologically adjacent transaction
        if (debitAmount == null && creditAmount == null) {
          double? prevBalance;
          if (!isDescending && k > 0) {
            prevBalance = _getCandidateBalance(candidates[k - 1]);
          } else if (isDescending && k + 1 < candidates.length) {
            prevBalance = _getCandidateBalance(candidates[k + 1]);
          }

          if (prevBalance != null && balance > 0 && prevBalance > 0) {
            final delta = balance - prevBalance;
            if ((delta - val1).abs() < 0.5) {
              creditAmount = val1;
            } else if ((delta + val1).abs() < 0.5) {
              debitAmount = val1;
            }
          }
        }

        // 3. Third priority: explicit Dr / Cr markers on amount or narration
        if (debitAmount == null && creditAmount == null) {
          if (txnHasExplicitDr) {
            debitAmount = val1;
          } else if (txnHasExplicitCr) {
            creditAmount = val1;
          } else if (hasCrMarker || _isLikelyCredit(cand.rawDesc)) {
            creditAmount = val1;
          } else if (hasDrMarker || _isLikelyDebit(cand.rawDesc)) {
            debitAmount = val1;
          } else {
            debitAmount = val1;
          }
        }
      } else {
        // 1 amount
        final singleVal = parsedAmounts[0];
        if (cand.typeMarker == 'CR' || txnHasExplicitCr || hasCrMarker || _isLikelyCredit(cand.rawDesc)) {
          creditAmount = singleVal;
        } else {
          debitAmount = singleVal;
        }
      }

      TransactionType type;
      double amount;

      if (creditAmount != null && creditAmount > 0) {
        type = TransactionType.income;
        amount = creditAmount;
      } else {
        type = TransactionType.expense;
        amount = debitAmount ?? 0.0;
      }

      if (amount <= 0.0) continue;

      String cleanDesc = _cleanNarration(cand.rawDesc);
      if (cleanDesc.isEmpty) {
        cleanDesc = type == TransactionType.income ? 'Deposit' : 'Bank Expense';
      }

      final refMatch = RegExp(r'(?:UPI[/-]|REF[/-]|CHQ[:\s]*|NEFT[/-]|IMPS[/-])([A-Za-z0-9]+)', caseSensitive: false)
          .firstMatch(cand.rawDesc);
      final refNo = refMatch?.group(1);
      final category = categorize('$cleanDesc ${cand.rawDesc}', type);

      results.add(ParsedBankTransaction(
        id: _uuid.v4(),
        date: cand.date,
        description: cleanDesc,
        rawDescription: cand.fullLine,
        amount: amount,
        type: type,
        category: category,
        referenceNo: refNo,
        balance: balance,
        isSelected: true,
      ));
    }

    return results;
  }

  static DateTime? _parseDate(String dateStr) {
    var cleaned = dateStr.trim();

    // Standardize uppercase/lowercase 3-letter month abbreviations to Title Case for intl DateFormat
    const months = {
      'JAN': 'Jan', 'FEB': 'Feb', 'MAR': 'Mar', 'APR': 'Apr',
      'MAY': 'May', 'JUN': 'Jun', 'JUL': 'Jul', 'AUG': 'Aug',
      'SEP': 'Sep', 'OCT': 'Oct', 'NOV': 'Nov', 'DEC': 'Dec',
    };
    for (final entry in months.entries) {
      cleaned = cleaned.replaceAll(RegExp(entry.key, caseSensitive: false), entry.value);
    }

    // Standardize dots and slashes with dashes for consistent parsing
    cleaned = cleaned.replaceAll('.', '-');
    cleaned = cleaned.replaceAll('/', '-');

    final formats = [
      'dd-MM-yyyy',
      'dd-MM-yy',
      'd-M-yyyy',
      'd-M-yy',
      'dd-MMM-yyyy',
      'dd-MMM-yy',
      'd-MMM-yyyy',
      'd-MMM-yy',
      'dd MMM yyyy',
      'dd MMM, yyyy',
      'yyyy-MM-dd',
    ];

    for (final fmt in formats) {
      try {
        final dt = DateFormat(fmt, 'en_US').parse(cleaned);
        if (dt.year < 100) {
          return DateTime(dt.year + 2000, dt.month, dt.day);
        }
        return dt;
      } catch (_) {}
    }

    try {
      final dt = DateTime.parse(cleaned);
      if (dt.year < 100) {
        return DateTime(dt.year + 2000, dt.month, dt.day);
      }
      return dt;
    } catch (_) {}

    return null;
  }

  static double _parseAmount(String str) {
    // Strip Dr/Cr suffixes, brackets, negative signs, and commas
    var cleaned = str.replaceAll(',', '').replaceAll(RegExp(r'[^\d.]'), '').trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  static bool _isLikelyCredit(String text) {
    final upper = text.toUpperCase();
    return upper.contains('BY TRANSFER') ||
        upper.contains('CR/') ||
        upper.contains('/CR') ||
        upper.contains('CREDIT') ||
        upper.contains('SALARY') ||
        upper.contains('REFUND') ||
        upper.contains('CASHBACK') ||
        upper.contains('DIVIDEND') ||
        upper.contains('INTEREST') ||
        upper.contains('NEFT CR') ||
        upper.contains('IMPS CR') ||
        upper.contains('UPI/CR') ||
        upper.contains('DEP') ||
        upper.contains('DEPOSIT');
  }

  static bool _isLikelyDebit(String text) {
    final upper = text.toUpperCase();
    return upper.contains('TO TRANSFER') ||
        upper.contains('DR/') ||
        upper.contains('/DR') ||
        upper.contains('DEBIT') ||
        upper.contains('WDL') ||
        upper.contains('ATM-WDL') ||
        upper.contains('WITHDRAWAL') ||
        upper.contains('PURCHASE') ||
        upper.contains('POS') ||
        upper.contains('PAYMENT') ||
        upper.contains('NEFT DR') ||
        upper.contains('IMPS DR') ||
        upper.contains('UPI/DR');
  }

  static String _cleanNarration(String raw) {
    var text = raw.trim();

    // Strip any leading balance or amount digits that may have preceded narration
    // e.g. "7805.05 UPI/DR/..." -> "UPI/DR/..."
    text = text.replaceFirst(RegExp(r'^(?:INR|Rs\.?)?\s*[-+]?\d+(?:\.\d{1,2})?\s+'), '');
    text = text.replaceFirst(RegExp(r'\s+(?:INR|Rs\.?)?\s*[-+]?\d+(?:\.\d{1,2})?$'), '');

    // If text is purely a number or amount, it's not a description
    if (RegExp(r'^(?:INR|Rs\.?)?\s*[-+]?\d+(\.\d+)?$', caseSensitive: false).hasMatch(text)) {
      return '';
    }

    // Remove leading/trailing value dates like "05/01/24"
    text = text.replaceAll(RegExp(r'^\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\s*'), '');
    text = text.replaceAll(RegExp(r'\s*\d{1,2}[/-]\d{1,2}[/-]\d{2,4}$'), '');

    // Strip leading cheque / reference noise
    text = text.replaceAll(RegExp(r'^\s*(?:CHQ|REF|TXN)?[:\s\-#]*\d+\s*[-:]?\s*', caseSensitive: false), '');

    // Remove bank transfer prefixes like "TO TRANSFER-INB /", "TO TRANSFER-MOB /", "BY TRANSFER-NEFT /"
    text = text.replaceAll(RegExp(r'^(?:TO|BY)\s+TRANSFER(?:-[A-Za-z0-9]+)?\s*[-/:]?\s*', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'^TRANSFER\s+(?:TO|FROM)\s+[A-Za-z0-9]+\s*[-/:]?\s*', caseSensitive: false), '');

    // Simplify UPI strings: "UPI/DR/4123456789/ZOMATO/ORDER" -> "ZOMATO"
    if (text.toUpperCase().contains('UPI')) {
      final upiParts = text.split(RegExp(r'[-/:]'));
      if (upiParts.length >= 2) {
        final meaningful = upiParts.where((p) {
          final trimmed = p.trim();
          return trimmed.length > 2 &&
              !RegExp(r'^(UPI|P2M|P2P|DR|CR|PAYMENT|TRANSFER|TO|BY|ORDER|REFUND|BIL|NA|PAID)$', caseSensitive: false).hasMatch(trimmed) &&
              !RegExp(r'^(?:TO|BY)\s+TRANSFER$', caseSensitive: false).hasMatch(trimmed) &&
              !RegExp(r'^\d+(\.\d+)?$').hasMatch(trimmed) &&
              !RegExp(r'^[A-Z]{4}\d{7}$', caseSensitive: false).hasMatch(trimmed);
        }).toList();
        if (meaningful.isNotEmpty) {
          // If first meaningful element is a bank/clearing identifier (e.g. PUNB, YESB, PPIW, UTIB, SBIN)
          // and a second meaningful element (like payee name) exists, prefer the payee name!
          if (meaningful.length >= 2 && RegExp(r'^(PUNB|YESB|UTIB|SBIN|HDFC|ICIC|PPIW|AIRP|PYTM)$', caseSensitive: false).hasMatch(meaningful.first.trim())) {
            text = meaningful[1].trim();
          } else {
            text = meaningful.first.trim();
          }
        }
      }
    }

    // Clean up excessive whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (RegExp(r'^(?:INR|Rs\.?)?\s*[-+]?\d+(\.\d+)?$', caseSensitive: false).hasMatch(text)) {
      return '';
    }
    return text;
  }

  /// Categorizes a transaction based on merchant and description keywords.
  static String categorize(String description, TransactionType type) {
    if (type == TransactionType.income) {
      final upper = description.toUpperCase();
      if (upper.contains('SALARY') || upper.contains('PAYROLL') || upper.contains('WAGES')) {
        return 'Salary';
      }
      if (upper.contains('DIVIDEND') || upper.contains('INTEREST') || upper.contains('MUTUAL') || upper.contains('ZERODHA') || upper.contains('GROWW')) {
        return 'Investment';
      }
      if (upper.contains('CASHBACK') || upper.contains('REFUND') || upper.contains('GIFT')) {
        return 'Gift';
      }
      return 'Salary';
    }

    final lower = description.toLowerCase();

    // Food & Dining
    if (_hasAny(lower, [
      'swiggy', 'zomato', 'mcdonald', 'starbucks', 'kfc', 'burger', 'cafe', 'restaurant',
      'pizza', 'domino', 'subway', 'chai', 'tea', 'coffee', 'hotel', 'blinkit', 'zepto',
      'instamart', 'bigbasket', 'bbdaily', 'dunkin', 'eats', 'biryani', 'bakery'
    ])) {
      return 'Food';
    }

    // Transportation & Fuel
    if (_hasAny(lower, [
      'uber', 'ola', 'rapido', 'irctc', 'railway', 'petrol', 'fuel', 'hpcl', 'bpcl',
      'iocl', 'shell', 'fastag', 'toll', 'metro', 'makemytrip', 'cleartrip', 'goibibo',
      'indigo', 'air india', 'vistara', 'flight', 'parking', 'auto'
    ])) {
      return 'Transport';
    }

    // Shopping & Retail
    if (_hasAny(lower, [
      'amazon', 'flipkart', 'myntra', 'ajio', 'nykaa', 'tata cliq', 'zara', 'h&m',
      'meesho', 'croma', 'reliance', 'dmart', 'supermarket', 'mall', 'clothing',
      'trends', 'lifestyle', 'westside', 'decathlon', 'ikea', 'retail', 'store'
    ])) {
      return 'Shopping';
    }

    // Entertainment & Subscriptions
    if (_hasAny(lower, [
      'netflix', 'spotify', 'hotstar', 'prime video', 'youtube', 'apple', 'google play',
      'cinema', 'pvr', 'inox', 'bookmyshow', 'game', 'playstation', 'steam', 'disney'
    ])) {
      return 'Entertainment';
    }

    // Health & Medical
    if (_hasAny(lower, [
      'apollo', 'pharmacy', 'medplus', '1mg', 'pharmeasy', 'hospital', 'clinic',
      'doctor', 'dental', 'pathology', 'lab', 'health', 'cult.fit', 'gym', 'fitness'
    ])) {
      return 'Health';
    }

    // Groceries & Daily Needs
    if (_hasAny(lower, [
      'grocery', 'vegetable', 'fruits', 'dairy', 'milk', 'bread', 'kirana', 'provisions'
    ])) {
      return 'Groceries';
    }

    // Housing & Rent
    if (_hasAny(lower, [
      'rent', 'maintenance', 'electricity', 'water bill', 'bescom', 'tneb', 'mseb',
      'gas bill', 'indane', 'hp gas', 'bharat gas', 'wifi', 'broadband', 'airtel', 'jio'
    ])) {
      return 'Rent';
    }

    // Investments & Savings
    if (_hasAny(lower, [
      'zerodha', 'groww', 'kuvera', 'et money', 'mutual fund', 'sip', 'insurance',
      'lic', 'hdfc life', 'icici pru', 'sbi life', 'nps', 'ppf'
    ])) {
      return 'Investment';
    }

    return 'Other';
  }

  static bool _hasAny(String text, List<String> keywords) {
    for (final kw in keywords) {
      if (text.contains(kw)) return true;
    }
    return false;
  }
}
