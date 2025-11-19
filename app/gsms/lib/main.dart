import 'package:flutter/material.dart';
import 'package:gsms/app/app.dart';
import 'package:gsms/app/theme_notifier.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: const App(),
    ),
  );
}
