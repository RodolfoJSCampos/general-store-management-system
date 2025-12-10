// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delivery_model.dart';

// Diagnostic guard: when reading legacy/unknown records, log the first
// problematic `fields` map once so we can inspect the stored layout.
bool _expedicaoDeliveryAdapterLogged = false;

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DeliveryModelAdapter extends TypeAdapter<DeliveryModel> {
  @override
  final int typeId = 10;

  @override
  DeliveryModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    Map<int, dynamic> fields = <int, dynamic>{};
    try {
      fields = <int, dynamic>{
        for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
      };
    } catch (e, st) {
      // If Hive fails to read nested values (unknown typeId etc.), log and
      // return a safe default DeliveryModel to allow the box to open.
        if (!_expedicaoDeliveryAdapterLogged) {
        _expedicaoDeliveryAdapterLogged = true;
        try {
          developer.log('Expedicao DeliveryModelAdapter: failed to read fields: $e');
          developer.log(st.toString());
        } catch (_) {}
      }
      // Return an empty-but-valid DeliveryModel so startup can continue.
      final fallback = DeliveryModel();
      fallback.id = DateTime.now().millisecondsSinceEpoch.toString();
      fallback.orderIds = <String>[];
      fallback.driverId = null;
      fallback.status = 'pending';
      fallback.createdAt = DateTime.now().toIso8601String();
      fallback.dispatchedAt = null;
      fallback.finishedAt = null;
      return fallback;
    }
    final result = DeliveryModel();
    // Initialize late fields with safe defaults to avoid LateInitializationError
    result.id = '';
    result.orderIds = <String>[];
    result.driverId = null;
    result.status = '';
    result.createdAt = '';
    result.dispatchedAt = null;
    result.finishedAt = null;

    // Iterate available fields and assign by type rather than relying on
    // fixed positions — this tolerates legacy records with reordered fields.
    try {
      for (final entry in fields.entries) {
        final idx = entry.key;
        final val = entry.value;

        // If we encounter an unexpected value type, log the fields once so
        // we can inspect legacy layouts that cause casting errors.
        if (val is! String && val is! List) {
          if (!_expedicaoDeliveryAdapterLogged) {
            _expedicaoDeliveryAdapterLogged = true;
            try {
              developer.log(
                'Expedicao DeliveryModelAdapter: unexpected field types detected.',
              );
              developer.log(
                'fields: ${fields.entries.map((e) => '${e.key}: ${e.value} (type=${e.value.runtimeType})').toList()}',
              );
            } catch (_) {
              // ignore logging failures
            }
          }
        }

        if (val is List) {
          // Treat any List found as orderIds
          try {
            result.orderIds = val.cast<String>();
          } catch (_) {
            // If the list contains non-String items, coerce to String
            result.orderIds = val
                .map((e) => e?.toString() ?? '')
                .cast<String>()
                .toList();
          }
          continue;
        }
        if (val is String) {
          switch (idx) {
            case 0:
              // usually id
              result.id = val;
              break;
            case 1:
              // usually orderIds (handled above) but if String, treat as id fallback
              if (result.id.isEmpty) result.id = val;
              break;
            case 2:
              result.driverId = val;
              break;
            case 3:
              result.status = val;
              break;
            case 4:
              result.createdAt = val;
              break;
            case 5:
              result.dispatchedAt = val;
              break;
            case 6:
              result.finishedAt = val;
              break;
            default:
              break;
          }
        }
      }
    } catch (e, st) {
      if (!_expedicaoDeliveryAdapterLogged) {
        _expedicaoDeliveryAdapterLogged = true;
        try {
          developer.log('Expedicao DeliveryModelAdapter read() exception: $e');
          developer.log(st.toString());
          developer.log(
            'fields dump: ${fields.entries.map((e) => '${e.key}: ${e.value} (type=${e.value.runtimeType})').toList()}',
          );
        } catch (_) {}
      }
    }

    // Ensure sensible defaults for missing values
    if (result.id.isEmpty) {
      result.id = DateTime.now().millisecondsSinceEpoch.toString();
    }
    result.orderIds = result.orderIds.isEmpty ? <String>[] : result.orderIds;
    if (result.status.isEmpty) {
      result.status = 'pending';
    }
    if (result.createdAt.isEmpty) {
      result.createdAt = DateTime.now().toIso8601String();
    }

    return result;
  }

  @override
  void write(BinaryWriter writer, DeliveryModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.orderIds)
      ..writeByte(2)
      ..write(obj.driverId)
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
