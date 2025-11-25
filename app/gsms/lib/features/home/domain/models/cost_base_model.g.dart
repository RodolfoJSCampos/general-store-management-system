// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cost_base_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CostBaseModelAdapter extends TypeAdapter<CostBaseModel> {
  @override
  final int typeId = 2;

  @override
  CostBaseModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CostBaseModel()
      ..code = fields[0] as String
      ..productDescription = fields[1] as String
      ..brand = fields[2] as String
      ..manufacturerRef = fields[3] as String
      ..cost = fields[4] as double;
  }

  @override
  void write(BinaryWriter writer, CostBaseModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.code)
      ..writeByte(1)
      ..write(obj.productDescription)
      ..writeByte(2)
      ..write(obj.brand)
      ..writeByte(3)
      ..write(obj.manufacturerRef)
      ..writeByte(4)
      ..write(obj.cost);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CostBaseModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
