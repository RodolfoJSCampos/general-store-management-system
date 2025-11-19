import 'package:flutter/material.dart';
import 'package:gsms/app/theme_notifier.dart';
import 'package:gsms/common/routes/app_routes.dart';
import 'package:provider/provider.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        return MaterialApp(
          title: 'General Store Management System',
          theme: ThemeData(
            colorSchemeSeed: Colors.blue,
            useMaterial3: true,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            colorSchemeSeed: Colors.blue,
            useMaterial3: true,
            brightness: Brightness.dark,
          ),
          themeMode: themeNotifier.themeMode,
          initialRoute: '/',
          routes: AppRoutes.routes,
        );
      },
    );
  }
}
