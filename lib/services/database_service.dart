import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction.dart';
import '../models/goal.dart';
import '../models/account.dart';

class DatabaseService {
  static Future<void> init() async {
    await Hive.initFlutter();
    
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TransactionTypeAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TransactionAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(GoalAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(AccountAdapter());
  }
}
