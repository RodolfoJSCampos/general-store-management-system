import 'package:flutter/material.dart';

class CadastrarVendaPage extends StatelessWidget {
  const CadastrarVendaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastrar Venda'),
      ),
      body: const Center(
        child: Text('Página de Cadastro de Venda'),
      ),
    );
  }
}
