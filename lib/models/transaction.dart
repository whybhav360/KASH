import 'package:hive/hive.dart';

part 'transaction.g.dart';

@HiveType(typeId: 0)
enum TransactionType {
  @HiveField(0)
  income,
  @HiveField(1)
  expense,
}

@HiveType(typeId: 1)
class Transaction extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  double amount;
  @HiveField(2)
  TransactionType type;
  @HiveField(3)
  String category;
  @HiveField(4)
  DateTime date;
  @HiveField(5)
  String note;
  @HiveField(6)
  String? accountId;

  Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    required this.note,
    this.accountId,
  });
}
