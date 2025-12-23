// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delivery_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DeliveryModelAdapter extends TypeAdapter<DeliveryModel> {
  @override
  final int typeId = 10;

  @override
  DeliveryModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DeliveryModel()
      ..id = fields[0] as String
      ..orderIds = (fields[1] as List).cast<String>()
      ..driverId = fields[2] as String?
      ..teamDriverIds = (fields[7] as List).cast<String>()
      ..status = fields[3] as String
      ..createdAt = fields[4] as String
      ..dispatchedAt = fields[5] as String?
      ..finishedAt = fields[6] as String?
      ..deliveryForecastDate = fields[8] as String?
      ..deliveryForecastPeriod = fields[9] as String?;
  }

  @override
  void write(BinaryWriter writer, DeliveryModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.orderIds)
      ..writeByte(2)
      ..write(obj.driverId)
      ..writeByte(7)
      ..write(obj.teamDriverIds)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.dispatchedAt)
      ..writeByte(6)
      ..write(obj.finishedAt)
      ..writeByte(8)
      ..write(obj.deliveryForecastDate)
      ..writeByte(9)
      ..write(obj.deliveryForecastPeriod);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeliveryModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
