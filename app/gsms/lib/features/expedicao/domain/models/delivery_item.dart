import 'package:hive/hive.dart';

part 'delivery_item.g.dart';

@HiveType(typeId: 11)
class DeliveryItem extends HiveObject {
  @HiveField(0)
  late String productCode;

  @HiveField(1)
  late String? description;

  @HiveField(2)
  late double quantity;

  @HiveField(3)
  late double? unitPrice;

  /// Empty constructor for Hive
  DeliveryItem();

  /// Factory constructor for creating new items
  factory DeliveryItem.create({
    required String productCode,
    String? description,
    required double quantity,
    double? unitPrice,
  }) {
    final model = DeliveryItem();
    model.productCode = productCode;
    model.description = description;
    model.quantity = quantity;
    model.unitPrice = unitPrice;
    return model;
  }
}
