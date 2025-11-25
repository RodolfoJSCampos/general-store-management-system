import 'package:hive/hive.dart';

part 'cost_base_model.g.dart';

@HiveType(typeId: 2)
class CostBaseModel extends HiveObject {
  @HiveField(0)
  late String code;

  @HiveField(1)
  late String productDescription;

  @HiveField(2)
  late String brand;

  @HiveField(3)
  late String manufacturerRef;

  @HiveField(4)
  late double cost;
}
