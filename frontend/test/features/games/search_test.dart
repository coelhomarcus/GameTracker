import 'package:flutter_test/flutter_test.dart';
import 'package:gametracker/core/network/app_exception.dart';
import 'package:gametracker/features/games/application/game_providers.dart';
import 'package:gametracker/features/games/data/game_models.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_repos.dart';
import '../../support/harness.dart';

const _zelda = GameSummary(
  igdbId: 900001,
  name: 'Zelda Fixture',
  platforms: ['Switch', 'Wii U'],
  genres: [],
);

Future<void> typeQuery(WidgetTester tester, String text) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(SearchBar),
      matching: find.byType(EditableText),
    ),
    text,
  );
  await tester.pump(searchDebounce + const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

Future<AppHarness> openExplore(
  WidgetTester tester, {
  FakeGamesRepository? games,
}) async {
  final h = AppHarness(
    games: games ?? (FakeGamesRepository()..searchResult = [_zelda]),
  );
  await h.pump(tester);
  await tapAndSettle(tester, find.text('Explorar').last);
  return h;
}

void main() {
  testWidgets('sem termo mostra a dica e não consulta o servidor', (
    tester,
  ) async {
    final h = await openExplore(tester);
    expect(find.text('Busque um jogo pelo nome'), findsOneWidget);
    await typeQuery(tester, 'z');
    expect(find.text('Busque um jogo pelo nome'), findsOneWidget);
    expect(h.games.searches, isEmpty);
  });

  testWidgets('mostra resultados depois do debounce', (tester) async {
    final h = await openExplore(tester);
    await typeQuery(tester, 'zelda');
    expect(h.games.searches, ['zelda']);
    expect(find.text('Zelda Fixture'), findsOneWidget);
    expect(find.text('Switch · Wii U'), findsOneWidget);
  });

  testWidgets('nenhum resultado é diferente de erro', (tester) async {
    final games = FakeGamesRepository()..searchResult = const [];
    await openExplore(tester, games: games);
    await typeQuery(tester, 'xyz');
    expect(find.text('Nenhum jogo encontrado'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsNothing);
  });

  testWidgets(
    'IGDB não configurada mostra erro explicativo com nova tentativa',
    (tester) async {
      final games = FakeGamesRepository()
        ..searchError = const ApiException(503, 'igdb_not_configured', 'x');
      await openExplore(tester, games: games);
      await typeQuery(tester, 'zelda');
      expect(find.textContaining('ainda não está configurada'), findsOneWidget);
      expect(find.text('Nenhum jogo encontrado'), findsNothing);

      games
        ..searchError = null
        ..searchResult = [_zelda];
      await tapAndSettle(tester, find.text('Tentar de novo'));
      await tester.pump(searchDebounce + const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(find.text('Zelda Fixture'), findsOneWidget);
    },
  );

  testWidgets('tocar no resultado abre a página do jogo', (tester) async {
    await openExplore(tester);
    await typeQuery(tester, 'zelda');
    await tapAndSettle(tester, find.text('Zelda Fixture'));
    expect(find.text('Meu progresso'), findsOneWidget);
  });

  testWidgets('botão adicionar abre o formulário de novo playthrough', (
    tester,
  ) async {
    await openExplore(tester);
    await typeQuery(tester, 'zelda');
    await tapAndSettle(
      tester,
      find.byTooltip('Adicionar Zelda Fixture à biblioteca'),
    );
    expect(find.text('Novo playthrough'), findsWidgets);
    expect(find.text('Plataforma'), findsOneWidget);
  });

  testWidgets('limpar a busca volta à dica', (tester) async {
    await openExplore(tester);
    await typeQuery(tester, 'zelda');
    await tapAndSettle(tester, find.byTooltip('Limpar busca'));
    expect(find.text('Busque um jogo pelo nome'), findsOneWidget);
  });

  testWidgets('seletor de jogo da Biblioteca leva ao formulário', (
    tester,
  ) async {
    final h = AppHarness(games: FakeGamesRepository()..searchResult = [_zelda]);
    await h.pump(tester);
    await tapAndSettle(
      tester,
      find.widgetWithText(FloatingActionButton, 'Adicionar jogo'),
    );
    await typeQuery(tester, 'zelda');
    await tapAndSettle(tester, find.text('Zelda Fixture'));
    expect(find.text('Novo playthrough'), findsWidgets);
  });
}
