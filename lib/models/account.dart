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
  String? imageBase64;
  @HiveField(7)
  bool isPrimary;

  Account({
    required this.id,
    required this.name,
    required this.openingBalance,
    required this.colorHex,
    this.bankProvider,
    this.iconCodePoint,
    this.customImagePath,
    this.imageBase64,
    this.isPrimary = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'openingBalance': openingBalance,
    'colorHex': colorHex,
    'bankProvider': bankProvider,
    'iconCodePoint': iconCodePoint,
    'customImagePath': customImagePath,
    'isPrimary': isPrimary,
    if (imageBase64 != null) 'imageBase64': imageBase64,
  };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['id'] as String,
    name: json['name'] as String,
    openingBalance: (json['openingBalance'] as num?)?.toDouble() ?? 0.0,
    colorHex: json['colorHex'] as int? ?? 0xFF1E88E5,
    bankProvider: json['bankProvider'] as String?,
    iconCodePoint: json['iconCodePoint'] as int?,
    customImagePath: json['customImagePath'] as String?,
    imageBase64: json['imageBase64'] as String?,
    isPrimary: json['isPrimary'] as bool? ?? false,
  );
}
