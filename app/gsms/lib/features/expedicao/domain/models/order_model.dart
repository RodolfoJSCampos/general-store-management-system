import 'package:hive/hive.dart';

part 'order_model.g.dart';

@HiveType(typeId: 13)
class OrderModel extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String orderNumber;

  @HiveField(2)
  late String responsible;

  @HiveField(3)
  late String createdAt;

  /// Empty constructor for Hive
  OrderModel();

  /// Factory constructor for creating new orders
  factory OrderModel.create({
    required String id,
    required String orderNumber,
    required String responsible,
  }) {
    final model = OrderModel();
    model.id = id;
    model.orderNumber = orderNumber;
    model.responsible = responsible;
    model.createdAt = DateTime.now().toIso8601String();
    return model;
  }
}
