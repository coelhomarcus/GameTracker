import 'package:material_ui/material_ui.dart';

import '../../../core/design_system/placeholder_page.dart';

class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderPage(
    title: 'Explorar',
    icon: Icons.search,
    message: 'Busca de jogos e pessoas chega na Etapa 4.',
  );
}
