import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../games/presentation/game_search_view.dart';
import '../../profiles/presentation/people_search_view.dart';

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
            const PeopleSearchView(),
          ],
        ),
      ),
    );
  }
}
