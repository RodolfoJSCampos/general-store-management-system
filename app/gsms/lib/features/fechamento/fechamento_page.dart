import 'package:flutter/material.dart';

class FechamentoPage extends StatelessWidget {
  const FechamentoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fechamento'),
      ),
      body: const Center(
        child: Text('Página de Fechamento'),
      ),
    );
  }
}
