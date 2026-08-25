import 'package:hive/hive.dart';
import 'transaction.dart';

part 'transaction_template.g.dart';

@HiveType(typeId: 4)
class TransactionTemplate extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  double amount;

  @HiveField(3)
  TransactionType type;

  @HiveField(4)
  String category;

  @HiveField(5)
  String? accountId;

  @HiveField(6)
  String note;

  TransactionTemplate({
    required this.id,
    required this.name,
    required this.amount,
    required this.type,
    required this.category,
    this.accountId,
    this.note = '',
  });
}
