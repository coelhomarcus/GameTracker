import 'package:flutter_test/flutter_test.dart';
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
    await tapAndSettle(tester, find.widgetWithText(FilterChip, 'Jogando (1)'));
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
    expect(find.text('Jogo Fixture Um'), findsWidgets);
  });
}
