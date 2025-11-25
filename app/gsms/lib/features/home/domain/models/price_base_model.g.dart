// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'price_base_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PriceBaseModelAdapter extends TypeAdapter<PriceBaseModel> {
  @override
  final int typeId = 0;

  @override
  PriceBaseModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PriceBaseModel()
      ..code = fields[0] as String
      ..description = fields[1] as String
      ..brand = fields[2] as String
      ..cashPrice = fields[3] as double
      ..installmentPrice = fields[4] as double
      ..tenTimesPrice = fields[5] as double
      ..minimumPrice = fields[6] as double;
  }

  @override
  void write(BinaryWriter writer, PriceBaseModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.code)
      ..writeByte(1)
      ..write(obj.description)
      ..writeByte(2)
      ..write(obj.brand)
      ..writeByte(3)
      ..write(obj.cashPrice)
      ..writeByte(4)
      ..write(obj.installmentPrice)
      ..writeByte(5)
      ..write(obj.tenTimesPrice)
      ..writeByte(6)
      ..write(obj.minimumPrice);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PriceBaseModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
