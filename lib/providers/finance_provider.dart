import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction.dart';
import '../models/goal.dart';

class FinanceProvider with ChangeNotifier {
  Box<Transaction>? _transactionBox;
  Box<Goal>? _goalBox;

  List<Transaction> _transactions = [];
  List<Goal> _goals = [];

  List<Transaction> get transactions => _transactions;
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

  Map<String, double> get categoryTotals {
    Map<String, double> totals = {};
    for (var t in _transactions.where((t) => t.type == TransactionType.expense)) {
      totals[t.category] = (totals[t.category] ?? 0) + t.amount;
    }
    return totals;
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
