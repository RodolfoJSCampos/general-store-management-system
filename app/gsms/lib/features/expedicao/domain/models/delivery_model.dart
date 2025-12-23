import 'package:hive/hive.dart';

part 'delivery_model.g.dart';

@HiveType(typeId: 10)
class DeliveryModel extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  List<String> orderIds = <String>[]; // IDs dos pedidos associados

  @HiveField(2)
  late String? driverId;

  @HiveField(7)
  List<String> teamDriverIds = <String>[]; // IDs da equipe de motoristas (primeiro é o motorista principal)

  @HiveField(3)
  late String status;

  @HiveField(4)
  late String createdAt;

  @HiveField(5)
  late String? dispatchedAt;

  @HiveField(6)
  late String? finishedAt;

  @HiveField(8)
  String? deliveryForecastDate; // Data prevista de entrega (formato ISO8601)

  @HiveField(9)
  String? deliveryForecastPeriod; // Período: 'manha' ou 'tarde'

  /// Empty constructor for Hive
  DeliveryModel();

  /// Factory constructor for creating new deliveries with orders
  factory DeliveryModel.create({
    required String id,
    required List<String> orderIds,
  }) {
    final now = DateTime.now().toIso8601String();
    final model = DeliveryModel();
    model.id = id;
    model.orderIds = orderIds;
    model.driverId = null;
    model.status = 'pending';
    model.createdAt = now;
    model.dispatchedAt = null;
    model.finishedAt = null;
    return model;
  }

  /// Get duration since dispatch
  Duration? get timeSinceDispatch {
    if (dispatchedAt == null) return null;
    final parsed = DateTime.tryParse(dispatchedAt!);
    if (parsed == null) return null;
    return DateTime.now().difference(parsed);
  }

  /// Format time since dispatch for display
  String get timeSinceDispatchFormatted {
    final dur = timeSinceDispatch;
    if (dur == null) return '—';
    if (dur.inDays > 0) return '${dur.inDays}d ${dur.inHours % 24}h';
    if (dur.inHours > 0) return '${dur.inHours}h ${dur.inMinutes % 60}m';
    return '${dur.inMinutes}m';
  }
}
