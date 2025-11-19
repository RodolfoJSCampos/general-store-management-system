import 'package:flutter/material.dart';

class ReposicaoPage extends StatelessWidget {
  const ReposicaoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reposição'),
      ),
      body: const Center(
        child: Text('Página de Reposição'),
      ),
    );
  }
}
