import 'package:hive/hive.dart';

part 'seller_model.g.dart';

@HiveType(typeId: 14)
class SellerModel extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  /// Empty constructor for Hive
  SellerModel();

  /// Factory constructor for creating new sellers
  factory SellerModel.create({required String id, required String name}) {
    final model = SellerModel();
    model.id = id;
    model.name = name;
    return model;
  }
}
