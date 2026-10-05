import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gametracker/app/app_info.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_profiles.dart';
import '../../support/harness.dart';

Future<AppHarness> openSettings(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  FakeAuthRepository? auth,
}) async {
  final h = AppHarness(
    auth: auth,
    profiles: FakeProfilesRepository()
      ..profiles['u1'] = fakeProfile(id: 'u1', username: 'ana', name: 'ANA'),
  );
  await h.pump(tester, prefs: prefs);
  await tapAndSettle(tester, find.text('Perfil').last);
  await tapAndSettle(tester, find.byTooltip('Configurações'));
  return h;
}

ThemeMode appThemeMode(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode ??
    ThemeMode.system;

void main() {
  test('a versão exibida é a do pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(
      match,
      isNotNull,
      reason: 'pubspec.yaml precisa ter "version: x.y.z"',
    );
    expect(appVersion, match!.group(1));
  });

  testWidgets('mostra conta, versão e tema atual', (tester) async {
    await openSettings(tester);
    expect(find.text('Aparência'), findsOneWidget);
    expect(find.text('@ana · ana@example.test'), findsOneWidget);
    expect(find.text('Versão $appVersion'), findsOneWidget);
    expect(find.text('Guardado neste aparelho.'), findsOneWidget);
  });

  testWidgets('trocar o tema aplica na hora e persiste', (tester) async {
    await openSettings(tester);
    expect(appThemeMode(tester), ThemeMode.system);

    await tapAndSettle(tester, find.text('Escuro'));
    expect(appThemeMode(tester), ThemeMode.dark);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme.mode'), 'dark');

    await tapAndSettle(tester, find.text('Claro'));
    expect(appThemeMode(tester), ThemeMode.light);
    expect(prefs.getString('theme.mode'), 'light');
  });

  testWidgets('o tema salvo é aplicado ao abrir o app', (tester) async {
    final h = AppHarness();
    await h.pump(tester, prefs: {'theme.mode': 'dark'});
    expect(appThemeMode(tester), ThemeMode.dark);
  });

  testWidgets('sair volta ao login e chama o logout', (tester) async {
    final auth = FakeAuthRepository();
    final h = await openSettings(tester, auth: auth);
    await tapAndSettle(tester, find.text('Sair'));
    expect(find.text('Entrar'), findsWidgets);
    expect(h.auth.logoutCalls, 1);
  });

  testWidgets('voltar leva ao perfil', (tester) async {
    await openSettings(tester);
    await tapAndSettle(tester, find.byType(BackButton));
    expect(find.text('Editar perfil'), findsOneWidget);
  });

  testWidgets('layout a 360 px com texto 200% não estoura', (tester) async {
    final h = AppHarness();
    await h.pump(tester, size: const Size(360, 800), textScale: 2.0);
    await goTo(tester, '/settings');
    expect(tester.takeException(), isNull);
  });
}
