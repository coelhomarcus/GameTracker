import 'package:flutter_test/flutter_test.dart';
import 'package:gametracker/core/dates/date_only.dart';
import 'package:gametracker/core/design_system/game_card.dart';
import 'package:gametracker/core/design_system/game_status.dart';
import 'package:gametracker/core/network/app_exception.dart';
import 'package:gametracker/features/library/data/game_entry.dart';
import 'package:gametracker/features/library/presentation/entry_actions.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_repos.dart';
import '../../support/golden.dart';
import '../../support/harness.dart';

/// Abre o jogo na Biblioteca e usa o menu de um registro específico ("Meu progresso").
Future<void> openMenu(WidgetTester tester, int index, String item) async {
  await openLibraryGame(tester, 'Jogo Fixture Um');
  await tapAndSettle(tester, find.byType(EntryMenuButton).at(index));
  await tapAndSettle(tester, find.text(item).last);
}

String location(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first)).state.uri.path;

Finder get searchField =>
    find.widgetWithText(TextField, 'Buscar na biblioteca');

Future<void> search(WidgetTester tester, String text) async {
  await tester.enterText(searchField, text);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('estado de carregamento e depois a coleção', (tester) async {
    final h = AppHarness(library: FakeLibraryRepository([fakeEntry()]));
    await h.pump(tester);
    expect(find.text('Jogo Fixture Um'), findsWidgets);
    expect(find.text('1 jogo · 1 registro'), findsOneWidget);
  });

  testWidgets('coleção vazia convida a encontrar um jogo', (tester) async {
    await AppHarness().pump(tester);
    expect(find.text('Sua biblioteca começa com um jogo'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Encontrar jogo'), findsOneWidget);
    expect(
      find.widgetWithText(FloatingActionButton, 'Adicionar jogo'),
      findsOneWidget,
    );

    await tapAndSettle(
      tester,
      find.widgetWithText(FilledButton, 'Encontrar jogo'),
    );
    expect(location(tester), '/explore');
  });

  testWidgets('erro de rede mostra mensagem e "Tentar de novo" recarrega', (
    tester,
  ) async {
    final library = FakeLibraryRepository([fakeEntry()])
      ..listError = const NetworkException();
    await AppHarness(library: library).pump(tester);
    expect(find.textContaining('Sem conexão'), findsOneWidget);
    expect(
      find.text('Sua biblioteca começa com um jogo'),
      findsNothing,
      reason: 'erro não é vazio',
    );

    library.listError = null;
    await tapAndSettle(tester, find.text('Tentar de novo'));
    expect(find.text('Jogo Fixture Um'), findsWidgets);
  });

  group('replays', () {
    final twoRecords = FakeLibraryRepository([
      fakeEntry(id: 'a', status: GameStatus.completed, platform: 'PC'),
      fakeEntry(id: 'b', status: GameStatus.backlog, platform: 'PC'),
    ]);

    testWidgets(
      'dois registros do mesmo jogo são um cartão só, com indicador',
      (tester) async {
        await AppHarness(library: twoRecords).pump(tester);
        expect(find.byType(GameCard), findsOneWidget);
        expect(find.text('1 jogo · 2 registros'), findsOneWidget);
        expect(find.text('2'), findsOneWidget, reason: 'indicador de replays');
        expect(find.text('1 jogo encontrado'), findsOneWidget);
      },
    );

    testWidgets('a grade não mostra título nem dados fixos embaixo da capa', (
      tester,
    ) async {
      await AppHarness(
        library: FakeLibraryRepository([
          fakeEntry(
            id: 'a',
            status: GameStatus.completed,
            platform: 'PC',
            hours: 20,
            rating: 8,
          ),
        ]),
      ).pump(tester);
      expect(find.text('PC'), findsNothing);
      expect(find.textContaining('20'), findsNothing);
      expect(find.textContaining('8/10'), findsNothing);
    });

    testWidgets('o rótulo de acessibilidade diz status e registros', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await AppHarness(library: twoRecords).pump(tester);
      expect(
        find.bySemanticsLabel('Jogo Fixture Um, Vários status, 2 registros'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('na lista: vários status, "2 registros" e horas somadas', (
      tester,
    ) async {
      await AppHarness(
        library: FakeLibraryRepository([
          fakeEntry(id: 'a', status: GameStatus.completed, hours: 4, rating: 9),
          fakeEntry(id: 'b', status: GameStatus.backlog, hours: 6, rating: 5),
        ]),
      ).pump(tester, prefs: {'library.grid': false});
      expect(find.text('Vários status'), findsOneWidget);
      expect(find.text('2 registros'), findsOneWidget);
      expect(find.text('10,0 h'), findsOneWidget);
      expect(
        find.textContaining('Nota'),
        findsNothing,
        reason: 'a nota é de um registro, não do jogo',
      );
    });

    testWidgets('na lista, um registro só mostra a nota dele', (tester) async {
      await AppHarness(
        library: FakeLibraryRepository([fakeEntry(rating: 8, hours: 0)]),
      ).pump(tester, prefs: {'library.grid': false});
      expect(find.text('Nota 8/10'), findsOneWidget);
      expect(find.text('0,0 h'), findsOneWidget, reason: 'zero é um valor');
    });

    testWidgets('tocar na capa abre o jogo em "Meu progresso"', (tester) async {
      await AppHarness(library: twoRecords).pump(tester);
      await openLibraryGame(tester, 'Jogo Fixture Um');
      expect(location(tester), '/games/900001');
      expect(find.byType(EntryMenuButton), findsNWidgets(2));
    });

    testWidgets('menu do jogo: Ver registros e Novo registro', (tester) async {
      await AppHarness(library: twoRecords).pump(tester);
      await tester.ensureVisible(libraryGame('Jogo Fixture Um'));
      await tapAndSettle(tester, find.byType(GameMenuButton));
      expect(find.text('Ver registros'), findsOneWidget);
      expect(
        find.text('Editar'),
        findsNothing,
        reason: 'edição é por registro',
      );
      expect(find.text('Remover'), findsNothing);
      await tapAndSettle(tester, find.text('Novo registro'));
      expect(location(tester), '/games/900001/playthroughs/new');
    });
  });

  testWidgets(
    'novo registro pelo menu volta à Biblioteca e atualiza o resumo',
    (tester) async {
      final library = FakeLibraryRepository([fakeEntry(id: 'a')]);
      await AppHarness(library: library)
          .pump(tester, size: const Size(400, 2000));
      await tester.ensureVisible(libraryGame('Jogo Fixture Um'));
      await tapAndSettle(tester, find.byType(GameMenuButton));
      await tapAndSettle(tester, find.text('Novo registro'));
      expect(location(tester), '/games/900001/playthroughs/new');
      expect(
        find.text(
          'Você já tem 1 registro deste jogo. Este será um novo registro.',
        ),
        findsOneWidget,
      );

      await tapAndSettle(
        tester,
        find.widgetWithText(FilledButton, 'Salvar registro'),
      );
      expect(
        location(tester),
        '/library',
        reason: 'volta ao contexto de origem',
      );
      expect(find.text('1 jogo · 2 registros'), findsOneWidget);
      expect(library.created, hasLength(1));
    },
  );

  group('filtros', () {
    final data = [
      fakeEntry(id: 'a', status: GameStatus.completed, platform: 'PC'),
      fakeEntry(id: 'b', status: GameStatus.playing, platform: 'PS5'),
      fakeEntry(
        id: 'c',
        game: fakeGame(igdbId: 2, name: 'Celeste'),
        status: GameStatus.completed,
        platform: 'PC',
      ),
      fakeEntry(
        id: 'd',
        game: fakeGame(igdbId: 3, name: 'Pokémon Ônix'),
        status: GameStatus.backlog,
        platform: 'Switch',
      ),
    ];

    Future<void> pumpData(WidgetTester tester) =>
        AppHarness(library: FakeLibraryRepository(data))
            .pump(tester, size: const Size(400, 1400));

    testWidgets('chips contam jogos distintos e filtram; tocar de novo limpa', (
      tester,
    ) async {
      await pumpData(tester);
      expect(find.text('Todos (3)'), findsOneWidget);
      expect(find.text('Concluído (2)'), findsOneWidget);
      expect(find.text('Jogando (1)'), findsOneWidget);
      expect(find.text('Abandonado (0)'), findsOneWidget);
      expect(find.text('3 jogos encontrados'), findsOneWidget);

      await tapAndSettle(
        tester,
        find.widgetWithText(FilterChip, 'Concluído (2)'),
      );
      expect(find.text('2 jogos encontrados'), findsOneWidget);
      expect(libraryGame('Celeste'), findsOneWidget);
      expect(find.text('Pokémon Ônix'), findsNothing);

      await tapAndSettle(
        tester,
        find.widgetWithText(FilterChip, 'Abandonado (0)'),
      );
      expect(find.text('Nenhum jogo com esses filtros'), findsOneWidget);

      await tapAndSettle(
        tester,
        find.widgetWithText(FilterChip, 'Abandonado (0)'),
      );
      expect(find.text('3 jogos encontrados'), findsOneWidget);
    });

    testWidgets('busca ignora caixa e acentos; "Limpar busca" volta a tudo', (
      tester,
    ) async {
      await pumpData(tester);
      await search(tester, 'pokemon onix');
      expect(find.text('1 jogo encontrado'), findsOneWidget);
      expect(libraryGame('Pokémon Ônix'), findsOneWidget);
      expect(
        find.text('Todos (1)'),
        findsOneWidget,
        reason: 'a busca vale para os chips',
      );

      await tapAndSettle(tester, find.byTooltip('Limpar busca'));
      expect(find.text('3 jogos encontrados'), findsOneWidget);
    });

    testWidgets('plataforma: uma por vez, a partir dos registros', (
      tester,
    ) async {
      await pumpData(tester);
      await tapAndSettle(tester, find.byTooltip('Filtrar por plataforma'));
      for (final p in ['Todas as plataformas', 'PC', 'PS5', 'Switch']) {
        expect(find.text(p), findsWidgets, reason: p);
      }
      await tapAndSettle(tester, find.text('PS5').last);
      expect(find.text('1 jogo encontrado'), findsOneWidget);
      expect(find.text('Concluído (0)'), findsOneWidget);
      expect(find.text('Jogando (1)'), findsOneWidget);

      await tapAndSettle(tester, find.byTooltip('Filtrar por plataforma'));
      await tapAndSettle(tester, find.text('Todas as plataformas'));
      expect(find.text('3 jogos encontrados'), findsOneWidget);
    });

    testWidgets('status e plataforma valem para o mesmo registro', (
      tester,
    ) async {
      // Hades: concluído no PC e jogando no PS5. "Jogando" + "PC" não o encontra.
      await pumpData(tester);
      await tapAndSettle(
        tester,
        find.widgetWithText(FilterChip, 'Jogando (1)'),
      );
      await tapAndSettle(tester, find.byTooltip('Filtrar por plataforma'));
      await tapAndSettle(tester, find.text('PC').last);
      expect(find.text('Nenhum jogo com esses filtros'), findsOneWidget);
      expect(find.text('Jogando (0)'), findsOneWidget);
    });

    testWidgets('na lista, o filtro parcial mostra "1 de 2 registros"', (
      tester,
    ) async {
      await AppHarness(library: FakeLibraryRepository(data)).pump(
        tester,
        size: const Size(400, 1400),
        prefs: {'library.grid': false},
      );
      expect(find.text('Vários status'), findsOneWidget);
      await tapAndSettle(
        tester,
        find.widgetWithText(FilterChip, 'Jogando (1)'),
      );
      expect(find.text('1 de 2 registros'), findsOneWidget);
      expect(find.text('Vários status'), findsNothing);
      expect(find.text('Jogando'), findsWidgets);
    });

    testWidgets(
      '"Limpar" e "Limpar filtros" removem busca, status e plataforma',
      (tester) async {
        await AppHarness(library: FakeLibraryRepository(data)).pump(
          tester,
          size: const Size(400, 1400),
          prefs: {'library.grid': false, 'library.sort': 'name'},
        );
        expect(find.text('Limpar'), findsNothing);
        await search(tester, 'zzz');
        await tapAndSettle(
          tester,
          find.widgetWithText(FilterChip, 'Concluído (0)'),
        );
        expect(find.text('Nenhum jogo com esses filtros'), findsOneWidget);

        await tapAndSettle(
          tester,
          find.widgetWithText(OutlinedButton, 'Limpar filtros'),
        );
        expect(find.text('3 jogos encontrados'), findsOneWidget);
        expect(find.text('Limpar'), findsNothing);
        expect(tester.widget<TextField>(searchField).controller!.text, isEmpty);
        expect(
          find.byType(ListTile),
          findsNWidgets(3),
          reason: 'mantém a lista',
        );
      },
    );

    testWidgets('busca e filtros sobrevivem à troca de aba', (tester) async {
      await pumpData(tester);
      await search(tester, 'celeste');
      await tapAndSettle(tester, find.text('Explorar').last);
      await tapAndSettle(tester, find.text('Biblioteca').last);
      expect(tester.widget<TextField>(searchField).controller!.text, 'celeste');
      expect(find.text('1 jogo encontrado'), findsOneWidget);
    });

    testWidgets('busca e filtros são descartados ao sair da conta', (
      tester,
    ) async {
      await AppHarness(library: FakeLibraryRepository(data))
          .pump(tester, size: const Size(400, 1400));
      await search(tester, 'celeste');
      await tapAndSettle(tester, find.text('Perfil').last);
      await tapAndSettle(tester, find.byTooltip('Configurações'));
      await tapSignOut(tester);
      await tester.enterText(find.byType(TextFormField).first, 'ana');
      await tester.enterText(find.byType(TextFormField).last, 'senha');
      await tapAndSettle(tester, find.widgetWithText(FilledButton, 'Entrar'));
      // O login volta à rota lembrada (/settings); a Biblioteca é outra conta/sessão.
      await goTo(tester, '/library');
      expect(find.text('3 jogos encontrados'), findsOneWidget);
      expect(tester.widget<TextField>(searchField).controller!.text, isEmpty);
    });
  });

  group('Jogando agora', () {
    testWidgets('mostra os jogos em andamento e some com busca ou filtro', (
      tester,
    ) async {
      await AppHarness(
        library: FakeLibraryRepository([
          fakeEntry(id: 'a', status: GameStatus.playing),
          fakeEntry(
            id: 'b',
            game: fakeGame(igdbId: 2, name: 'Celeste'),
            status: GameStatus.completed,
          ),
        ]),
      ).pump(tester, size: const Size(400, 1400));
      expect(find.text('Jogando agora'), findsOneWidget);
      expect(find.text('1 jogo · 2 registros'), findsNothing);
      expect(
        find.text('2 jogos · 2 registros · 1 jogo em andamento'),
        findsOneWidget,
      );

      await search(tester, 'cel');
      expect(find.text('Jogando agora'), findsNothing);
      await tapAndSettle(tester, find.byTooltip('Limpar busca'));
      expect(find.text('Jogando agora'), findsOneWidget);

      await tapAndSettle(
        tester,
        find.widgetWithText(FilterChip, 'Concluído (1)'),
      );
      expect(find.text('Jogando agora'), findsNothing);
    });

    testWidgets('"Ver todos" filtra por Jogando e esconde a prateleira', (
      tester,
    ) async {
      await AppHarness(
        library: FakeLibraryRepository([
          fakeEntry(id: 'a', status: GameStatus.playing),
          fakeEntry(
            id: 'b',
            game: fakeGame(igdbId: 2, name: 'Celeste'),
            status: GameStatus.completed,
          ),
        ]),
      ).pump(tester, size: const Size(400, 1400));
      await tapAndSettle(tester, find.text('Ver todos'));
      expect(find.text('Jogando agora'), findsNothing);
      expect(find.text('1 jogo encontrado'), findsOneWidget);
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Jogando (1)'))
            .selected,
        isTrue,
      );
    });

    testWidgets('no máximo 6 capas', (tester) async {
      await AppHarness(
        library: FakeLibraryRepository([
          for (var i = 0; i < 9; i++)
            fakeEntry(
              id: 'e$i',
              game: fakeGame(igdbId: 10 + i, name: 'Jogo $i'),
              status: GameStatus.playing,
              createdAt: DateTime.utc(2026, 1, i + 1),
            ),
        ]),
      ).pump(tester, size: const Size(1400, 1000));
      final shelf = find.descendant(
        of: find.byType(ListView).first,
        matching: find.byType(GameCard),
      );
      expect(shelf.evaluate().length, lessThanOrEqualTo(6));
      expect(find.text('Jogo 8'), findsWidgets);
      expect(
        find.text('9 jogos · 9 registros · 9 jogos em andamento'),
        findsOneWidget,
      );
    });
  });

  group('composição (golden)', () {
    List<GameEntry> sample() => [
      fakeEntry(
        id: 'a',
        game: fakeGame(igdbId: 1, name: 'Hades'),
        status: GameStatus.playing,
        platform: 'PC',
        hours: 12,
        createdAt: DateTime.utc(2026, 3, 3),
      ),
      fakeEntry(
        id: 'b',
        game: fakeGame(igdbId: 1, name: 'Hades'),
        status: GameStatus.completed,
        platform: 'PC',
        hours: 30,
        rating: 9,
        createdAt: DateTime.utc(2026, 1, 3),
      ),
      fakeEntry(
        id: 'c',
        game: fakeGame(igdbId: 2, name: 'Celeste'),
        status: GameStatus.completed,
        platform: 'Switch',
        hours: 8,
        rating: 10,
        createdAt: DateTime.utc(2026, 2, 3),
      ),
      fakeEntry(
        id: 'd',
        game: fakeGame(
          igdbId: 3,
          name: 'The Legend of Zelda: Tears of the Kingdom — Edição Especial',
        ),
        status: GameStatus.playing,
        platform: 'Switch',
        createdAt: DateTime.utc(2026, 2, 20),
      ),
      fakeEntry(
        id: 'e',
        game: fakeGame(igdbId: 4, name: 'Doom'),
        status: GameStatus.backlog,
        platform: 'PC',
        createdAt: DateTime.utc(2026, 1, 20),
      ),
      fakeEntry(
        id: 'f',
        game: fakeGame(igdbId: 5, name: 'Hollow Knight'),
        status: GameStatus.dropped,
        platform: 'PC',
        createdAt: DateTime.utc(2026, 1, 10),
      ),
    ];

    for (final (name, size, grid) in [
      ('grade_390', const Size(390, 1000), true),
      ('lista_390', const Size(390, 1000), false),
      ('grade_1280', const Size(1280, 900), true),
    ]) {
      testWidgets(name, skip: goldenSkip, (tester) async {
        await AppHarness(library: FakeLibraryRepository(sample()))
            .pump(tester, size: size, prefs: {'library.grid': grid});
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/library_$name.png'),
        );
      });
    }
  });

  group('exibição', () {
    testWidgets('grade: duas colunas em 360 dp', (tester) async {
      await AppHarness(
        library: FakeLibraryRepository([
          for (var i = 0; i < 4; i++)
            fakeEntry(
              id: 'e$i',
              game: fakeGame(igdbId: 10 + i, name: 'Jogo $i'),
              status: GameStatus.completed,
            ),
        ]),
      ).pump(tester, size: const Size(360, 1200));
      final lefts = {
        for (final e in find.byType(GameCard).evaluate())
          tester.getTopLeft(find.byWidget(e.widget)).dx.round(),
      };
      expect(lefts, hasLength(2));
    });

    testWidgets('com texto a 200% a lista assume sem mexer na preferência', (
      tester,
    ) async {
      final h = AppHarness(library: FakeLibraryRepository([fakeEntry()]));
      await h.pump(
        tester,
        size: const Size(360, 800),
        textScale: 2.0,
        prefs: {'library.grid': true},
      );
      await tester.scrollUntilVisible(
        find.byType(ListTile),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(ListTile), findsWidgets);
      expect(
        find.byTooltip('Mostrar como lista'),
        findsOneWidget,
        reason: 'a preferência salva continua sendo grade',
      );
    });

    testWidgets('ordena por Nome A–Z e por horas', (tester) async {
      await AppHarness(
        library: FakeLibraryRepository([
          fakeEntry(
            id: 'a',
            game: fakeGame(igdbId: 1, name: 'Zeta'),
            hours: 50,
          ),
          fakeEntry(
            id: 'b',
            game: fakeGame(igdbId: 2, name: 'Alfa'),
            hours: 5,
          ),
          fakeEntry(
            id: 'c',
            game: fakeGame(igdbId: 3, name: 'Beta'),
          ),
        ]),
      ).pump(tester, prefs: {'library.grid': false, 'library.sort': 'name'});

      List<String> titles() => [
        for (final t in tester.widgetList<ListTile>(find.byType(ListTile)))
          ((t.title as Text).data)!,
      ];
      expect(titles(), ['Alfa', 'Beta', 'Zeta']);

      await tapAndSettle(tester, find.byTooltip('Ordenar por Nome A–Z'));
      await tapAndSettle(tester, find.text('Mais horas registradas').last);
      expect(titles(), [
        'Zeta',
        'Alfa',
        'Beta',
      ], reason: 'sem horas por último');
    });
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
    'alterar status de um registro (página do jogo) envia só essa mudança',
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
      await tapAndSettle(tester, find.byType(BackButton));
      expect(find.text('1 jogo · 1 registro'), findsOneWidget);
      expect(find.text('Jogando agora'), findsNothing);
    },
  );

  testWidgets('alterar um replay não mexe nos outros registros do jogo', (
    tester,
  ) async {
    final library = FakeLibraryRepository([
      fakeEntry(
        id: 'a',
        status: GameStatus.completed,
        createdAt: DateTime.utc(2026, 3, 1),
      ),
      fakeEntry(
        id: 'b',
        status: GameStatus.backlog,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ]);
    await AppHarness(library: library).pump(tester);
    // O primeiro card da página do jogo é o registro mais novo ('a').
    await openMenu(tester, 0, 'Alterar status');
    await tapAndSettle(tester, find.widgetWithText(ListTile, 'Abandonado'));
    expect(library.updated, hasLength(1), reason: 'só um registro é enviado');
    expect(library.updated.single.$1, 'a');
    expect(library.updated.single.$2.status, GameStatus.dropped);
  });

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
    // Identifica o jogo e o registro, não só "um registro".
    expect(find.textContaining('Jogo Fixture Um'), findsWidgets);
    // A data é a do aparelho (o registro guarda um instante).
    final created = DateOnly.fromLocal(DateTime.utc(2026, 1, 1).toLocal());
    expect(
      find.textContaining('PC · Na fila · criado em ${created.format()}'),
      findsOneWidget,
    );
    await tapAndSettle(tester, find.widgetWithText(TextButton, 'Cancelar'));
    expect(library.deleted, isEmpty);

    await tapAndSettle(tester, find.byType(EntryMenuButton).at(0));
    await tapAndSettle(tester, find.text('Remover').last);
    await tapAndSettle(tester, find.widgetWithText(FilledButton, 'Remover'));
    expect(library.deleted.length, 1);
    await tapAndSettle(tester, find.byType(BackButton));
    expect(
      find.text('1 jogo · 1 registro'),
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
    await tapAndSettle(tester, find.byType(BackButton));
    expect(find.text('1 jogo · 1 registro'), findsOneWidget);
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
      expect(find.text('Sua biblioteca começa com um jogo'), findsNothing);

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
    await tapAndSettle(tester, find.byTooltip('Configurações'));
    await tapSignOut(tester);
    expect(find.text('Jogo Fixture Um'), findsNothing);
    expect(find.text('Entrar'), findsWidgets);
  });
}
