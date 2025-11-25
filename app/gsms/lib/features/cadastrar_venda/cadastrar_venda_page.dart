import 'package:flutter/material.dart';
import 'package:gsms/features/home/domain/models/price_base_model.dart';
import 'package:hive_flutter/hive_flutter.dart';

class CadastrarVendaPage extends StatelessWidget {
  const CadastrarVendaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastrar Venda (Base de Preços)'),
      ),
      body: ValueListenableBuilder<Box<PriceBaseModel>>(
        valueListenable: Hive.box<PriceBaseModel>('price_base').listenable(),
        builder: (context, box, _) {
          final items = box.values.toList().cast<PriceBaseModel>();
          final keys = box.keys.toList();

          if (items.isEmpty) {
            return const Center(
              child: Text('A base de dados de preços está vazia.'),
            );
          }

          Widget buildRichText(String key, String value) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium,
                  children: <TextSpan>[
                    TextSpan(
                        text: key,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: value),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final key = keys[index];
              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildRichText('Hive Key: ', key.toString()),
                      const Divider(height: 20),
                      buildRichText('Código: ', item.code),
                      buildRichText('Descrição: ', item.description),
                      buildRichText('Marca: ', item.brand),
                      buildRichText('Preço a Vista: ',
                          'R\$ ${item.cashPrice.toStringAsFixed(2)}'),
                      buildRichText('Preço a Prazo: ',
                          'R\$ ${item.installmentPrice.toStringAsFixed(2)}'),
                      buildRichText('Preço 10X: ',
                          'R\$ ${item.tenTimesPrice.toStringAsFixed(2)}'),
                      buildRichText('Preço Mínimo: ',
                          'R\$ ${item.minimumPrice.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
