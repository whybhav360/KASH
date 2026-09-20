import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/account.dart';
import '../models/transaction.dart';
import '../models/transaction_template.dart';

class BackupData {
  final List<Account> accounts;
  final List<Transaction> transactions;
  final List<TransactionTemplate> templates;
  final List<String> expenseCategories;
  final List<String> incomeCategories;
  final String? userName;
  final String? profilePictureBase64;
  final String format; // 'json' or 'csv'

  BackupData({
    this.accounts = const [],
    this.transactions = const [],
    this.templates = const [],
    this.expenseCategories = const [],
    this.incomeCategories = const [],
    this.userName,
    this.profilePictureBase64,
    required this.format,
  });

  int get totalItemsCount =>
      accounts.length + transactions.length + templates.length;
}

class BackupService {
  static const String currentBackupVersion = '1.0';

  /// Generates full JSON backup string (excluding goals).
  /// 100% offline, stored locally.
  /// Embeds custom account images and profile picture as Base64 for complete cross-device portability.
  static Future<String> exportToJson({
    required List<Account> accounts,
    required List<Transaction> transactions,
    required List<TransactionTemplate> templates,
    required List<String> expenseCategories,
    required List<String> incomeCategories,
    required String userName,
    String? userProfilePicture,
  }) async {
    final List<Map<String, dynamic>> accountsJson = [];
    for (final a in accounts) {
      String? base64Str = a.imageBase64;
      if (base64Str == null && a.customImagePath != null) {
        try {
          final file = File(a.customImagePath!);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            base64Str = base64Encode(bytes);
          }
        } catch (_) {}
      }
      final map = a.toJson();
      if (base64Str != null) {
        map['imageBase64'] = base64Str;
      }
      accountsJson.add(map);
    }

    String? profilePicBase64;
    if (userProfilePicture != null) {
      try {
        final file = File(userProfilePicture);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          profilePicBase64 = base64Encode(bytes);
        }
      } catch (_) {}
    }

    final Map<String, dynamic> backupMap = {
      'metadata': {
        'appName': 'KASH',
        'version': currentBackupVersion,
        'exportedAt': DateTime.now().toIso8601String(),
      },
      'profile': {
        'userName': userName,
        if (profilePicBase64 != null) 'profilePictureBase64': profilePicBase64,
      },
      'categories': {
        'expense': expenseCategories,
        'income': incomeCategories,
      },
      'accounts': accountsJson,
      'templates': templates.map((t) => t.toJson()).toList(),
      'transactions': transactions.map((t) => t.toJson()).toList(),
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(backupMap);
  }

  /// Parses JSON backup string into [BackupData].
  static BackupData parseJsonBackup(String jsonStr) {
    final dynamic decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup file structure: expected JSON object.');
    }

    final profile = decoded['profile'] as Map<String, dynamic>?;
    final userName = profile?['userName'] as String?;
    final profilePictureBase64 = profile?['profilePictureBase64'] as String?;

    final categories = decoded['categories'] as Map<String, dynamic>?;
    final expenseCategories = (categories?['expense'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final incomeCategories = (categories?['income'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final accountsRaw = decoded['accounts'] as List? ?? [];
    final accounts = accountsRaw
        .whereType<Map<String, dynamic>>()
        .map(Account.fromJson)
        .toList();

    final templatesRaw = decoded['templates'] as List? ?? [];
    final templates = templatesRaw
        .whereType<Map<String, dynamic>>()
        .map(TransactionTemplate.fromJson)
        .toList();

    final transactionsRaw = decoded['transactions'] as List? ?? [];
    final transactions = transactionsRaw
        .whereType<Map<String, dynamic>>()
        .map(Transaction.fromJson)
        .toList();

    return BackupData(
      accounts: accounts,
      transactions: transactions,
      templates: templates,
      expenseCategories: expenseCategories,
      incomeCategories: incomeCategories,
      userName: userName,
      profilePictureBase64: profilePictureBase64,
      format: 'json',
    );
  }

  /// Exports transactions to an RFC-4180 compliant CSV string.
  static String exportToCsv({
    required List<Transaction> transactions,
    required List<Account> accounts,
  }) {
    final accountMap = {for (var a in accounts) a.id: a.name};
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    final List<List<dynamic>> rows = [
      ['Date', 'Type', 'Amount', 'Category', 'Account', 'Note', 'Transaction ID']
    ];

    for (final tx in transactions) {
      final accountName = (tx.accountId != null && accountMap.containsKey(tx.accountId))
          ? accountMap[tx.accountId]!
          : 'Default';

      rows.add([
        dateFormat.format(tx.date),
        tx.type.name,
        tx.amount,
        tx.category,
        accountName,
        tx.note,
        tx.id,
      ]);
    }

    return csv.encode(rows);
  }

  /// Parses CSV transactions into [BackupData], reconstructing accounts if needed.
  static BackupData parseCsvBackup(
    String csvStr, {
    List<Account> existingAccounts = const [],
  }) {
    final List<List<dynamic>> rows = csv.decode(csvStr);

    if (rows.isEmpty) {
      throw const FormatException('CSV file is empty.');
    }

    // Header analysis
    final header = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();

    int dateIdx = header.indexOf('date');
    int typeIdx = header.indexOf('type');
    int amountIdx = header.indexOf('amount');
    int categoryIdx = header.indexOf('category');
    int accountIdx = header.indexOf('account');
    int noteIdx = header.indexOf('note');
    int idIdx = header.indexOf('transaction id');
    if (idIdx == -1) idIdx = header.indexOf('id');

    // Fallbacks if header is not found
    final bool hasHeader = dateIdx != -1 || amountIdx != -1;
    final int startRow = hasHeader ? 1 : 0;

    if (!hasHeader) {
      dateIdx = 0;
      typeIdx = 1;
      amountIdx = 2;
      categoryIdx = 3;
      accountIdx = 4;
      noteIdx = 5;
      idIdx = 6;
    }

    final Map<String, Account> accountByName = {
      for (var a in existingAccounts) a.name.trim().toLowerCase(): a
    };
    final List<Account> discoveredAccounts = [];
    final List<Transaction> transactions = [];
    final Set<String> discoveredExpenseCategories = {};
    final Set<String> discoveredIncomeCategories = {};
    const uuid = Uuid();

    for (int i = startRow; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || (row.length == 1 && row[0].toString().trim().isEmpty)) {
        continue;
      }

      String? dateStr = _safeGet(row, dateIdx);
      String? typeStr = _safeGet(row, typeIdx)?.toLowerCase();
      String? amountStr = _safeGet(row, amountIdx);
      String category = _safeGet(row, categoryIdx) ?? 'Other';
      String? accountName = _safeGet(row, accountIdx);
      String note = _safeGet(row, noteIdx) ?? '';
      String? txId = _safeGet(row, idIdx);

      if (dateStr == null && amountStr == null) continue;

      DateTime date;
      try {
        date = DateTime.parse(dateStr ?? '');
      } catch (_) {
        try {
          date = DateFormat('yyyy-MM-dd HH:mm:ss').parse(dateStr ?? '');
        } catch (_) {
          date = DateTime.now();
        }
      }

      final type = (typeStr == 'income')
          ? TransactionType.income
          : (typeStr == 'transfer')
              ? TransactionType.transfer
              : TransactionType.expense;
      final amount = double.tryParse(amountStr?.replaceAll(',', '') ?? '0') ?? 0.0;

      if (type == TransactionType.expense) {
        discoveredExpenseCategories.add(category);
      } else {
        discoveredIncomeCategories.add(category);
      }

      // Match or create account
      String accountId = 'default';
      if (accountName != null && accountName.trim().isNotEmpty) {
        final normName = accountName.trim().toLowerCase();
        if (accountByName.containsKey(normName)) {
          accountId = accountByName[normName]!.id;
        } else {
          final newAcc = Account(
            id: uuid.v4(),
            name: accountName.trim(),
            openingBalance: 0.0,
            colorHex: 0xFF1E88E5,
          );
          accountByName[normName] = newAcc;
          discoveredAccounts.add(newAcc);
          accountId = newAcc.id;
        }
      }

      transactions.add(Transaction(
        id: (txId != null && txId.trim().isNotEmpty) ? txId.trim() : uuid.v4(),
        amount: amount,
        type: type,
        category: category,
        date: date,
        note: note,
        accountId: accountId,
      ));
    }

    return BackupData(
      accounts: discoveredAccounts,
      transactions: transactions,
      templates: const [],
      expenseCategories: discoveredExpenseCategories.toList(),
      incomeCategories: discoveredIncomeCategories.toList(),
      format: 'csv',
    );
  }

  static String? _safeGet(List<dynamic> row, int index) {
    if (index >= 0 && index < row.length) {
      final val = row[index].toString().trim();
      return val.isEmpty ? null : val;
    }
    return null;
  }

  /// Saves content to a file via native system save dialog.
  /// Returns the saved file path or file name, or null if the user cancelled the dialog.
  static Future<String?> saveBackupFile({
    required String content,
    required String fileName,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    final mimeType = fileName.endsWith('.json') ? 'application/json' : 'text/csv';

    try {
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Save Backup',
        fileName: fileName,
        bytes: bytes,
        type: fileName.endsWith('.json') ? FileType.custom : FileType.any,
        allowedExtensions: fileName.endsWith('.json') ? ['json'] : ['csv'],
        mimeType: mimeType,
      );

      if (uri != null) {
        try {
          if (uri.scheme == 'file') {
            return uri.toFilePath();
          }
        } catch (_) {}
        return fileName;
      }
      return null; // User cancelled
    } catch (_) {
      // Fallback if native file save dialog is unavailable on current platform
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        return file.path;
      } catch (_) {
        final tempDir = Directory.systemTemp;
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(bytes);
        return file.path;
      }
    }
  }

  /// Opens native file picker offline and reads the local file content.
  static Future<({String content, String extension, String fileName})?> pickBackupFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json', 'csv'],
    );

    if (file == null) {
      return null;
    }

    String content;
    if (file.path != null) {
      content = await File(file.path!).readAsString();
    } else {
      final bytes = await file.readAsBytes();
      content = utf8.decode(bytes);
    }

    final extension = (file.extension ?? '').toLowerCase();
    return (content: content, extension: extension, fileName: file.name);
  }
}
