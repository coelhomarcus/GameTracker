import 'package:flutter_test/flutter_test.dart';
import 'package:gametracker/core/dates/date_only.dart';
import 'package:gametracker/core/design_system/game_status.dart';
import 'package:gametracker/core/network/app_exception.dart';
import 'package:gametracker/features/games/data/game_models.dart';
import 'package:gametracker/features/library/presentation/tracking_form_page.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_repos.dart';
import '../../support/harness.dart';

const _newPath = '/games/900001/playthroughs/new';

Finder get saveButton => find.widgetWithText(FilledButton, 'Salvar');
Finder get hoursField => find.widgetWithText(TextFormField, 'Horas jogadas');

Future<AppHarness> openForm(
  WidgetTester tester, {
  String path = _newPath,
  FakeLibraryRepository? library,
  FakeGamesRepository? games,
}) async {
  final h = AppHarness(library: library, games: games);
  await h.pump(tester);
  await goTo(tester, path);
  return h;
}

void main() {
  group('regras de validação', () {
    const today = DateOnly(2026, 6, 10);

    test('horas: vazio é válido; lixo e teto são recusados', () {
      String? check(String t, {DateOnly? start, DateOnly? end}) =>
          TrackingRules.hours(t, start: start, end: end, today: today);
      expect(check(''), isNull);
      expect(check('0'), isNull, reason: 'zero é valor válido');
      expect(check('12,5'), isNull);
      expect(check('abc'), 'Use só números, como 12 ou 12,5.');
      expect(check('100000'), contains('máximo'));
    });

    test('horas: 24 h por dia entre início e fim, ou até hoje', () {
      final msg = TrackingRules.hours(
        '73',
        start: const DateOnly(2026, 6, 8),
        end: null,
        today: today,
      );
      expect(msg, contains('72 h'));
      expect(msg, contains('entre o início e hoje'));
      expect(
        TrackingRules.hours(
          '72',
          start: const DateOnly(2026, 6, 8),
          end: null,
          today: today,
        ),
        isNull,
      );
      final withEnd = TrackingRules.hours(
        '50',
        start: const DateOnly(2026, 1, 5),
        end: const DateOnly(2026, 1, 6),
        today: today,
      );
      expect(withEnd, contains('48 h'));
      expect(withEnd, contains('entre início e fim'));
    });

    test('período: fim antes do início é erro', () {
      expect(
        TrackingRules.period(
          start: const DateOnly(2026, 2, 1),
          end: const DateOnly(2026, 1, 1),
        ),
        isNotNull,
      );
      expect(
        TrackingRules.period(
          start: const DateOnly(2026, 1, 1),
          end: const DateOnly(2026, 1, 1),
        ),
        isNull,
      );
      expect(
        TrackingRules.period(start: null, end: const DateOnly(2026, 1, 1)),
        isNull,
      );
    });
  });

  group('criar', () {
    testWidgets('abre pelo deep link, com as plataformas do jogo', (
      tester,
    ) async {
      await openForm(tester);
      expect(find.text('Novo playthrough'), findsWidgets);
      expect(find.text('Jogo Fixture Um'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'PC'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'PlayStation 5'), findsOneWidget);
    });

    testWidgets('salva status, horas e plataforma escolhidos', (tester) async {
      final h = await openForm(tester);
      await tapAndSettle(
        tester,
        find.widgetWithText(ChoiceChip, 'PlayStation 5'),
      );
      await tapAndSettle(tester, find.widgetWithText(ChoiceChip, 'Jogando'));
      await tester.enterText(hoursField, '12,5');
      await tapAndSettle(tester, saveButton);

      final (igdbId, draft) = h.library.created.single;
      expect(igdbId, 900001);
      expect(draft.platform, 'PlayStation 5');
      expect(draft.status, GameStatus.playing);
      expect(draft.hoursPlayed, 12.5);
      expect((draft.rating, draft.startedAt, draft.notes), (null, null, null));
      expect(
        find.text('Meu progresso'),
        findsOneWidget,
        reason: 'volta para a página do jogo',
      );
    });

    testWidgets('zero horas é enviado como zero', (tester) async {
      final h = await openForm(tester);
      await tester.enterText(hoursField, '0');
      await tapAndSettle(tester, saveButton);
      expect(h.library.created.single.$2.hoursPlayed, 0);
    });

    testWidgets('horas inválidas bloqueiam o salvar e explicam', (
      tester,
    ) async {
      final h = await openForm(tester);
      await tester.enterText(hoursField, 'abc');
      await tester.pumpAndSettle();
      expect(find.text('Use só números, como 12 ou 12,5.'), findsOneWidget);
      await tapAndSettle(tester, saveButton);
      expect(h.library.created, isEmpty);
    });

    testWidgets('teto de horas considera a data de início escolhida', (
      tester,
    ) async {
      final h = await openForm(tester);
      await tapAndSettle(tester, find.text('Início'));
      await tapAndSettle(tester, find.text('OK'));
      expect(find.text(DateOnly.today().format()), findsOneWidget);

      await tester.enterText(hoursField, '30');
      await tester.pumpAndSettle();
      expect(find.textContaining('passa das 24 h possíveis'), findsOneWidget);
      await tapAndSettle(tester, saveButton);
      expect(h.library.created, isEmpty);

      await tester.enterText(hoursField, '10');
      await tester.pumpAndSettle();
      expect(find.textContaining('passa das'), findsNothing);
    });

    testWidgets('data escolhida é enviada como dia de calendário', (
      tester,
    ) async {
      final h = await openForm(tester);
      await tapAndSettle(tester, find.text('Início'));
      await tapAndSettle(tester, find.text('OK'));
      await tapAndSettle(tester, saveButton);
      expect(h.library.created.single.$2.startedAt, DateOnly.today());
    });

    testWidgets('falha preserva o que foi digitado e permite tentar de novo', (
      tester,
    ) async {
      final library = FakeLibraryRepository()
        ..mutationError = const NetworkException();
      final h = await openForm(tester, library: library);
      await tester.enterText(hoursField, '12');
      await tapAndSettle(tester, find.widgetWithText(ChoiceChip, 'Concluído'));
      await tapAndSettle(tester, saveButton);

      expect(find.textContaining('Sem conexão'), findsWidgets);
      expect(
        find.text('12'),
        findsOneWidget,
        reason: 'horas continuam no campo',
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Concluído'))
            .selected,
        isTrue,
      );
      expect(h.library.created, isEmpty);
      expect(
        find.text('Novo playthrough'),
        findsWidgets,
        reason: 'continua no formulário',
      );

      library.mutationError = null;
      await tapAndSettle(tester, saveButton);
      expect(h.library.created.length, 1);
      expect(h.library.created.single.$2.hoursPlayed, 12);
    });

    testWidgets('avisa que criar de novo é um replay', (tester) async {
      await openForm(
        tester,
        library: FakeLibraryRepository([fakeEntry(id: 'a')]),
      );
      expect(
        find.textContaining('Você já tem 1 registro deste jogo'),
        findsOneWidget,
      );
    });

    testWidgets('nota: sem nota por padrão, escolher e remover', (
      tester,
    ) async {
      final h = await openForm(tester);
      expect(find.text('Sem nota'), findsWidgets);
      expect(find.byType(Slider), findsNothing);

      await tapAndSettle(tester, find.text('Dar uma nota'));
      expect(find.text('7/10'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);

      await tapAndSettle(tester, find.widgetWithText(TextButton, 'Sem nota'));
      expect(find.byType(Slider), findsNothing);
      await tapAndSettle(tester, saveButton);
      expect(
        h.library.created.single.$2.rating,
        isNull,
        reason: 'sem nota nunca vira 0',
      );
    });

    testWidgets('jogo sem plataformas pede a plataforma por texto', (
      tester,
    ) async {
      final games = FakeGamesRepository(
        games: {
          900001: const Game(
            id: 'g',
            igdbId: 900001,
            name: 'Sem Plataforma',
            screenshots: [],
            platforms: [],
            genres: [],
          ),
        },
      );
      final h = await openForm(tester, games: games);
      await tapAndSettle(tester, saveButton);
      expect(find.text('Informe a plataforma'), findsOneWidget);
      expect(h.library.created, isEmpty);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Plataforma'),
        'Mega Drive',
      );
      await tapAndSettle(tester, saveButton);
      expect(h.library.created.single.$2.platform, 'Mega Drive');
    });
  });

  group('editar', () {
    final entry = fakeEntry(
      id: 'e1',
      status: GameStatus.completed,
      hours: 20,
      rating: 8,
      startedAt: const DateOnly(2026, 1, 5),
      finishedAt: const DateOnly(2026, 1, 20),
      notes: 'Primeira vez',
    );
    const editPath = '/games/900001/playthroughs/e1/edit';

    testWidgets('mostra os valores salvos, sem deslocar as datas', (
      tester,
    ) async {
      await openForm(
        tester,
        path: editPath,
        library: FakeLibraryRepository([entry]),
      );
      expect(find.text('Editar playthrough'), findsWidgets);
      expect(tester.widget<TextFormField>(hoursField).controller!.text, '20');
      expect(find.text('05/01/2026'), findsOneWidget);
      expect(find.text('20/01/2026'), findsOneWidget);
      expect(find.text('8/10'), findsOneWidget);
      expect(find.text('Primeira vez'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Concluído'))
            .selected,
        isTrue,
      );
    });

    testWidgets('esvaziar campos envia a remoção, sem tocar no resto', (
      tester,
    ) async {
      final h = await openForm(
        tester,
        path: editPath,
        library: FakeLibraryRepository([entry]),
      );
      await tester.enterText(hoursField, '');
      await tapAndSettle(tester, find.widgetWithText(TextButton, 'Sem nota'));
      await tapAndSettle(tester, find.byTooltip('Limpar Fim'));
      await tapAndSettle(tester, saveButton);

      final (id, draft) = h.library.updated.single;
      expect(id, 'e1');
      expect(draft.hoursPlayed, isNull);
      expect(draft.rating, isNull);
      expect(draft.finishedAt, isNull);
      expect(
        draft.startedAt,
        const DateOnly(2026, 1, 5),
        reason: 'início não foi alterado',
      );
      expect(draft.status, GameStatus.completed);
      expect(draft.notes, 'Primeira vez');
    });

    testWidgets('registro inexistente mostra saída útil', (tester) async {
      await openForm(
        tester,
        path: '/games/900001/playthroughs/zzz/edit',
        library: FakeLibraryRepository([entry]),
      );
      expect(find.text('Registro não encontrado'), findsOneWidget);
      expect(find.text('Voltar ao jogo'), findsOneWidget);
    });

    testWidgets('sair com alterações pede confirmação; sem alterações, não', (
      tester,
    ) async {
      final h = AppHarness(library: FakeLibraryRepository([entry]));
      await h.pump(tester);
      await goTo(tester, '/games/900001');
      Future<void> openEdit() async {
        GoRouter.of(tester.element(find.byType(Scaffold).first)).push(editPath);
        await tester.pumpAndSettle();
      }

      await openEdit();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.text('Descartar alterações?'),
        findsNothing,
        reason: 'nada mudou',
      );
      expect(
        find.text('Meu progresso'),
        findsOneWidget,
        reason: 'voltou ao jogo',
      );

      await openEdit();
      await tester.enterText(hoursField, '25');
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Descartar alterações?'), findsOneWidget);

      await tapAndSettle(tester, find.text('Continuar editando'));
      expect(find.text('Descartar alterações?'), findsNothing);
      expect(
        tester.widget<TextFormField>(hoursField).controller!.text,
        '25',
        reason: 'o texto continua',
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text('Descartar'));
      expect(find.text('Meu progresso'), findsOneWidget);
    });

    testWidgets('editar sem mudar nada não dispara alteração indevida', (
      tester,
    ) async {
      final h = await openForm(
        tester,
        path: editPath,
        library: FakeLibraryRepository([entry]),
      );
      await tapAndSettle(tester, saveButton);
      // O formulário entrega o mesmo conteúdo; o repositório real compara e não envia nada (ver testes de corpo).
      expect(h.library.updated.single.$2.hoursPlayed, 20);
      expect(h.library.updated.single.$2.rating, 8);
    });
  });

  testWidgets('layout a 360 px e texto 200% não estoura', (tester) async {
    final h = AppHarness();
    await h.pump(tester, size: const Size(360, 800), textScale: 2.0);
    await goTo(tester, _newPath);
    expect(tester.takeException(), isNull);
  });
}
