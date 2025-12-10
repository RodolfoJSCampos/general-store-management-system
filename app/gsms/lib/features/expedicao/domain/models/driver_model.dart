import 'package:hive/hive.dart';

part 'driver_model.g.dart';

@HiveType(typeId: 12)
class DriverModel extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  /// Empty constructor for Hive
  DriverModel();

  /// Factory constructor for creating new drivers
  factory DriverModel.create({required String id, required String name}) {
    final model = DriverModel();
    model.id = id;
    model.name = name;
    return model;
  }
}
