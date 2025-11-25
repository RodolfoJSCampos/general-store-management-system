import 'package:hive/hive.dart';

part 'client_base_model.g.dart';

@HiveType(typeId: 1)
class ClientBaseModel extends HiveObject {
  @HiveField(0)
  late String code;

  @HiveField(1)
  late String legalName;

  @HiveField(2)
  late String tradeName;

  @HiveField(3)
  late String notes;

  @HiveField(4)
  late double creditLimit;

  @HiveField(5)
  late bool isBlocked;
}
