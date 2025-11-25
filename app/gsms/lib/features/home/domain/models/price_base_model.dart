import 'package:hive/hive.dart';

part 'price_base_model.g.dart';

@HiveType(typeId: 0)
class PriceBaseModel extends HiveObject {
  @HiveField(0)
  late String code;

  @HiveField(1)
  late String description;

  @HiveField(2)
  late String brand;

  @HiveField(3)
  late double cashPrice;

  @HiveField(4)
  late double installmentPrice;

  @HiveField(5)
  late double tenTimesPrice;

  @HiveField(6)
  late double minimumPrice;
}
