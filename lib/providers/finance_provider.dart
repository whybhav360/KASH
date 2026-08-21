import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction.dart';
import '../models/goal.dart';
import '../models/account.dart';
import '../models/transaction_template.dart';

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
  List<String> _expenseCategories = ['Food', 'Transport', 'Rent', 'Entertainment', 'Health', 'Groceries', 'Shopping', 'Other'];
  List<String> _incomeCategories = ['Salary', 'Gift', 'Investment', 'Business', 'Other'];
  TransactionType? _filterType;
  String? _filterAccountId;

  List<Transaction> get transactions => _transactions;
  String get userName => _userName;
  String? get userProfilePicture => _userProfilePicture;
  List<String> get expenseCategories => _expenseCategories;
  List<String> get incomeCategories => _incomeCategories;
  
  List<Transaction> get filteredTransactions {
    return _transactions.where((t) {
      final typeMatch = _filterType == null || t.type == _filterType;
      final accountMatch = _filterAccountId == null || t.accountId == _filterAccountId;
      return typeMatch && accountMatch;
    }).toList();
  }
  
  TransactionType? get filterType => _filterType;
  String? get filterAccountId => _filterAccountId;

  void setFilterType(TransactionType? type) {
    _filterType = type;
    notifyListeners();
  }

  void setFilterAccount(String? accountId) {
    _filterAccountId = accountId;
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
    
    // Create default account if none exists
    if (_accountBox!.isEmpty) {
      await _accountBox!.add(Account(
        id: 'default',
        name: 'Main Savings',
        openingBalance: 12450.0,
        colorHex: 0xFF4F46E5,
        iconCodePoint: Icons.account_balance_wallet_rounded.codePoint,
      ));
    }
    
    _loadData();
  }

  void _loadData() {
    _transactions = _transactionBox?.values.toList() ?? [];
    
    // Handle migration for old transactions without accountId
    bool needsRefresh = false;
    for (var tx in _transactions) {
      if (tx.accountId == null) {
        tx.accountId = 'default';
        tx.save();
        needsRefresh = true;
      }
    }
    if (needsRefresh) {
      _transactions = _transactionBox?.values.toList() ?? [];
    }

    _transactions.sort((a, b) => b.date.compareTo(a.date));
    _goals = _goalBox?.values.toList() ?? [];
    _accounts = _accountBox?.values.toList() ?? [];
    _templates = _templateBox?.values.toList() ?? [];
    _userName = _settingsBox?.get('userName', defaultValue: 'John Doe') ?? 'John Doe';
    _userProfilePicture = _settingsBox?.get('profilePicture');
    _expenseCategories = List<String>.from(_settingsBox?.get('expenseCategories', defaultValue: ['Food', 'Transport', 'Rent', 'Entertainment', 'Health', 'Groceries', 'Shopping', 'Other']));
    _incomeCategories = List<String>.from(_settingsBox?.get('incomeCategories', defaultValue: ['Salary', 'Gift', 'Investment', 'Business', 'Other']));
    notifyListeners();
  }

  Future<void> setUserName(String name) async {
    await _settingsBox?.put('userName', name);
    _userName = name;
    notifyListeners();
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

  Future<void> refreshData() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _loadData();
  }

  // Account Management
  Future<void> addAccount(Account account) async {
    await _accountBox?.add(account);
    _loadData();
  }

  Future<void> updateAccount(Account account) async {
    await account.save();
    _loadData();
  }

  Future<void> deleteAccount(Account account) async {
    // Optional: handle transactions linked to this account
    await account.delete();
    _loadData();
  }

  // Transaction Management
  Future<void> addTransaction(Transaction transaction) async {
    await _transactionBox?.add(transaction);
    _loadData();
  }

  Future<void> updateTransaction(Transaction transaction) async {
    await transaction.save();
    _loadData();
  }

  Future<void> deleteTransaction(Transaction transaction) async {
    await transaction.delete();
    _loadData();
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
    final accountTransactions = _transactions.where((t) => t.accountId == accountId);
    for (var t in accountTransactions) {
      if (t.type == TransactionType.income) {
        balance += t.amount;
      } else {
        balance -= t.amount;
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
}
