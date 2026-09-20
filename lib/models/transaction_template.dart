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

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'amount': amount,
    'type': type.name,
    'category': category,
    'accountId': accountId,
    'note': note,
  };

  factory TransactionTemplate.fromJson(Map<String, dynamic> json) => TransactionTemplate(
    id: json['id'] as String,
    name: json['name'] as String,
    amount: (json['amount'] as num).toDouble(),
    type: (json['type'] as String) == 'income'
        ? TransactionType.income
        : (json['type'] as String) == 'transfer'
            ? TransactionType.transfer
            : TransactionType.expense,
    category: json['category'] as String,
    accountId: json['accountId'] as String?,
    note: (json['note'] as String?) ?? '',
  );
}
