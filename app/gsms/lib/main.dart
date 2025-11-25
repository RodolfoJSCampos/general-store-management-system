import 'package:flutter/material.dart';
import 'package:gsms/app/app.dart';
import 'package:gsms/app/theme_notifier.dart';
import 'package:gsms/features/home/domain/models/client_base_model.dart';
import 'package:gsms/features/home/domain/models/cost_base_model.dart';
import 'package:gsms/features/home/domain/models/price_base_model.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  // Registra os adaptadores
  Hive.registerAdapter(PriceBaseModelAdapter());
  Hive.registerAdapter(ClientBaseModelAdapter());
  Hive.registerAdapter(CostBaseModelAdapter());

  // Abre as boxes
  await Hive.openBox('settings');
  await Hive.openBox<PriceBaseModel>('price_base');
  await Hive.openBox<ClientBaseModel>('client_base');
  await Hive.openBox<CostBaseModel>('cost_base');
  await Hive.openBox('metadata');

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: const App(),
    ),
  );
}
