import 'package:hive/hive.dart';

part 'account.g.dart';

@HiveType(typeId: 3)
class Account extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  double openingBalance;
  @HiveField(3)
  int colorHex;
  @HiveField(4)
  String? bankProvider;
  @HiveField(5)
  int? iconCodePoint;
  @HiveField(6)
  String? customImagePath;

  Account({
    required this.id,
    required this.name,
    required this.openingBalance,
    required this.colorHex,
    this.bankProvider,
    this.iconCodePoint,
    this.customImagePath,
  });
}
