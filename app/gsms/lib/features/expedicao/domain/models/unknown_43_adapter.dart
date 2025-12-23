import 'package:hive/hive.dart';

/// Placeholder class for unknown type 43
class Unknown43Type {
  const Unknown43Type();
}

/// A defensive, manual adapter for legacy objects stored with typeId=43.
///
/// This adapter attempts to read the incoming value generically and
/// returns null to avoid crashes. Legacy records with this type will
/// be silently ignored during reads.
class Unknown43Adapter extends TypeAdapter<Unknown43Type?> {
  @override
  final int typeId = 43;

  @override
  Unknown43Type? read(BinaryReader reader) {
    // Skip reading the actual data - just consume it
    try {
      // Read and discard the value
      reader.read();
    } catch (_) {
      // If read fails, try reading as structured data
      try {
        final numOfFields = reader.readByte();
        for (int i = 0; i < numOfFields; i++) {
          reader.readByte(); // field index
          try {
            reader.read(); // field value
          } catch (_) {}
        }
      } catch (_) {}
    }
    // Always return null for this unknown type
    return null;
  }

  @override
  void write(BinaryWriter writer, Unknown43Type? obj) {
    // Write null
    writer.write(null);
  }
}
