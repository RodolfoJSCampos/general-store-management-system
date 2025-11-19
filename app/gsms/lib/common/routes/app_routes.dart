import 'package:flutter/material.dart';
import 'package:gsms/features/fazer_orcamento/fazer_orcamento_page.dart';
import 'package:gsms/features/home/home_page.dart';
import 'package:gsms/features/cadastrar_venda/cadastrar_venda_page.dart';
import 'package:gsms/features/expedicao/expedicao_page.dart';
import 'package:gsms/features/reposicao/reposicao_page.dart';
import 'package:gsms/features/fechamento/fechamento_page.dart';
import 'package:gsms/features/acerto_contas/acerto_contas_page.dart';

class AppRoutes {
  static const String home = '/';
  static const String fazerOrcamento = '/fazer_orcamento';
  static const String cadastrarVenda = '/cadastrar_venda';
  static const String expedicao = '/expedicao';
  static const String reposicao = '/reposicao';
  static const String fechamento = '/fechamento';
  static const String acertoContas = '/acerto_contas';

  static Map<String, WidgetBuilder> get routes {
    return {
      home: (context) => const HomePage(),
      fazerOrcamento: (context) => const FazerOrcamentoPage(),
      cadastrarVenda: (context) => const CadastrarVendaPage(),
      expedicao: (context) => const ExpedicaoPage(),
      reposicao: (context) => const ReposicaoPage(),
      fechamento: (context) => const FechamentoPage(),
      acertoContas: (context) => const AcertoContasPage(),
    };
  }
}
