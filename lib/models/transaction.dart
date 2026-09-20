import 'package:hive/hive.dart';

part 'transaction.g.dart';

@HiveType(typeId: 0)
enum TransactionType {
  @HiveField(0)
  income,
  @HiveField(1)
  expense,
  @HiveField(2)
  transfer,
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
  @HiveField(7)
  String? toAccountId;

  Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    required this.note,
    this.accountId,
    this.toAccountId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'type': type.name,
    'category': category,
    'date': date.toIso8601String(),
    'note': note,
    'accountId': accountId,
    if (toAccountId != null) 'toAccountId': toAccountId,
  };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'] as String,
    amount: (json['amount'] as num).toDouble(),
    type: (json['type'] as String) == 'income'
        ? TransactionType.income
        : (json['type'] as String) == 'transfer'
            ? TransactionType.transfer
            : TransactionType.expense,
    category: json['category'] as String,
    date: DateTime.parse(json['date'] as String),
    note: (json['note'] as String?) ?? '',
    accountId: json['accountId'] as String?,
    toAccountId: json['toAccountId'] as String?,
  );
}
