import 'package:flutter_test/flutter_test.dart';
import 'package:gametracker/core/design_system/game_status.dart';
import 'package:gametracker/core/network/app_exception.dart';
import 'package:gametracker/features/library/presentation/entry_actions.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_repos.dart';
import '../../support/harness.dart';

Future<void> openMenu(WidgetTester tester, int index, String item) async {
  await tapAndSettle(tester, find.byType(EntryMenuButton).at(index));
  await tapAndSettle(tester, find.text(item).last);
}

void main() {
  testWidgets('estado de carregamento e depois a coleção', (tester) async {
    final h = AppHarness(library: FakeLibraryRepository([fakeEntry()]));
    await h.pump(tester);
    expect(find.text('Jogo Fixture Um'), findsWidgets);
    expect(find.text('1 registro · 0 concluídos'), findsOneWidget);
  });

  testWidgets('coleção vazia oferece adicionar jogo', (tester) async {
    await AppHarness().pump(tester);
    expect(find.text('Sua biblioteca está vazia'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Adicionar jogo'), findsOneWidget);
  });

  testWidgets('erro de rede mostra mensagem e "Tentar de novo" recarrega', (
    tester,
  ) async {
    final library = FakeLibraryRepository([fakeEntry()])
      ..listError = const NetworkException();
    await AppHarness(library: library).pump(tester);
    expect(find.textContaining('Sem conexão'), findsOneWidget);
    expect(
      find.text('Sua biblioteca está vazia'),
      findsNothing,
      reason: 'erro não é vazio',
    );

    library.listError = null;
    await tapAndSettle(tester, find.text('Tentar de novo'));
    expect(find.text('Jogo Fixture Um'), findsWidgets);
  });

  testWidgets('dois playthroughs do mesmo jogo aparecem como dois registros', (
    tester,
  ) async {
    final library = FakeLibraryRepository([
      fakeEntry(id: 'a', status: GameStatus.completed, platform: 'PC'),
      fakeEntry(id: 'b', status: GameStatus.backlog, platform: 'PC'),
    ]);
    await AppHarness(library: library).pump(tester);
    expect(
      find.byType(EntryMenuButton),
      findsNWidgets(2),
      reason: 'um card por registro',
    );
    expect(find.text('2 registros · 1 concluído'), findsOneWidget);
  });

  testWidgets('filtros mostram contagem e filtram; tocar de novo limpa', (
    tester,
  ) async {
    final library = FakeLibraryRepository([
      fakeEntry(id: 'a', status: GameStatus.completed),
      fakeEntry(
        id: 'b',
        game: fakeGame(igdbId: 2, name: 'Segundo'),
        status: GameStatus.playing,
      ),
    ]);
    await AppHarness(library: library).pump(tester);
    expect(find.text('Todos (2)'), findsOneWidget);
    expect(find.text('Abandonado (0)'), findsOneWidget);

    await tapAndSettle(
      tester,
      find.widgetWithText(FilterChip, 'Concluído (1)'),
    );
    expect(find.text('Jogo Fixture Um'), findsWidgets);
    expect(find.text('Segundo'), findsNothing);

    await tapAndSettle(
      tester,
      find.widgetWithText(FilterChip, 'Abandonado (0)'),
    );
    expect(find.text('Nenhum registro neste status'), findsOneWidget);

    await tapAndSettle(
      tester,
      find.widgetWithText(FilterChip, 'Abandonado (0)'),
    );
    expect(find.text('Segundo'), findsWidgets);
  });

  testWidgets('lista/grade e ordenação persistem entre aberturas do app', (
    tester,
  ) async {
    final library = FakeLibraryRepository([
      fakeEntry(id: 'a', hours: 5, createdAt: DateTime.utc(2026, 1, 1)),
      fakeEntry(
        id: 'b',
        game: fakeGame(igdbId: 2, name: 'Segundo'),
        hours: 50,
        createdAt: DateTime.utc(2026, 2, 1),
      ),
    ]);
    await AppHarness(library: library).pump(
      tester,
      prefs: {'library.grid': false, 'library.sort': 'most_played'},
    );
    // Lista (não grade): cada registro é um ListTile, e "Segundo" (50 h) vem primeiro.
    expect(find.byType(ListTile), findsNWidgets(2));
    final firstTitle = tester.widget<Text>(
      find
          .descendant(
            of: find.byType(ListTile).first,
            matching: find.byType(Text),
          )
          .first,
    );
    expect(firstTitle.data, 'Segundo');
  });

  testWidgets('alternar grade/lista grava a preferência', (tester) async {
    await AppHarness(library: FakeLibraryRepository([fakeEntry()]))
        .pump(tester);
    expect(find.byType(ListTile), findsNothing);
    await tapAndSettle(tester, find.byTooltip('Mostrar como lista'));
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.byTooltip('Mostrar como grade'), findsOneWidget);
  });

  testWidgets(
    'alterar status pelo menu envia só essa mudança e atualiza a tela',
    (tester) async {
      final library = FakeLibraryRepository([
        fakeEntry(id: 'a', status: GameStatus.backlog, hours: 3),
      ]);
      await AppHarness(library: library).pump(tester);

      await openMenu(tester, 0, 'Alterar status');
      await tapAndSettle(tester, find.widgetWithText(ListTile, 'Concluído'));

      expect(library.updated.single.$1, 'a');
      expect(library.updated.single.$2.status, GameStatus.completed);
      expect(
        library.updated.single.$2.hoursPlayed,
        3,
        reason: 'o resto do registro é preservado',
      );
      expect(find.text('1 registro · 1 concluído'), findsOneWidget);
    },
  );

  testWidgets('remover pede confirmação, remove só o registro escolhido', (
    tester,
  ) async {
    final library = FakeLibraryRepository([
      fakeEntry(id: 'a'),
      fakeEntry(id: 'b'),
    ]);
    await AppHarness(library: library).pump(tester);

    await openMenu(tester, 0, 'Remover');
    expect(find.text('Remover registro?'), findsOneWidget);
    await tapAndSettle(tester, find.widgetWithText(TextButton, 'Cancelar'));
    expect(library.deleted, isEmpty);

    await openMenu(tester, 0, 'Remover');
    await tapAndSettle(tester, find.widgetWithText(FilledButton, 'Remover'));
    expect(library.deleted.length, 1);
    expect(
      find.text('1 registro · 0 concluídos'),
      findsOneWidget,
      reason: 'o outro playthrough continua',
    );
  });

  testWidgets('falha ao remover mantém o registro e avisa', (tester) async {
    final library = FakeLibraryRepository([fakeEntry(id: 'a')])
      ..mutationError = const NetworkException();
    await AppHarness(library: library).pump(tester);
    await openMenu(tester, 0, 'Remover');
    await tapAndSettle(tester, find.widgetWithText(FilledButton, 'Remover'));
    expect(find.textContaining('Sem conexão'), findsOneWidget);
    expect(find.text('1 registro · 0 concluídos'), findsOneWidget);
  });

  testWidgets('muitos registros a 360 px e texto 200% não estouram o layout', (
    tester,
  ) async {
    final entries = [
      for (var i = 0; i < 12; i++)
        fakeEntry(
          id: 'e$i',
          game: fakeGame(
            igdbId: i,
            name: 'Um jogo com nome extremamente comprido número $i',
          ),
          status: GameStatus.values[i % 4],
          platform: 'PlayStation 5',
        ),
    ];
    await AppHarness(library: FakeLibraryRepository(entries))
        .pump(tester, size: const Size(360, 800), textScale: 2.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('puxar para atualizar refaz a consulta', (tester) async {
    final library = FakeLibraryRepository([fakeEntry()]);
    await AppHarness(library: library).pump(tester);
    expect(library.listCalls, 1);
    await tester.fling(
      find.byType(Scrollable).last,
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();
    expect(library.listCalls, 2);
  });

  testWidgets(
    'falha ao atualizar mantém a lista e avisa que está desatualizada',
    (tester) async {
      final library = FakeLibraryRepository([fakeEntry()]);
      await AppHarness(library: library).pump(tester);

      library.listError = const NetworkException();
      await tester.fling(
        find.byType(Scrollable).last,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Jogo Fixture Um'),
        findsWidgets,
        reason: 'a lista continua na tela',
      );
      expect(find.textContaining('Mostrando os dados salvos'), findsOneWidget);
      expect(find.text('Sua biblioteca está vazia'), findsNothing);

      library.listError = null;
      await tapAndSettle(tester, find.text('Tentar de novo'));
      expect(find.textContaining('Mostrando os dados salvos'), findsNothing);
      expect(find.text('Jogo Fixture Um'), findsWidgets);
    },
  );

  testWidgets('a coleção não aparece de outra conta depois de sair', (
    tester,
  ) async {
    final h = AppHarness(library: FakeLibraryRepository([fakeEntry()]));
    await h.pump(tester);
    expect(find.text('Jogo Fixture Um'), findsWidgets);
    await tapAndSettle(tester, find.text('Perfil').last);
    await tapAndSettle(tester, find.text('Sair'));
    expect(find.text('Jogo Fixture Um'), findsNothing);
    expect(find.text('Entrar'), findsWidgets);
  });
}
