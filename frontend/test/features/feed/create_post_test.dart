import 'package:flutter_test/flutter_test.dart';
import 'package:gametracker/core/design_system/game_status.dart';
import 'package:gametracker/core/network/app_exception.dart';
import 'package:gametracker/features/games/data/game_models.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_feed.dart';
import '../../support/fake_repos.dart';
import '../../support/harness.dart';

Finder get textField =>
    find.widgetWithText(TextField, 'O que você quer compartilhar?');
Finder get publish => find.widgetWithText(FilledButton, 'Publicar');

Future<AppHarness> openComposer(
  WidgetTester tester, {
  String path = '/posts/new',
  FakeFeedRepository? feed,
  FakeLibraryRepository? library,
  FakeGamesRepository? games,
}) async {
  final h = AppHarness(feed: feed, library: library, games: games);
  await h.pump(tester);
  await goTo(tester, path);
  return h;
}

void main() {
  testWidgets('publicar desabilitado sem texto', (tester) async {
    await openComposer(tester);
    expect(tester.widget<FilledButton>(publish).onPressed, isNull);
    await tester.enterText(textField, '   ');
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(publish).onPressed,
      isNull,
      reason: 'só espaços não conta',
    );
    await tester.enterText(textField, 'oi');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(publish).onPressed, isNotNull);
  });

  testWidgets('publica texto sem vínculo e o post aparece no topo do Geral', (
    tester,
  ) async {
    final feed = FakeFeedRepository(
      general: [fakePost(id: 'old', content: 'post antigo')],
    );
    final h = AppHarness(feed: feed);
    await h.pump(tester);
    await tapAndSettle(tester, find.text('Comunidade').last);
    await tapAndSettle(
      tester,
      find.widgetWithText(FloatingActionButton, 'Publicar'),
    );

    await tester.enterText(textField, '  Meu primeiro post  ');
    await tester.pumpAndSettle();
    await tapAndSettle(tester, publish);

    expect(
      feed.created.single.content,
      'Meu primeiro post',
      reason: 'texto aparado',
    );
    expect(
      (feed.created.single.gameId, feed.created.single.gameEntryId),
      (null, null),
    );
    expect(
      find.text('Meu primeiro post'),
      findsOneWidget,
      reason: 'voltou ao feed com o novo post',
    );
    final newY = tester.getTopLeft(find.text('Meu primeiro post')).dy;
    final oldY = tester.getTopLeft(find.text('post antigo')).dy;
    expect(newY, lessThan(oldY), reason: 'no topo');
  });

  testWidgets('falha preserva o texto e os vínculos e permite tentar de novo', (
    tester,
  ) async {
    final feed = FakeFeedRepository()..createError = const NetworkException();
    await openComposer(tester, feed: feed);
    await tester.enterText(textField, 'Texto que não pode sumir');
    await tester.pumpAndSettle();
    await tapAndSettle(tester, publish);

    expect(find.textContaining('Sem conexão'), findsOneWidget);
    expect(find.text('Texto que não pode sumir'), findsOneWidget);
    expect(
      find.text('Nova publicação'),
      findsOneWidget,
      reason: 'continua no compositor',
    );
    expect(feed.created, isEmpty);

    feed.createError = null;
    await tapAndSettle(tester, publish);
    expect(feed.created.single.content, 'Texto que não pode sumir');
  });

  testWidgets('vincula um jogo pela busca e envia o UUID do jogo', (
    tester,
  ) async {
    final games =
        FakeGamesRepository(
            games: {
              900001: fakeGame(),
              55: fakeGame(igdbId: 55, name: 'Escolhido'),
            },
          )
          ..searchResult = const [
            GameSummary(
              igdbId: 55,
              name: 'Escolhido',
              platforms: ['PC'],
              genres: [],
            ),
          ];
    final feed = FakeFeedRepository();
    await openComposer(tester, feed: feed, games: games);

    await tapAndSettle(tester, find.text('Vincular um jogo'));
    await tester.enterText(
      find.descendant(
        of: find.byType(SearchBar),
        matching: find.byType(EditableText),
      ),
      'esco',
    );
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('Escolhido'));
    expect(find.widgetWithText(InputChip, 'Escolhido'), findsOneWidget);

    await tester.enterText(textField, 'Joguei isso');
    await tester.pumpAndSettle();
    await tapAndSettle(tester, publish);
    expect(
      feed.created.single.gameId,
      'g-55',
      reason: 'o backend vincula pelo UUID, não pelo igdbId',
    );
    expect(feed.created.single.gameEntryId, isNull);
  });

  testWidgets('remover o vínculo volta a publicar sem jogo', (tester) async {
    final entry = fakeEntry(id: 'e1');
    final feed = FakeFeedRepository();
    await openComposer(
      tester,
      path: '/posts/new?entryId=e1',
      feed: feed,
      library: FakeLibraryRepository([entry]),
    );
    expect(find.widgetWithText(InputChip, 'Jogo Fixture Um'), findsOneWidget);
    await tester.tap(find.byTooltip('Remover vínculo com o jogo'));
    await tester.pumpAndSettle();
    expect(find.text('Vincular um jogo'), findsOneWidget);

    await tester.enterText(textField, 'sem jogo');
    await tester.pumpAndSettle();
    await tapAndSettle(tester, publish);
    expect(
      (feed.created.single.gameId, feed.created.single.gameEntryId),
      (null, null),
    );
  });

  testWidgets(
    'com registro do jogo, escolhe qual playthrough e envia o registro',
    (tester) async {
      final library = FakeLibraryRepository([
        fakeEntry(id: 'a', platform: 'PC', status: GameStatus.completed),
        fakeEntry(
          id: 'b',
          platform: 'PlayStation 5',
          status: GameStatus.backlog,
        ),
      ]);
      final feed = FakeFeedRepository();
      await openComposer(
        tester,
        path: '/posts/new?entryId=a',
        feed: feed,
        library: library,
      );

      expect(find.text('Registro (opcional)'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'PC · Concluído'), findsOneWidget);
      expect(
        find.widgetWithText(ChoiceChip, 'PlayStation 5 · Na fila'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ChoiceChip>(
              find.widgetWithText(ChoiceChip, 'PC · Concluído'),
            )
            .selected,
        isTrue,
      );

      await tapAndSettle(
        tester,
        find.widgetWithText(ChoiceChip, 'PlayStation 5 · Na fila'),
      );
      await tester.enterText(textField, 'Sobre a versão de PS5');
      await tester.pumpAndSettle();
      await tapAndSettle(tester, publish);
      expect(feed.created.single.gameEntryId, 'b');
    },
  );

  testWidgets('sair com texto pede confirmação; sem texto, não', (
    tester,
  ) async {
    final h = AppHarness();
    await h.pump(tester);
    await tapAndSettle(tester, find.text('Comunidade').last);
    await tapAndSettle(
      tester,
      find.widgetWithText(FloatingActionButton, 'Publicar'),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Descartar publicação?'), findsNothing);
    expect(
      find.text('Nova publicação'),
      findsNothing,
      reason: 'voltou ao feed',
    );

    await tapAndSettle(
      tester,
      find.widgetWithText(FloatingActionButton, 'Publicar'),
    );
    await tester.enterText(textField, 'rascunho');
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Descartar publicação?'), findsOneWidget);

    await tapAndSettle(tester, find.text('Continuar editando'));
    expect(find.text('rascunho'), findsOneWidget, reason: 'texto preservado');
  });

  group('celebração ao concluir um jogo', () {
    testWidgets(
      'pelo menu de status: oferece publicar e abre o compositor já preenchido',
      (tester) async {
        final library = FakeLibraryRepository([
          fakeEntry(id: 'e1', status: GameStatus.playing),
        ]);
        final feed = FakeFeedRepository();
        final h = AppHarness(feed: feed, library: library);
        await h.pump(tester);

        await openLibraryGame(tester, 'Jogo Fixture Um');
        await tapAndSettle(
          tester,
          find.byTooltip('Ações do registro de Jogo Fixture Um'),
        );
        await tapAndSettle(tester, find.text('Alterar status'));
        await tapAndSettle(tester, find.widgetWithText(ListTile, 'Concluído'));

        expect(
          find.textContaining('Quer contar para a comunidade?'),
          findsOneWidget,
        );
        expect(feed.created, isEmpty, reason: 'a publicação é voluntária');

        await tapAndSettle(tester, find.text('Publicar'));
        expect(find.text('Nova publicação'), findsOneWidget);
        expect(
          tester.widget<TextField>(textField).controller!.text,
          'Zerei Jogo Fixture Um! 🎉',
        );
        expect(
          find.widgetWithText(InputChip, 'Jogo Fixture Um'),
          findsOneWidget,
          reason: 'registro vinculado',
        );

        await tapAndSettle(tester, publish);
        expect(feed.created.single.gameEntryId, 'e1');
        expect(feed.created.single.content, 'Zerei Jogo Fixture Um! 🎉');
      },
    );

    testWidgets('outros status não oferecem publicar', (tester) async {
      final library = FakeLibraryRepository([
        fakeEntry(id: 'e1', status: GameStatus.backlog),
      ]);
      await AppHarness(library: library).pump(tester);
      await openLibraryGame(tester, 'Jogo Fixture Um');
      await tapAndSettle(
        tester,
        find.byTooltip('Ações do registro de Jogo Fixture Um'),
      );
      await tapAndSettle(tester, find.text('Alterar status'));
      await tapAndSettle(tester, find.widgetWithText(ListTile, 'Jogando'));
      expect(find.textContaining('Quer contar'), findsNothing);
    });

    testWidgets('falha ao concluir não oferece publicar', (tester) async {
      final library = FakeLibraryRepository([
        fakeEntry(id: 'e1', status: GameStatus.playing),
      ])..mutationError = const NetworkException();
      await AppHarness(library: library).pump(tester);
      await openLibraryGame(tester, 'Jogo Fixture Um');
      await tapAndSettle(
        tester,
        find.byTooltip('Ações do registro de Jogo Fixture Um'),
      );
      await tapAndSettle(tester, find.text('Alterar status'));
      await tapAndSettle(tester, find.widgetWithText(ListTile, 'Concluído'));
      expect(find.textContaining('Quer contar'), findsNothing);
      expect(find.textContaining('Sem conexão'), findsOneWidget);
    });

    testWidgets(
      'pelo formulário: só quando passa a concluído (não ao editar um já concluído)',
      (tester) async {
        final library = FakeLibraryRepository([
          fakeEntry(id: 'e1', status: GameStatus.playing),
          fakeEntry(id: 'e2', status: GameStatus.completed),
        ]);
        final h = AppHarness(library: library);
        await h.pump(tester);
        await goTo(tester, '/games/900001');
        GoRouter.of(tester.element(find.byType(Scaffold).first))
            .push('/games/900001/playthroughs/e1/edit');
        await tester.pumpAndSettle();
        await tapAndSettle(
          tester,
          find.widgetWithText(ChoiceChip, 'Concluído'),
        );
        await tapAndSettle(
          tester,
          find.widgetWithText(FilledButton, 'Salvar registro'),
        );
        expect(
          find.textContaining('Quer contar para a comunidade?'),
          findsOneWidget,
        );

        ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
            .clearSnackBars();
        await tester.pumpAndSettle();
        GoRouter.of(tester.element(find.byType(Scaffold).first))
            .push('/games/900001/playthroughs/e2/edit');
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Horas jogadas'),
          '9',
        );
        await tester.pumpAndSettle();
        await tapAndSettle(
          tester,
          find.widgetWithText(FilledButton, 'Salvar registro'),
        );
        expect(
          find.textContaining('Quer contar'),
          findsNothing,
          reason: 'já estava concluído',
        );
        expect(find.text('Registro atualizado'), findsOneWidget);
      },
    );

    testWidgets('criando já como concluído também oferece', (tester) async {
      final h = AppHarness();
      await h.pump(tester);
      await goTo(tester, '/games/900001/playthroughs/new');
      await tapAndSettle(tester, find.widgetWithText(ChoiceChip, 'Concluído'));
      await tapAndSettle(
        tester,
        find.widgetWithText(FilledButton, 'Salvar registro'),
      );
      expect(
        find.textContaining('Quer contar para a comunidade?'),
        findsOneWidget,
      );
    });
  });

  testWidgets('layout a 360 px e texto 200% não estoura', (tester) async {
    final h = AppHarness(library: FakeLibraryRepository([fakeEntry(id: 'e1')]));
    await h.pump(tester, size: const Size(360, 800), textScale: 2.0);
    await goTo(tester, '/posts/new?entryId=e1');
    expect(tester.takeException(), isNull);
  });
}
