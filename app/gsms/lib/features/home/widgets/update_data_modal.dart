import 'package:flutter/material.dart';
import 'package:gsms/features/home/domain/models/database_info.dart'; // Import the new class
import 'package:gsms/features/home/widgets/import_clients_csv_modal.dart';
import 'package:gsms/features/home/widgets/import_costs_csv_modal.dart';
import 'package:gsms/features/home/widgets/import_csv_modal.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

/// A modal dialog for updating various data bases (prices, clients, costs).
/// It displays the last update time for each database and provides buttons to trigger the update process.
class UpdateDataModal extends StatefulWidget {
  const UpdateDataModal({super.key});

  @override
  State<UpdateDataModal> createState() => _UpdateDataModalState();
}

class _UpdateDataModalState extends State<UpdateDataModal> {
  // State variables to hold the last update timestamps for each database.
  String _priceBaseLastUpdate = 'Nunca';
  String _clientBaseLastUpdate = 'Nunca';
  String _costBaseLastUpdate = 'Nunca';

  @override
  void initState() {
    super.initState();
    _loadLastUpdate();
  }

  /// Loads the last update timestamps for price, client, and cost bases from Hive.
  /// Updates the UI state with the retrieved information.
  Future<void> _loadLastUpdate() async {
    // Access the metadata box directly as it's already opened at app startup.
    final metadataBox = Hive.box('metadata');

    // Retrieve and format the last update time for the price base.
    final priceLastUpdate = metadataBox.get('price_base_last_update') as String?;
    if (priceLastUpdate != null && mounted) {
      final dateTime = DateTime.parse(priceLastUpdate);
      final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
      setState(() {
        _priceBaseLastUpdate = formattedDate;
      });
    }

    // Retrieve and format the last update time for the client base.
    final clientLastUpdate = metadataBox.get('client_base_last_update') as String?;
    if (clientLastUpdate != null && mounted) {
      final dateTime = DateTime.parse(clientLastUpdate);
      final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
      setState(() {
        _clientBaseLastUpdate = formattedDate;
      });
    }

    // Retrieve and format the last update time for the cost base.
    final costLastUpdate = metadataBox.get('cost_base_last_update') as String?;
    if (costLastUpdate != null && mounted) {
      final dateTime = DateTime.parse(costLastUpdate);
      final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
      setState(() {
        _costBaseLastUpdate = formattedDate;
      });
    }
  }

  /// Handles the action when an update button is pressed for a specific database.
  /// Shows the corresponding CSV import modal and reloads the update timestamps upon completion.
  void _handleUpdatePressed(DatabaseInfo db) {
    if (db.name == 'Base de Preços') {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return const ImportCsvModal();
        },
      ).then((_) => _loadLastUpdate());
    } else if (db.name == 'Banco de Dados de Clientes') {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return const ImportClientsCsvModal();
        },
      ).then((_) => _loadLastUpdate());
    } else if (db.name == 'Base de Custos') {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return const ImportCostsCsvModal();
        },
      ).then((_) => _loadLastUpdate());
    } else {
      // Fallback for any other database types, showing a simple snackbar message.
      debugPrint('Atualizando ${db.name}...');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Atualizando ${db.name}...'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define the database information using the new DatabaseInfo class.
    final priceBaseDb = DatabaseInfo(
      name: 'Base de Preços',
      lastUpdate: _priceBaseLastUpdate,
      icon: Icons.attach_money,
    );

    final clientBaseDb = DatabaseInfo(
      name: 'Banco de Dados de Clientes',
      lastUpdate: _clientBaseLastUpdate,
      icon: Icons.people,
    );

    final costBaseDb = DatabaseInfo(
      name: 'Base de Custos',
      lastUpdate: _costBaseLastUpdate,
      icon: Icons.monetization_on,
    );

    final List<DatabaseInfo> databases = [priceBaseDb, clientBaseDb, costBaseDb];

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      // Use withValues for compatibility with older deprecated withOpacity.
      backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
      title: Row(
        children: [
          Icon(
            Icons.sync,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          const Text('Atualizar Bases de Dados'),
        ],
      ),
      content: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxWidth: 700),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: databases.length,
          itemBuilder: (BuildContext context, int index) {
            final db = databases[index];
            return Card(
              elevation: 2,
              margin:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: ListTile(
                leading: Icon(
                  db.icon, // Access icon directly from DatabaseInfo object
                  color: Theme.of(context).colorScheme.secondary,
                ),
                title: Text(
                  db.name, // Access name directly from DatabaseInfo object
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Última atualização: ${db.lastUpdate}', // Access lastUpdate directly
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                trailing: ElevatedButton.icon(
                  icon: const Icon(Icons.sync),
                  label: const Text('Atualizar'),
                  onPressed: () => _handleUpdatePressed(db), // Use the new handler method
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.primary,
          ),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}