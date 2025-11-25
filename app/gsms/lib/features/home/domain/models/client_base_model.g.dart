// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client_base_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ClientBaseModelAdapter extends TypeAdapter<ClientBaseModel> {
  @override
  final int typeId = 1;

  @override
  ClientBaseModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ClientBaseModel()
      ..code = fields[0] as String
      ..legalName = fields[1] as String
      ..tradeName = fields[2] as String
      ..notes = fields[3] as String
      ..creditLimit = fields[4] as double
      ..isBlocked = fields[5] as bool;
  }

  @override
  void write(BinaryWriter writer, ClientBaseModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.code)
      ..writeByte(1)
      ..write(obj.legalName)
      ..writeByte(2)
      ..write(obj.tradeName)
      ..writeByte(3)
      ..write(obj.notes)
      ..writeByte(4)
      ..write(obj.creditLimit)
      ..writeByte(5)
      ..write(obj.isBlocked);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClientBaseModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
