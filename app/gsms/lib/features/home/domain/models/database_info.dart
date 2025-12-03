import 'package:flutter/material.dart';

/// Represents information about a database, including its name, last update timestamp, and an associated icon.
///
/// This class provides a structured way to manage database metadata,
/// improving type safety and readability over generic `Map<String, dynamic>` objects.
class DatabaseInfo {
  final String name;
  final String lastUpdate;
  final IconData icon;

  const DatabaseInfo({
    required this.name,
    required this.lastUpdate,
    required this.icon,
  });
}
