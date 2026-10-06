import 'package:flutter_test/flutter_test.dart';
import 'package:gametracker/core/design_system/game_list_row.dart';
import 'package:gametracker/core/design_system/game_status.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'support/fake_repos.dart';
import 'support/harness.dart';

AppHarness signedIn() => AppHarness(
  library: FakeLibraryRepository([
    fakeEntry(id: 'e1', status: GameStatus.completed, hours: 20, rating: 8),
    fakeEntry(id: 'e2', status: GameStatus.backlog),
    fakeEntry(
      id: 'e3',
      game: fakeGame(
        igdbId: 900002,
        name: 'Jogo Fixture Dois com um nome bem comprido para testar quebra',
      ),
      platform: 'PlayStation 5',
      status: GameStatus.playing,
      hours: 0,
    ),
  ]),
);

void main() {
  testWidgets('sem sessão, o app abre no login', (tester) async {
    await AppHarness(signedIn: false).pump(tester, size: const Size(360, 800));
    expect(find.text('GameTracker'), findsOneWidget);
    expect(find.text('Entrar'), findsWidgets);
  });

  for (final w in [360.0, 599.0]) {
    testWidgets('largura $w usa NavigationBar', (tester) async {
      await signedIn().pump(tester, size: Size(w, 800));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });
  }

  for (final w in [600.0, 840.0, 1280.0]) {
    testWidgets('largura $w usa NavigationRail com os mesmos 5 destinos', (
      tester,
    ) async {
      await signedIn().pump(tester, size: Size(w, 800));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      for (final label in [
        'Biblioteca',
        'Explorar',
        'Comunidade',
        'Mensagens',
        'Perfil',
      ]) {
        expect(find.text(label), findsWidgets, reason: label);
      }
    });
  }

  testWidgets('navega entre destinos e preserva o filtro da Biblioteca', (
    tester,
  ) async {
    await signedIn().pump(tester, size: const Size(400, 800));
    await chooseStatus(tester, 'Jogando (1)');
    expect(find.textContaining('Jogo Fixture Dois'), findsWidgets);
    expect(find.text('Jogo Fixture Um'), findsNothing);

    await tapAndSettle(tester, find.text('Mensagens').last);
    expect(find.text('beto'), findsOneWidget);

    await tapAndSettle(tester, find.text('Biblioteca').last);
    expect(
      find.text('Jogo Fixture Um'),
      findsNothing,
      reason: 'estado do destino preservado',
    );
  });

  testWidgets('rota inexistente mostra saída útil', (tester) async {
    await signedIn().pump(tester, size: const Size(400, 800));
    tester.element(find.byType(NavigationBar)).go('/nada');
    await tester.pumpAndSettle();
    expect(find.text('Página não encontrada.'), findsOneWidget);
  });

  testWidgets('texto a 200% não gera overflow na Biblioteca', (tester) async {
    await signedIn().pump(tester, size: const Size(360, 800), textScale: 2.0);
    expect(tester.takeException(), isNull);
    // A 200% a lista assume (a grade de capas deixa de ser legível) e começa abaixo do resumo,
    // da prateleira e dos filtros.
    await tester.scrollUntilVisible(
      find.text('Jogo Fixture Um'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(GameListRow), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  group('rail nas páginas de detalhe', () {
    for (final path in [
      '/games/900001',
      '/games/900001/playthroughs/new',
      '/users/u-beto',
      '/settings',
      '/notifications',
    ]) {
      testWidgets('$path mantém o rail a 1280 e não duplica', (tester) async {
        await signedIn().pump(tester, size: const Size(1280, 900));
        await goTo(tester, path);
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('$path não mostra rail nem barra a 400', (tester) async {
        await signedIn().pump(tester, size: const Size(400, 900));
        await goTo(tester, path);
        expect(find.byType(NavigationRail), findsNothing);
        expect(find.byType(NavigationBar), findsNothing);
      });
    }

    testWidgets('o rail leva ao destino escolhido a partir do detalhe', (
      tester,
    ) async {
      await signedIn().pump(tester, size: const Size(1280, 900));
      await goTo(tester, '/games/900001');
      await tapAndSettle(
        tester,
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text('Explorar'),
        ),
      );
      final context = tester.element(find.byType(NavigationRail));
      expect(GoRouter.of(context).state.uri.path, '/explore');
      expect(find.byType(NavigationRail), findsOneWidget);
    });

    testWidgets('voltar do detalhe devolve o destino com o filtro intacto', (
      tester,
    ) async {
      await signedIn().pump(tester, size: const Size(1280, 900));
      await chooseStatus(tester, 'Jogando (1)');
      await openLibraryGame(
        tester,
        'Jogo Fixture Dois com um nome bem comprido para testar quebra',
      );
      expect(find.byType(NavigationRail), findsOneWidget);
      await tapAndSettle(tester, find.byType(BackButton));
      expect(find.text('Jogo Fixture Um'), findsNothing);
      expect(find.byType(NavigationRail), findsOneWidget);
    });

    testWidgets('redimensionar no detalhe não perde a página aberta', (
      tester,
    ) async {
      await signedIn().pump(tester, size: const Size(1280, 900));
      await goTo(tester, '/games/900001?tab=progress');
      tester.view.physicalSize = const Size(400, 900);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.widgetWithText(Tab, 'Meu progresso'), findsOneWidget);
      tester.view.physicalSize = const Size(1280, 900);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
    });
  });
}
