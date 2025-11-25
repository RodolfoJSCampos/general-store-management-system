import 'package:flutter/material.dart';
import 'package:gsms/features/home/widgets/import_clients_csv_modal.dart';
import 'package:gsms/features/home/widgets/import_costs_csv_modal.dart';
import 'package:gsms/features/home/widgets/import_csv_modal.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

class UpdateDataModal extends StatefulWidget {
  const UpdateDataModal({super.key});

  @override
  State<UpdateDataModal> createState() => _UpdateDataModalState();
}

class _UpdateDataModalState extends State<UpdateDataModal> {
  String _priceBaseLastUpdate = 'Nunca';
  String _clientBaseLastUpdate = 'Nunca';
  String _costBaseLastUpdate = 'Nunca';

  @override
  void initState() {
    super.initState();
    _loadLastUpdate();
  }

  Future<void> _loadLastUpdate() async {
    final metadataBox = await Hive.openBox('metadata');

    final priceLastUpdate = metadataBox.get('price_base_last_update') as String?;
    if (priceLastUpdate != null && mounted) {
      final dateTime = DateTime.parse(priceLastUpdate);
      final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
      setState(() {
        _priceBaseLastUpdate = formattedDate;
      });
    }

    final clientLastUpdate = metadataBox.get('client_base_last_update') as String?;
    if (clientLastUpdate != null && mounted) {
      final dateTime = DateTime.parse(clientLastUpdate);
      final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
      setState(() {
        _clientBaseLastUpdate = formattedDate;
      });
    }

    final costLastUpdate = metadataBox.get('cost_base_last_update') as String?;
    if (costLastUpdate != null && mounted) {
      final dateTime = DateTime.parse(costLastUpdate);
      final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
      setState(() {
        _costBaseLastUpdate = formattedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final priceBaseDb = {
      'name': 'Base de Preços',
      'lastUpdate': _priceBaseLastUpdate,
      'icon': Icons.attach_money
    };

    final clientBaseDb = {
      'name': 'Banco de Dados de Clientes',
      'lastUpdate': _clientBaseLastUpdate,
      'icon': Icons.people
    };

    final costBaseDb = {
      'name': 'Base de Custos',
      'lastUpdate': _costBaseLastUpdate,
      'icon': Icons.monetization_on
    };

    final databases = [priceBaseDb, clientBaseDb, costBaseDb];

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
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
                  db['icon'] as IconData,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                title: Text(
                  db['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Última atualização: ${db['lastUpdate']}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                trailing: ElevatedButton.icon(
                  icon: const Icon(Icons.sync),
                  label: const Text('Atualizar'),
                  onPressed: () {
                    if (db['name'] == 'Base de Preços') {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return const ImportCsvModal();
                        },
                      ).then((_) => _loadLastUpdate());
                    } else if (db['name'] == 'Banco de Dados de Clientes') {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return const ImportClientsCsvModal();
                        },
                      ).then((_) => _loadLastUpdate());
                    } else if (db['name'] == 'Base de Custos') {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return const ImportCostsCsvModal();
                        },
                      ).then((_) => _loadLastUpdate());
                    } else {
                      // TODO: Implementar lógica de atualização individual
                      print('Atualizando ${db['name']}...');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Atualizando ${db['name']}...'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
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