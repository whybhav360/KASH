import 'package:hive/hive.dart';

part 'goal.g.dart';

@HiveType(typeId: 2)
class Goal extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String title;
  @HiveField(2)
  double targetAmount;
  @HiveField(3)
  double currentAmount;

  Goal({
    required this.id,
    required this.title,
    required this.targetAmount,
    this.currentAmount = 0.0,
  });
}
