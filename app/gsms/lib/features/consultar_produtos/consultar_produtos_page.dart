import 'package:flutter/material.dart';

class ConsultarProdutosPage extends StatelessWidget {
  const ConsultarProdutosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultar Produtos'),
      ),
      body: const Center(
        child: Text('Página de Consulta de Produtos'),
      ),
    );
  }
}
