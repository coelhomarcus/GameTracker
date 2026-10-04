import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/design_system/placeholder_page.dart';
import '../../games/presentation/game_search_view.dart';

class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Explorar'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Jogos'),
              Tab(text: 'Pessoas'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            GameSearchView(
              onOpen: (game) => context.push('/games/${game.igdbId}'),
              onAdd: (game) =>
                  context.push('/games/${game.igdbId}/playthroughs/new'),
            ),
            const PlaceholderBody(
              icon: Icons.group_outlined,
              message: 'Busca de pessoas chega na Etapa 6.',
            ),
          ],
        ),
      ),
    );
  }
}
