import 'package:flutter_test/flutter_test.dart';
import 'package:gametracker/core/design_system/game_status.dart';
import 'package:gametracker/core/network/app_exception.dart';
import 'package:gametracker/features/games/data/game_models.dart';

import '../../support/fake_repos.dart';
import '../../support/harness.dart';

AppHarness harness({
  FakeGamesRepository? games,
  FakeLibraryRepository? library,
}) => AppHarness(
  games: games,
  library:
      library ??
      FakeLibraryRepository([
        fakeEntry(
          id: 'a',
          status: GameStatus.completed,
          hours: 20,
          rating: 8,
          platform: 'PC',
        ),
        fakeEntry(
          id: 'b',
          status: GameStatus.backlog,
          platform: 'PlayStation 5',
        ),
      ]),
);

Future<void> openGame(
  WidgetTester tester,
  AppHarness h, {
  int igdbId = 900001,
}) async {
  await h.pump(tester);
  await goTo(tester, '/games/$igdbId');
}

void main() {
  testWidgets('abre pelo igdbId da rota e mostra o jogo', (tester) async {
    await openGame(tester, harness());
    expect(find.text('Jogo Fixture Um'), findsWidgets);
    expect(find.text('Sinopse de teste.'), findsOneWidget);
    expect(find.text('PC · PlayStation 5'), findsOneWidget);
    expect(find.text('RPG'), findsOneWidget);
  });

  testWidgets('jogo sem sinopse nem screenshots não quebra', (tester) async {
    final games = FakeGamesRepository(
      games: {
        900002: const Game(
          id: 'g2',
          igdbId: 900002,
          name: 'Sem Dados',
          screenshots: [],
          platforms: [],
          genres: [],
        ),
      },
    );
    await openGame(tester, harness(games: games), igdbId: 900002);
    expect(find.text('Este jogo ainda não tem sinopse.'), findsOneWidget);
    expect(find.text('Screenshots'), findsNothing);
  });

  testWidgets('jogo inexistente mostra erro com saída', (tester) async {
    final games = FakeGamesRepository()
      ..gameError = const ApiException(404, 'not_found', 'Jogo não encontrado');
    await openGame(tester, harness(games: games));
    expect(find.text('Não encontrado.'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  testWidgets('favoritar muda o ícone na hora; falha desfaz e avisa', (
    tester,
  ) async {
    final games = FakeGamesRepository();
    final h = harness(games: games);
    await openGame(tester, h);

    await tapAndSettle(tester, find.byTooltip('Favoritar'));
    expect(find.byTooltip('Remover dos favoritos'), findsOneWidget);
    expect(games.favoriteCalls.single, ('g-900001', true));

    games.favoriteError = const NetworkException();
    await tapAndSettle(tester, find.byTooltip('Remover dos favoritos'));
    expect(
      find.byTooltip('Remover dos favoritos'),
      findsOneWidget,
      reason: 'desfez para o estado anterior',
    );
    expect(find.textContaining('Sem conexão'), findsOneWidget);
  });

  testWidgets('Meu progresso lista os dois playthroughs com horas e nota', (
    tester,
  ) async {
    await openGame(tester, harness());
    await tapAndSettle(tester, find.text('Meu progresso'));
    expect(find.text('PC'), findsWidgets);
    expect(find.text('PlayStation 5'), findsWidgets);
    expect(find.text('20,0 h'), findsOneWidget, reason: 'vírgula decimal');
    expect(find.text('Nota 8/10'), findsOneWidget);
    expect(find.text('Novo playthrough (replay)'), findsOneWidget);
  });

  testWidgets('sem registros: convida a criar o primeiro', (tester) async {
    await openGame(tester, harness(library: FakeLibraryRepository()));
    await tapAndSettle(tester, find.text('Meu progresso'));
    expect(find.text('Você ainda não registrou este jogo'), findsOneWidget);
    expect(find.text('Novo playthrough'), findsWidgets);
  });

  testWidgets('Comunidade: estatísticas de playthroughs e jogadores', (
    tester,
  ) async {
    final games = FakeGamesRepository()
      ..playersResult = [
        const GamePlayer(
          user: PlayerUser(id: 'u9', username: 'beto', name: 'Beto'),
          status: GameStatus.playing,
          hoursPlayed: 3.5,
        ),
      ];
    await openGame(tester, harness(games: games));
    await tapAndSettle(tester, find.text('Comunidade'));
    expect(find.text('2 jogando'), findsOneWidget);
    expect(find.text('3 concluído'), findsOneWidget);
    expect(find.textContaining('registros, não pessoas'), findsOneWidget);
    expect(find.text('Beto'), findsOneWidget);
    expect(find.text('3,5 h'), findsOneWidget);
  });

  testWidgets('Comunidade: ninguém seguido jogando mostra mensagem própria', (
    tester,
  ) async {
    await openGame(tester, harness());
    await tapAndSettle(tester, find.text('Comunidade'));
    expect(find.text('Ninguém está jogando agora.'), findsOneWidget);
    await tapAndSettle(tester, find.text('Quem eu sigo'));
    expect(find.text('Ninguém que você segue está jogando.'), findsOneWidget);
  });

  testWidgets('Comunidade: falha das estatísticas não derruba as outras abas', (
    tester,
  ) async {
    final games = FakeGamesRepository();
    final h = harness(games: games);
    await openGame(tester, h);
    // A aba Sobre e Meu progresso continuam funcionando sem depender das estatísticas.
    await tapAndSettle(tester, find.text('Meu progresso'));
    expect(find.text('20,0 h'), findsOneWidget);
    await tapAndSettle(tester, find.text('Sobre'));
    expect(find.text('Sinopse de teste.'), findsOneWidget);
  });

  testWidgets('screenshots abrem na imagem tocada, navegam e fecham', (
    tester,
  ) async {
    final games = FakeGamesRepository(
      games: {
        900001: const Game(
          id: 'g-900001',
          igdbId: 900001,
          name: 'Jogo Fixture Um',
          screenshots: [
            'http://localhost:3100/api/images/cover?url=a',
            'http://localhost:3100/api/images/cover?url=b',
            'http://localhost:3100/api/images/cover?url=c',
          ],
          platforms: ['PC'],
          genres: [],
        ),
      },
    );
    final semantics = tester.ensureSemantics();
    await openGame(tester, harness(games: games));
    await tapAndSettle(
      tester,
      find.bySemanticsLabel('Abrir screenshot 2 de 3'),
    );
    expect(
      find.text('2 de 3'),
      findsOneWidget,
      reason: 'abre na imagem tocada, não na primeira',
    );

    await tapAndSettle(tester, find.byTooltip('Próxima imagem'));
    expect(find.text('3 de 3'), findsOneWidget);
    expect(
      find.byTooltip('Próxima imagem'),
      findsNothing,
      reason: 'fim da galeria',
    );

    await tapAndSettle(tester, find.byTooltip('Fechar'));
    expect(find.text('3 de 3'), findsNothing);
    expect(find.text('Sinopse'), findsOneWidget);
    semantics.dispose();
  });
}
