import 'package:flutter/material.dart';
import 'package:gsms/app/theme_notifier.dart';
import 'package:gsms/common/routes/app_routes.dart';
import 'package:gsms/common/widgets/feature_button.dart';
import 'package:gsms/features/home/widgets/update_data_modal.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão de Materiais de Construção'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (String result) {
              // Lógica para 'Conta' e 'Sair'
              switch (result) {
                case 'atualizar_dados':
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return const UpdateDataModal();
                    },
                  );
                  break;
                case 'conta':
                  // TODO: Implementar navegação para a página da conta
                  print('Página de conta selecionada.');
                  break;
                case 'sair':
                  // TODO: Implementar lógica de logout
                  print('Sair selecionado.');
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'tema',
                mouseCursor: SystemMouseCursors.click,
                child: Consumer<ThemeNotifier>(
                  builder: (context, themeNotifier, child) {
                    final isDarkMode =
                        themeNotifier.themeMode == ThemeMode.dark;
                    return SwitchListTile(
                      title: Text(isDarkMode ? 'Dark' : 'Light'),
                      secondary: Icon(isDarkMode
                          ? Icons.dark_mode
                          : Icons.light_mode),
                      value: isDarkMode,
                      onChanged: (bool value) {
                        themeNotifier.setThemeMode(
                            value ? ThemeMode.dark : ThemeMode.light);
                        Navigator.pop(
                            context); // Fecha o menu ao alterar o tema
                      },
                    );
                  },
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'atualizar_dados',
                mouseCursor: SystemMouseCursors.click,
                child: const ListTile(
                  leading: Icon(Icons.sync),
                  title: Text('Atualizar Dados'),
                  mouseCursor: SystemMouseCursors.click,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'conta',
                mouseCursor: SystemMouseCursors.click,
                child: const ListTile(
                  leading: Icon(Icons.person_outline),
                  title: Text('Conta'),
                  mouseCursor: SystemMouseCursors.click,
                ),
              ),
              PopupMenuItem<String>(
                value: 'sair',
                mouseCursor: SystemMouseCursors.click,
                child: const ListTile(
                  leading: Icon(Icons.exit_to_app),
                  title: Text('Sair'),
                  mouseCursor: SystemMouseCursors.click,
                ),
              ),
            ],
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          const int itemCount = 6;
          const double padding = 16;
          final double screenWidth = constraints.maxWidth;
          final double screenHeight = constraints.maxHeight;

          int crossAxisCount;
          double childAspectRatio;

          if (screenWidth < screenHeight) {
            // Portrait or square
            crossAxisCount = 2;
            double itemWidth =
                (screenWidth - (crossAxisCount + 1) * padding) / crossAxisCount;
            childAspectRatio = itemWidth / itemWidth;
          } else {
            // Landscape
            crossAxisCount = 3;
            double itemWidth =
                (screenWidth - (crossAxisCount + 1) * padding) / crossAxisCount;
            double itemHeight = (screenHeight - 3 * padding) / 2;
            childAspectRatio = itemWidth / itemHeight;
          }

          final List<Widget> featureButtons = [
            const FeatureButton(
              title: 'Fazer Orçamento',
              icon: Icons.calculate,
              routeName: AppRoutes.fazerOrcamento,
            ),
            const FeatureButton(
              title: 'Cadastrar Venda',
              icon: Icons.add_shopping_cart,
              routeName: AppRoutes.cadastrarVenda,
            ),
            const FeatureButton(
              title: 'Expedição',
              icon: Icons.local_shipping,
              routeName: AppRoutes.expedicao,
            ),
            const FeatureButton(
              title: 'Reposição',
              icon: Icons.inventory,
              routeName: AppRoutes.reposicao,
            ),
            const FeatureButton(
              title: 'Fechamento',
              icon: Icons.point_of_sale,
              routeName: AppRoutes.fechamento,
            ),
            const FeatureButton(
              title: 'Acerto de Contas',
              icon: Icons.request_quote,
              routeName: AppRoutes.acertoContas,
            ),
          ];

          return GridView.builder(
            padding: const EdgeInsets.all(padding),
            itemCount: itemCount,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: padding,
              mainAxisSpacing: padding,
              childAspectRatio: childAspectRatio,
            ),
            itemBuilder: (context, index) {
              return featureButtons[index];
            },
          );
        },
      ),
    );
  }
}
