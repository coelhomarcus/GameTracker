import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gametracker/app/app.dart';

import 'support/fake_auth.dart';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

Future<void> pumpApp(
  WidgetTester tester, {
  required Size size,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: fakeAuthOverrides(FakeAuthRepository()),
      child: const GameTrackerApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> login(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Entrar'));
  await tester.tap(find.text('Entrar'));
  await tester.pumpAndSettle();
  expect(find.text('Informe seu e-mail ou username'), findsOneWidget);
  await tester.enterText(find.byType(TextFormField).first, 'ana');
  await tester.enterText(find.byType(TextFormField).last, 'senha');
  await tester.ensureVisible(find.text('Entrar'));
  await tester.tap(find.text('Entrar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('login valida campos e leva à Biblioteca', (tester) async {
    await pumpApp(tester, size: const Size(360, 800));
    expect(find.text('GameTracker'), findsOneWidget);
    await login(tester);
    expect(find.text('Biblioteca'), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  for (final w in [360.0, 599.0]) {
    testWidgets('largura $w usa NavigationBar', (tester) async {
      await pumpApp(tester, size: Size(w, 800));
      await login(tester);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });
  }

  for (final w in [600.0, 840.0, 1280.0]) {
    testWidgets('largura $w usa NavigationRail com os mesmos 5 destinos', (
      tester,
    ) async {
      await pumpApp(tester, size: Size(w, 800));
      await login(tester);
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
    await pumpApp(tester, size: const Size(360, 800));
    await login(tester);
    final chip = find.widgetWithText(FilterChip, 'Jogando');
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.textContaining('Jogo Fixture Dois'), findsWidgets);
    expect(find.text('Terceiro'), findsNothing);

    await tester.tap(find.text('Explorar').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Etapa 4'), findsOneWidget);

    await tester.tap(find.text('Biblioteca').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Terceiro'),
      findsNothing,
      reason: 'estado do destino preservado',
    );
  });

  testWidgets('página de jogo abre por igdbId e mostra os dois playthroughs', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(360, 800));
    await login(tester);
    await tester.tap(find.text('Jogo Fixture Um').first);
    await tester.pumpAndSettle();
    expect(find.text('Meu progresso'), findsOneWidget);
    await tester.tap(find.text('Meu progresso'));
    await tester.pumpAndSettle();
    expect(find.text('Concluído'), findsOneWidget);
    expect(find.text('Na fila'), findsOneWidget);
    expect(find.text('20,0 h'), findsOneWidget, reason: 'vírgula decimal');
    expect(find.text('Nota 8/10'), findsOneWidget);
  });

  testWidgets('rota inexistente mostra saída útil', (tester) async {
    await pumpApp(tester, size: const Size(360, 800));
    await login(tester);
    final context = tester.element(find.byType(NavigationBar));
    context.go('/nada');
    await tester.pumpAndSettle();
    expect(find.text('Página não encontrada.'), findsOneWidget);
  });

  testWidgets('texto a 200% não gera overflow na Biblioteca e no login', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(360, 800), textScale: 2.0);
    expect(tester.takeException(), isNull);
    await login(tester);
    expect(tester.takeException(), isNull);
  });
}
