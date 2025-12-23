import 'package:flutter/material.dart';
import 'package:gsms/app/app.dart';
import 'package:gsms/app/theme_notifier.dart';
import 'package:gsms/features/home/domain/models/client_base_model.dart';
import 'package:gsms/features/home/domain/models/cost_base_model.dart';
import 'package:gsms/features/home/domain/models/price_base_model.dart';
import 'package:gsms/features/expedicao/domain/models/delivery_model.dart';
import 'package:gsms/features/expedicao/domain/models/driver_model.dart';
import 'package:gsms/features/expedicao/domain/models/order_model.dart';
import 'package:gsms/features/expedicao/domain/models/seller_model.dart';
import 'package:gsms/features/expedicao/domain/models/unknown_43_adapter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  // Registra os adaptadores
  // Register defensive adapter for legacy typeId 43 early, with override
  // to ensure it is available when nested reads occur.
  Hive.registerAdapter<Unknown43Type?>(Unknown43Adapter(), override: true);

  Hive.registerAdapter<PriceBaseModel>(PriceBaseModelAdapter());
  Hive.registerAdapter<ClientBaseModel>(ClientBaseModelAdapter());
  Hive.registerAdapter<CostBaseModel>(CostBaseModelAdapter());
  Hive.registerAdapter<DeliveryModel>(DeliveryModelAdapter());
  Hive.registerAdapter<DriverModel>(DriverModelAdapter());
  Hive.registerAdapter<OrderModel>(OrderModelAdapter());
  Hive.registerAdapter<SellerModel>(SellerModelAdapter());

  // Abre as boxes
  await Hive.openBox('settings');
  await Hive.openBox<PriceBaseModel>('price_base');
  await Hive.openBox<ClientBaseModel>('client_base');
  await Hive.openBox<CostBaseModel>('cost_base');
  await Hive.openBox<OrderModel>('orders');
  await Hive.openBox<DeliveryModel>('deliveries');
  await Hive.openBox<DriverModel>('drivers');
  await Hive.openBox<SellerModel>('sellers');
  await Hive.openBox('metadata');

  // Run one-time migration to ensure all DeliveryModel entries have explicit orderIds
  await _runExpedicaoMigrationsIfNeeded();

  runApp(
    ChangeNotifierProvider(create: (_) => ThemeNotifier(), child: const App()),
  );
}

/// One-time migration: ensure every stored DeliveryModel has explicit non-null
/// `orderIds` persisted. Uses `metadata` box to record migration completion.
Future<void> _runExpedicaoMigrationsIfNeeded() async {
  try {
    const migrationKey = 'expedicao_orderIds_migrated_v1';
    final meta = Hive.box('metadata');
    final already = meta.get(migrationKey) as bool?;
    if (already == true) return;

    final box = Hive.box<DeliveryModel>('deliveries');
    for (final key in box.keys) {
      final d = box.get(key);
      if (d == null) continue;
      // If orderIds is empty, write it explicitly so legacy records store the field
      if (d.orderIds.isEmpty) {
        // put will persist the current object state including orderIds
        await box.put(key, d);
      }
    }

    await meta.put(migrationKey, true);
  } catch (e, s) {
    // Swallow errors but log them to console for debugging
    // Migration must not prevent app startup
    // ignore: avoid_print
    print('Expedição migration failed: $e\n$s');
  }
}
