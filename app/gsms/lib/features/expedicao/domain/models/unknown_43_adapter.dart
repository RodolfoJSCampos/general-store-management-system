import 'package:hive/hive.dart';

/// A defensive, manual adapter for legacy objects stored with typeId=43.
///
/// This adapter attempts to read the incoming value generically and
/// returns a safe `String` representation. It's intentionally forgiving so
/// that legacy records won't crash the app; after startup you can run a
/// migration to normalize these values.
class Unknown43Adapter extends TypeAdapter<String> {
  @override
  final int typeId = 43;

  @override
  String read(BinaryReader reader) {
    try {
      // Try reading as a map-like object written by generated adapters
      final numOfFields = reader.readByte();
      final fields = <int, dynamic>{
        for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
      };
      // Build a compact string representation
      return fields.entries.map((e) => '${e.key}:${e.value}').join('|');
    } catch (_) {
      try {
        // Fallback: try to read a single dynamic value
        final v = reader.read();
        return v?.toString() ?? '<null>';
      } catch (_) {
        return '<unknown_type_43>';
      }
    }
  }

  @override
  void write(BinaryWriter writer, String obj) {
    // Not used — we don't intend to write this type back in its original form.
    writer.write(obj);
  }
}
