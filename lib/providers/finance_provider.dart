import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../models/goal.dart';
import '../models/account.dart';
import '../models/transaction_template.dart';
import '../services/backup_service.dart';

class FinanceProvider with ChangeNotifier {
  Box<Transaction>? _transactionBox;
  Box<Goal>? _goalBox;
  Box<Account>? _accountBox;
  Box<TransactionTemplate>? _templateBox;
  Box? _settingsBox;

  List<Transaction> _transactions = [];
  List<Goal> _goals = [];
  List<Account> _accounts = [];
  List<TransactionTemplate> _templates = [];
  String _userName = 'User';
  String? _userProfilePicture;
  List<String> _expenseCategories = ['Food', 'Transport', 'Rent', 'Entertainment', 'Health', 'Groceries', 'Shopping', 'Paid', 'Other'];
  List<String> _incomeCategories = ['Salary', 'Gift', 'Investment', 'Business', 'Other'];
  TransactionType? _filterType;
  String? _filterAccountId;
  String? _filterCategory;

  List<Transaction> get transactions => _transactions;
  String get userName => _userName;
  bool get hasChangedName {
    if (_settingsBox?.get('hasChangedName', defaultValue: false) == true) {
      return true;
    }
    final stored = _settingsBox?.get('userName');
    if (stored != null && stored.toString().trim().isNotEmpty && stored != 'User') {
      return true;
    }
    return false;
  }
  String? get userProfilePicture => _userProfilePicture;
  List<String> get expenseCategories => _expenseCategories;
  List<String> get incomeCategories => _incomeCategories;
  
  List<Transaction> get filteredTransactions {
    return _transactions.where((t) {
      final typeMatch = _filterType == null || t.type == _filterType;
      final accountMatch = _filterAccountId == null ||
          t.accountId == _filterAccountId ||
          t.toAccountId == _filterAccountId;
      final categoryMatch = _filterCategory == null || t.category == _filterCategory;
      return typeMatch && accountMatch && categoryMatch;
    }).toList();
  }
  
  TransactionType? get filterType => _filterType;
  String? get filterAccountId => _filterAccountId;
  String? get filterCategory => _filterCategory;

  Account? get primaryAccount =>
      _accounts.where((a) => a.isPrimary).firstOrNull ?? _accounts.firstOrNull;

  List<String> get usedCategories {
    final set = <String>{};
    for (var tx in _transactions) {
      final cat = tx.category.trim();
      if (cat.isNotEmpty) {
        set.add(cat);
      }
    }
    final list = set.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  void setFilterType(TransactionType? type) {
    _filterType = type;
    notifyListeners();
  }

  void setFilterAccount(String? accountId) {
    _filterAccountId = accountId;
    notifyListeners();
  }

  void setFilterCategory(String? category) {
    _filterCategory = category;
    notifyListeners();
  }

  List<Goal> get goals => _goals;
  List<Account> get accounts => _accounts;
  List<TransactionTemplate> get templates => _templates;

  Future<void> init() async {
    _transactionBox = await Hive.openBox<Transaction>('transactions');
    _goalBox = await Hive.openBox<Goal>('goals');
    _accountBox = await Hive.openBox<Account>('accounts');
    _templateBox = await Hive.openBox<TransactionTemplate>('templates');
    _settingsBox = await Hive.openBox('settings');
    
    _loadData();
  }

  void _loadData() {
    _transactions = _transactionBox?.values.toList() ?? [];
    _goals = _goalBox?.values.toList() ?? [];
    
    // Load accounts and apply persistent custom order
    final rawAccounts = _accountBox?.values.toList() ?? [];
    final List<String> savedOrder = List<String>.from(
      _settingsBox?.get('accountOrder', defaultValue: <String>[]) ?? [],
    );
    if (savedOrder.isNotEmpty) {
      rawAccounts.sort((a, b) {
        final aIndex = savedOrder.indexOf(a.id);
        final bIndex = savedOrder.indexOf(b.id);
        if (aIndex != -1 && bIndex != -1) return aIndex.compareTo(bIndex);
        if (aIndex != -1) return -1;
        if (bIndex != -1) return 1;
        return 0;
      });
    }
    _accounts = rawAccounts;

    // Ensure exactly one account is marked primary if accounts exist
    if (_accounts.isNotEmpty) {
      final primaryAccounts = _accounts.where((a) => a.isPrimary).toList();
      if (primaryAccounts.isEmpty) {
        _accounts.first.isPrimary = true;
        _accounts.first.save();
      } else if (primaryAccounts.length > 1) {
        for (int i = 1; i < primaryAccounts.length; i++) {
          primaryAccounts[i].isPrimary = false;
          primaryAccounts[i].save();
        }
      }
    }

    // Handle migration for old transactions without valid accountId
    bool needsRefresh = false;
    final primaryAccId = primaryAccount?.id;
    final validAccountIds = _accounts.map((a) => a.id).toSet();

    for (var tx in _transactions) {
      if (primaryAccId != null &&
          (tx.accountId == null || tx.accountId == 'default')) {
        tx.accountId = primaryAccId;
        tx.save();
        needsRefresh = true;
      } else if (tx.type != TransactionType.transfer &&
                 tx.accountId != null &&
                 validAccountIds.isNotEmpty &&
                 !validAccountIds.contains(tx.accountId)) {
        tx.delete();
        needsRefresh = true;
      } else if (tx.type == TransactionType.transfer && validAccountIds.isNotEmpty) {
        final fromValid = tx.accountId != null && validAccountIds.contains(tx.accountId);
        final toValid = tx.toAccountId != null && validAccountIds.contains(tx.toAccountId);
        if (!fromValid && !toValid) {
          tx.delete();
          needsRefresh = true;
        }
      }
    }
    if (needsRefresh) {
      _transactions = _transactionBox?.values.toList() ?? [];
    }

    _transactions.sort((a, b) => b.date.compareTo(a.date));
    _templates = _templateBox?.values.toList() ?? [];
    _userName = _settingsBox?.get('userName', defaultValue: 'User') ?? 'User';
    _userProfilePicture = _settingsBox?.get('profilePicture');
    _expenseCategories = List<String>.from(_settingsBox?.get('expenseCategories', defaultValue: ['Food', 'Transport', 'Rent', 'Entertainment', 'Health', 'Groceries', 'Shopping', 'Paid', 'Other']));
    if (!_expenseCategories.contains('Paid')) {
      final otherIdx = _expenseCategories.indexOf('Other');
      if (otherIdx != -1) {
        _expenseCategories.insert(otherIdx, 'Paid');
      } else {
        _expenseCategories.add('Paid');
      }
      _settingsBox?.put('expenseCategories', _expenseCategories);
    }
    _incomeCategories = List<String>.from(_settingsBox?.get('incomeCategories', defaultValue: ['Salary', 'Gift', 'Investment', 'Business', 'Other']));
    notifyListeners();
  }

  Future<void> setUserName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) {
      await _settingsBox?.put('userName', trimmed);
      await _settingsBox?.put('hasChangedName', true);
      _userName = trimmed;
      notifyListeners();
    }
  }

  Future<void> setUserProfilePicture(String? path) async {
    await _settingsBox?.put('profilePicture', path);
    _userProfilePicture = path;
    notifyListeners();
  }

  Future<void> addExpenseCategory(String category) async {
    if (!_expenseCategories.contains(category)) {
      _expenseCategories.add(category);
      await _settingsBox?.put('expenseCategories', _expenseCategories);
      notifyListeners();
    }
  }

  Future<void> removeExpenseCategory(String category) async {
    _expenseCategories.remove(category);
    await _settingsBox?.put('expenseCategories', _expenseCategories);
    notifyListeners();
  }

  Future<void> reorderExpenseCategories(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _expenseCategories.length) return;
    if (newIndex < 0) newIndex = 0;
    if (newIndex > _expenseCategories.length) newIndex = _expenseCategories.length;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _expenseCategories.removeAt(oldIndex);
    _expenseCategories.insert(newIndex, item);
    await _settingsBox?.put('expenseCategories', _expenseCategories);
    notifyListeners();
  }

  Future<void> addIncomeCategory(String category) async {
    if (!_incomeCategories.contains(category)) {
      _incomeCategories.add(category);
      await _settingsBox?.put('incomeCategories', _incomeCategories);
      notifyListeners();
    }
  }

  Future<void> removeIncomeCategory(String category) async {
    _incomeCategories.remove(category);
    await _settingsBox?.put('incomeCategories', _incomeCategories);
    notifyListeners();
  }

  Future<void> reorderIncomeCategories(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _incomeCategories.length) return;
    if (newIndex < 0) newIndex = 0;
    if (newIndex > _incomeCategories.length) newIndex = _incomeCategories.length;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _incomeCategories.removeAt(oldIndex);
    _incomeCategories.insert(newIndex, item);
    await _settingsBox?.put('incomeCategories', _incomeCategories);
    notifyListeners();
  }

  Future<void> refreshData() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _loadData();
  }

  // Account Management
  Future<void> addAccount(Account account) async {
    if (account.isPrimary || _accounts.isEmpty) {
      account.isPrimary = true;
      for (var a in _accounts) {
        if (a.isPrimary) {
          a.isPrimary = false;
          await a.save();
        }
      }
    }
    await _accountBox?.add(account);
    final List<String> currentOrder = List<String>.from(
      _settingsBox?.get('accountOrder', defaultValue: <String>[]) ?? [],
    );
    if (!currentOrder.contains(account.id)) {
      currentOrder.add(account.id);
      await _settingsBox?.put('accountOrder', currentOrder);
    }
    _loadData();
  }

  Future<void> updateAccount(Account account) async {
    if (account.isPrimary) {
      for (var a in _accounts) {
        if (a.id != account.id && a.isPrimary) {
          a.isPrimary = false;
          await a.save();
        }
      }
    } else {
      final hasOtherPrimary = _accounts.any((a) => a.id != account.id && a.isPrimary);
      if (!hasOtherPrimary && _accounts.isNotEmpty) {
        final other = _accounts.where((a) => a.id != account.id).firstOrNull;
        if (other != null) {
          other.isPrimary = true;
          await other.save();
        } else {
          account.isPrimary = true;
        }
      }
    }
    await account.save();
    _loadData();
  }

  Future<void> deleteAccount(Account account) async {
    // 1. Permanently delete non-transfer transactions associated with this account.
    // For transfer transactions: keep them if the other participating account still exists.
    if (_transactionBox != null) {
      final txKeysToDelete = <dynamic>[];
      final remainingAccountIds = _accounts.where((a) => a.id != account.id).map((a) => a.id).toSet();

      for (var key in _transactionBox!.keys) {
        final tx = _transactionBox!.get(key);
        if (tx != null) {
          if (tx.type == TransactionType.transfer) {
            final isParticipant = tx.accountId == account.id || tx.toAccountId == account.id;
            if (isParticipant) {
              final otherId = tx.accountId == account.id ? tx.toAccountId : tx.accountId;
              final otherExists = otherId != null && remainingAccountIds.contains(otherId);
              if (!otherExists) {
                txKeysToDelete.add(key);
              }
            }
          } else if (tx.accountId == account.id) {
            txKeysToDelete.add(key);
          }
        }
      }
      for (var key in txKeysToDelete) {
        await _transactionBox!.delete(key);
      }
    }

    // 2. Permanently delete all templates associated with this account
    if (_templateBox != null) {
      final tplKeysToDelete = <dynamic>[];
      for (var key in _templateBox!.keys) {
        final tpl = _templateBox!.get(key);
        if (tpl != null && tpl.accountId == account.id) {
          tplKeysToDelete.add(key);
        }
      }
      for (var key in tplKeysToDelete) {
        await _templateBox!.delete(key);
      }
    }

    // 3. Delete the account from Hive
    await account.delete();
    final List<String> currentOrder = List<String>.from(
      _settingsBox?.get('accountOrder', defaultValue: <String>[]) ?? [],
    );
    currentOrder.remove(account.id);
    await _settingsBox?.put('accountOrder', currentOrder);
    _loadData();
  }

  /// Reconciles an account balance to match the actual bank balance.
  /// If [createAdjustmentTransaction] is true, records an Adjustment transaction
  /// for the difference so it appears clearly in transaction history.
  /// Otherwise, directly updates the account's [openingBalance].
  Future<void> reconcileAccountBalance(
    String accountId,
    double actualBalance, {
    bool createAdjustmentTransaction = true,
  }) async {
    final account = _accounts.firstWhere(
      (a) => a.id == accountId,
      orElse: () => Account(id: '', name: '', openingBalance: 0, colorHex: 0),
    );
    if (account.id.isEmpty) return;

    final currentBalance = getAccountBalance(accountId);
    final diff = actualBalance - currentBalance;
    if (diff.abs() < 0.001) return;

    if (createAdjustmentTransaction) {
      final isIncome = diff > 0;
      final adjTx = Transaction(
        id: const Uuid().v4(),
        amount: (diff.abs() * 100).round() / 100,
        type: isIncome ? TransactionType.income : TransactionType.expense,
        category: 'Adjustment',
        date: DateTime.now(),
        note: 'Balance adjustment to match actual bank balance',
        accountId: accountId,
      );
      await addTransaction(adjTx);
    } else {
      account.openingBalance += diff;
      await account.save();
      _loadData();
    }
  }

  Future<void> reorderAccounts(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _accounts.length) return;
    if (newIndex < 0) newIndex = 0;
    if (newIndex > _accounts.length) newIndex = _accounts.length;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _accounts.removeAt(oldIndex);
    _accounts.insert(newIndex, item);
    final order = _accounts.map((a) => a.id).toList();
    await _settingsBox?.put('accountOrder', order);
    notifyListeners();
  }

  // Transaction Management
  Future<void> addTransaction(Transaction transaction) async {
    if (_accounts.isNotEmpty &&
        (transaction.accountId == null ||
            transaction.accountId == 'default' ||
            !_accounts.any((a) => a.id == transaction.accountId))) {
      transaction.accountId = primaryAccount?.id ?? _accounts.first.id;
    }
    await _transactionBox?.add(transaction);
    _loadData();
  }

  Future<int> addTransactions(List<Transaction> newTransactions) async {
    if (newTransactions.isEmpty) return 0;
    final defaultId = primaryAccount?.id ?? (_accounts.isNotEmpty ? _accounts.first.id : null);
    for (final tx in newTransactions) {
      if (defaultId != null &&
          (tx.accountId == null ||
              tx.accountId == 'default' ||
              !_accounts.any((a) => a.id == tx.accountId))) {
        tx.accountId = defaultId;
      }
      await _transactionBox?.add(tx);
    }
    _loadData();
    return newTransactions.length;
  }

  Future<void> updateTransaction(Transaction transaction) async {
    await transaction.save();
    _loadData();
  }

  Future<void> deleteTransaction(Transaction transaction) async {
    await transaction.delete();
    _loadData();
  }

  // Transfer Between Accounts
  Future<void> transfer({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    final toAcc = _accounts.firstWhere(
      (a) => a.id == toAccountId,
      orElse: () => Account(id: '', name: 'Account', openingBalance: 0, colorHex: 0),
    );
    final transferTx = Transaction(
      id: const Uuid().v4(),
      amount: amount,
      type: TransactionType.transfer,
      category: 'Transfer',
      date: date,
      note: (note != null && note.trim().isNotEmpty)
          ? note.trim()
          : 'Transfer to ${toAcc.name}',
      accountId: fromAccountId,
      toAccountId: toAccountId,
    );
    await addTransaction(transferTx);
  }

  // Template Management
  Future<void> addTemplate(TransactionTemplate template) async {
    await _templateBox?.add(template);
    _loadData();
  }

  Future<void> deleteTemplate(TransactionTemplate template) async {
    await template.delete();
    _loadData();
  }

  // Balance Calculations
  double get totalNetWorth {
    double total = _accounts.fold(0, (sum, acc) => sum + acc.openingBalance);
    total += totalIncome - totalExpenses;
    return total;
  }

  double getAccountBalance(String accountId) {
    final account = _accounts.firstWhere((a) => a.id == accountId, 
      orElse: () => Account(id: '', name: '', openingBalance: 0, colorHex: 0));
    if (account.id == '') return 0;

    double balance = account.openingBalance;
    for (var t in _transactions) {
      if (t.type == TransactionType.income && t.accountId == accountId) {
        balance += t.amount;
      } else if (t.type == TransactionType.expense && t.accountId == accountId) {
        balance -= t.amount;
      } else if (t.type == TransactionType.transfer) {
        if (t.accountId == accountId) {
          balance -= t.amount;
        }
        if (t.toAccountId == accountId) {
          balance += t.amount;
        }
      }
    }
    return balance;
  }

  double get totalIncome => _transactions
      .where((t) => t.type == TransactionType.income)
      .fold(0, (sum, t) => sum + t.amount);

  double get totalExpenses => _transactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0, (sum, t) => sum + t.amount);

  double get totalBalance => totalNetWorth;

  Map<String, double> getCategoryTotalsForMonth(int month, int year) {
    Map<String, double> totals = {};
    for (var t in _transactions.where((t) =>
        t.type == TransactionType.expense &&
        t.date.month == month &&
        t.date.year == year)) {
      totals[t.category] = (totals[t.category] ?? 0) + t.amount;
    }
    return totals;
  }

  List<DateTime> get availableMonths {
    if (_transactions.isEmpty) {
      final now = DateTime.now();
      return [DateTime(now.year, now.month)];
    }
    
    final dates = _transactions.map((t) => DateTime(t.date.year, t.date.month)).toSet().toList();
    dates.sort((a, b) => b.compareTo(a));
    return dates;
  }

  double get currentMonthExpenses {
    final now = DateTime.now();
    return _transactions
        .where((t) => t.type == TransactionType.expense && t.date.month == now.month && t.date.year == now.year)
        .fold(0, (sum, t) => sum + t.amount);
  }

  double get lastMonthExpenses {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1);
    return _transactions
        .where((t) => t.type == TransactionType.expense && t.date.month == lastMonth.month && t.date.year == lastMonth.year)
        .fold(0, (sum, t) => sum + t.amount);
  }

  // Goal Management
  Future<void> addGoal(Goal goal) async {
    await _goalBox?.add(goal);
    _loadData();
  }

  Future<void> deleteGoal(Goal goal) async {
    await goal.delete();
    _loadData();
  }

  // Backup & Restore (Excluding Goals)
  Future<void> importBackupData(BackupData data, {required bool replaceExisting}) async {
    // Restore images from Base64 into local app storage for cross-device portability
    try {
      final appDir = await getApplicationDocumentsDirectory();
      for (final account in data.accounts) {
        if (account.imageBase64 != null && account.imageBase64!.isNotEmpty) {
          try {
            final bytes = base64Decode(account.imageBase64!);
            final file = File('${appDir.path}/account_${account.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');
            await file.writeAsBytes(bytes);
            account.customImagePath = file.path;
          } catch (_) {}
        }
      }

      if (data.profilePictureBase64 != null && data.profilePictureBase64!.isNotEmpty) {
        try {
          final bytes = base64Decode(data.profilePictureBase64!);
          final file = File('${appDir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await file.writeAsBytes(bytes);
          await _settingsBox?.put('profilePicture', file.path);
          _userProfilePicture = file.path;
        } catch (_) {}
      }
    } catch (_) {}

    if (replaceExisting) {
      // Clear non-goal boxes: GOALS ARE STRICTLY EXCLUDED AND PRESERVED
      await _transactionBox?.clear();
      await _accountBox?.clear();
      await _templateBox?.clear();

      if (data.expenseCategories.isNotEmpty) {
        _expenseCategories = List<String>.from(data.expenseCategories);
        await _settingsBox?.put('expenseCategories', _expenseCategories);
      }
      if (data.incomeCategories.isNotEmpty) {
        _incomeCategories = List<String>.from(data.incomeCategories);
        await _settingsBox?.put('incomeCategories', _incomeCategories);
      }
      if (data.userName != null && data.userName!.trim().isNotEmpty) {
        _userName = data.userName!.trim();
        await _settingsBox?.put('userName', _userName);
        await _settingsBox?.put('hasChangedName', true);
      }

      for (final account in data.accounts) {
        await _accountBox?.add(account);
      }

      for (final template in data.templates) {
        await _templateBox?.add(template);
      }

      for (final tx in data.transactions) {
        await _transactionBox?.add(tx);
      }
    } else {
      // Merge mode
      bool expCatChanged = false;
      for (final cat in data.expenseCategories) {
        if (!_expenseCategories.contains(cat)) {
          _expenseCategories.add(cat);
          expCatChanged = true;
        }
      }
      if (expCatChanged) {
        await _settingsBox?.put('expenseCategories', _expenseCategories);
      }

      bool incCatChanged = false;
      for (final cat in data.incomeCategories) {
        if (!_incomeCategories.contains(cat)) {
          _incomeCategories.add(cat);
          incCatChanged = true;
        }
      }
      if (incCatChanged) {
        await _settingsBox?.put('incomeCategories', _incomeCategories);
      }

      if (data.userName != null && data.userName!.trim().isNotEmpty && _userName == 'User') {
        _userName = data.userName!.trim();
        await _settingsBox?.put('userName', _userName);
        await _settingsBox?.put('hasChangedName', true);
      }

      for (final newAcc in data.accounts) {
        final existing = _accounts.where((a) => a.id == newAcc.id).firstOrNull;
        if (existing != null) {
          existing.name = newAcc.name;
          existing.openingBalance = newAcc.openingBalance;
          existing.colorHex = newAcc.colorHex;
          existing.bankProvider = newAcc.bankProvider;
          existing.iconCodePoint = newAcc.iconCodePoint;
          existing.customImagePath = newAcc.customImagePath;
          existing.isPrimary = newAcc.isPrimary;
          await existing.save();
        } else {
          await _accountBox?.add(newAcc);
        }
      }

      for (final newTemplate in data.templates) {
        final existing = _templates.where((t) => t.id == newTemplate.id).firstOrNull;
        if (existing != null) {
          existing.name = newTemplate.name;
          existing.amount = newTemplate.amount;
          existing.type = newTemplate.type;
          existing.category = newTemplate.category;
          existing.accountId = newTemplate.accountId;
          existing.note = newTemplate.note;
          await existing.save();
        } else {
          await _templateBox?.add(newTemplate);
        }
      }

      for (final newTx in data.transactions) {
        final existing = _transactions.where((t) => t.id == newTx.id).firstOrNull;
        if (existing != null) {
          existing.amount = newTx.amount;
          existing.type = newTx.type;
          existing.category = newTx.category;
          existing.date = newTx.date;
          existing.note = newTx.note;
          existing.accountId = newTx.accountId;
          await existing.save();
        } else {
          await _transactionBox?.add(newTx);
        }
      }
    }

    _loadData();
  }
}
