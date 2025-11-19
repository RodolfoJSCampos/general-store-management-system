import 'package:flutter/material.dart';
import 'package:gsms/app/theme_notifier.dart';
import 'package:gsms/common/routes/app_routes.dart';
import 'package:gsms/common/widgets/feature_button.dart';
import 'package:provider/provider.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão de Materiais de Construção'),
        actions: [
          PopupMenuButton<ThemeMode>(
            onSelected: (ThemeMode mode) {
              Provider.of<ThemeNotifier>(context, listen: false)
                  .setThemeMode(mode);
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<ThemeMode>>[
              const PopupMenuItem<ThemeMode>(
                value: ThemeMode.light,
                child: Text('Light Mode'),
              ),
              const PopupMenuItem<ThemeMode>(
                value: ThemeMode.dark,
                child: Text('Dark Mode'),
              ),
              const PopupMenuItem<ThemeMode>(
                value: ThemeMode.system,
                child: Text('System Default'),
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
