import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction.dart';
import '../models/goal.dart';

class FinanceProvider with ChangeNotifier {
  Box<Transaction>? _transactionBox;
  Box<Goal>? _goalBox;

  List<Transaction> _transactions = [];
  List<Goal> _goals = [];
  TransactionType? _filterType;

  List<Transaction> get transactions => _transactions;
  List<Transaction> get allTransactions => _transactions;
  
  List<Transaction> get filteredTransactions {
    if (_filterType == null) return _transactions;
    return _transactions.where((t) => t.type == _filterType).toList();
  }
  
  TransactionType? get filterType => _filterType;

  void setFilterType(TransactionType? type) {
    _filterType = type;
    notifyListeners();
  }
  List<Goal> get goals => _goals;

  Future<void> init() async {
    _transactionBox = await Hive.openBox<Transaction>('transactions');
    _goalBox = await Hive.openBox<Goal>('goals');
    _loadData();
  }

  void _loadData() {
    _transactions = _transactionBox?.values.toList() ?? [];
    // Sort by date descending
    _transactions.sort((a, b) => b.date.compareTo(a.date));
    _goals = _goalBox?.values.toList() ?? [];
    notifyListeners();
  }

  Future<void> refreshData() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _loadData();
  }

  // Transactions
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

  // Goals
  Future<void> addGoal(Goal goal) async {
    await _goalBox?.add(goal);
    _loadData();
  }

  Future<void> deleteGoal(Goal goal) async {
    await goal.delete();
    _loadData();
  }

  double get totalIncome => _transactions
      .where((t) => t.type == TransactionType.income)
      .fold(0, (sum, t) => sum + t.amount);

  double get totalExpenses => _transactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0, (sum, t) => sum + t.amount);

  double get totalBalance => totalIncome - totalExpenses;

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
    dates.sort((a, b) => b.compareTo(a)); // Newest first
    return dates;
  }

  // Insights Data
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
}
