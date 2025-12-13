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
      ..id = _readString(fields[0])
      ..orderIds = (fields[1] as List?)?.cast<String>() ?? <String>[]
      ..driverId = _readStringOrNull(fields[2])
      ..teamDriverIds = (fields[7] as List?)?.cast<String>() ?? <String>[]
      ..status = _readString(fields[3])
      ..createdAt = _readString(fields[4])
      ..dispatchedAt = _readStringOrNull(fields[5])
      ..finishedAt = _readStringOrNull(fields[6]);
  }

  static String _readString(dynamic value) {
    if (value is String) return value;
    if (value is List && value.isNotEmpty) {
      return value.first?.toString() ?? '';
    }
    return value?.toString() ?? '';
  }

  static String? _readStringOrNull(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is List && value.isNotEmpty) {
      return value.first?.toString();
    }
    return value.toString();
  }

  @override
  void write(BinaryWriter writer, DeliveryModel obj) {
    writer
      ..writeByte(8)
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
      ..write(obj.finishedAt);
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
