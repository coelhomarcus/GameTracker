import 'package:material_ui/material_ui.dart';

import '../../../core/design_system/game_cover.dart';
import '../../../core/design_system/status_chip.dart';
import '../../../core/design_system/tokens.dart';
import '../../library/data/library_fixtures.dart';

/// Página de jogo reconstruída pelo `igdbId` da rota (plano, seção 4.3).
class GamePage extends StatelessWidget {
  const GamePage({super.key, required this.igdbId});

  final int igdbId;

  @override
  Widget build(BuildContext context) {
    final entries = libraryFixtures.where((e) => e.igdbId == igdbId).toList();
    if (entries.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Jogo não encontrado.')),
      );
    }
    final name = entries.first.name;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: DefaultTabController(
        length: 3,
        child: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              pinned: true,
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              actions: [
                IconButton(
                  icon: const Icon(Icons.favorite_border),
                  tooltip: 'Favoritar',
                  onPressed: () {},
                ),
              ],
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Sobre'),
                  Tab(text: 'Meu progresso'),
                  Tab(text: 'Comunidade'),
                ],
              ),
            ),
          ],
          body: TabBarView(
            children: [
              ListView(
                padding: const EdgeInsets.all(Space.lg),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: Space.lg,
                    children: [
                      SizedBox(width: 120, child: GameCover(name: name)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: text.titleLarge),
                            const SizedBox(height: Space.sm),
                            const Text('PC · PlayStation 5'),
                            const SizedBox(height: Space.md),
                            FilledButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.add),
                              label: const Text('Novo playthrough'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.xl),
                  Text('Sinopse', style: text.titleMedium),
                  const SizedBox(height: Space.sm),
                  const Text(
                    'Sinopse de teste. Os dados reais chegam do backend na Etapa 4.',
                  ),
                ],
              ),
              ListView(
                padding: const EdgeInsets.all(Space.lg),
                children: [
                  for (final e in entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.md),
                      child: Card.filled(
                        child: ListTile(
                          title: Text(e.platform),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: Space.xs),
                            child: Wrap(
                              spacing: Space.sm,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                StatusChip(e.status),
                                if (e.hoursPlayed != null)
                                  Text(
                                    '${e.hoursPlayed!.toStringAsFixed(1).replaceAll('.', ',')} h',
                                  ),
                                if (e.rating != null)
                                  Text('Nota ${e.rating}/10'),
                              ],
                            ),
                          ),
                          trailing: const Icon(Icons.edit_outlined),
                        ),
                      ),
                    ),
                ],
              ),
              const Center(
                child: Text(
                  'Jogadores e posts da comunidade chegam na Etapa 5.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
