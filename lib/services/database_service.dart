import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../models/goal.dart';
import '../providers/finance_provider.dart';

class DatabaseService {
  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(TransactionAdapter());
    Hive.registerAdapter(TransactionTypeAdapter());
    Hive.registerAdapter(GoalAdapter());
  }

  static void preloadDemoData(FinanceProvider provider) {
    final now = DateTime.now();
    provider.addTransaction(Transaction(
      id: const Uuid().v4(),
      amount: 5000,
      type: TransactionType.income,
      category: 'Salary',
      date: now.subtract(const Duration(days: 5)),
      note: 'Monthly salary',
    ));
    provider.addTransaction(Transaction(
      id: const Uuid().v4(),
      amount: 50,
      type: TransactionType.expense,
      category: 'Food',
      date: now.subtract(const Duration(days: 2)),
      note: 'Lunch at cafe',
    ));
    provider.addTransaction(Transaction(
      id: const Uuid().v4(),
      amount: 1200,
      type: TransactionType.expense,
      category: 'Rent',
      date: now.subtract(const Duration(days: 1)),
      note: 'Monthly rent',
    ));
    
    provider.addGoal(Goal(
      id: const Uuid().v4(),
      title: 'New Laptop',
      targetAmount: 2500,
    ));
  }
}
