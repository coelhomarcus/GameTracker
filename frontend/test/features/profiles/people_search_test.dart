import 'package:flutter_test/flutter_test.dart';
import 'package:gametracker/core/network/app_exception.dart';
import 'package:gametracker/features/profiles/application/profile_providers.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_profiles.dart';
import '../../support/harness.dart';

Future<void> typePeople(WidgetTester tester, String text) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(SearchBar),
      matching: find.byType(EditableText),
    ),
    text,
  );
  await tester.pump(peopleSearchDebounce + const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

Future<AppHarness> openPeople(
  WidgetTester tester, {
  FakeProfilesRepository? profiles,
}) async {
  final h = AppHarness(profiles: profiles);
  await h.pump(tester);
  await tapAndSettle(tester, find.text('Explorar').last);
  await tapAndSettle(tester, find.text('Pessoas'));
  return h;
}

FakeProfilesRepository withResults() => FakeProfilesRepository()
  ..searchResult = [
    fakePerson(
      id: 'u-beto',
      username: 'beto',
      name: 'Beto Silva',
      bio: 'Gosto de RPG',
    ),
    fakePerson(id: 'u-cris', username: 'cris', followed: true),
  ]
  ..profiles['u-beto'] = fakeProfile(name: 'Beto Silva', followers: 3);

void main() {
  testWidgets('sem termo mostra a dica e não consulta', (tester) async {
    final p = withResults();
    await openPeople(tester, profiles: p);
    expect(find.text('Encontre pessoas'), findsOneWidget);
    await typePeople(tester, 'b');
    expect(find.text('Encontre pessoas'), findsOneWidget);
    expect(p.searches, isEmpty);
  });

  testWidgets(
    'mostra nome, username, bio e o estado de seguir depois do debounce',
    (tester) async {
      final p = withResults();
      await openPeople(tester, profiles: p);
      await typePeople(tester, 'be');
      expect(p.searches, ['be']);
      expect(find.text('Beto Silva'), findsOneWidget);
      expect(find.text('@beto'), findsOneWidget);
      expect(find.text('Gosto de RPG'), findsOneWidget);
      expect(
        find.text('cris'),
        findsOneWidget,
        reason: 'sem nome cai no username',
      );
      expect(find.widgetWithText(FilledButton, 'Seguir'), findsOneWidget);
      expect(find.text('Seguindo'), findsOneWidget);
    },
  );

  testWidgets('seguir direto nos resultados é imediato; falha desfaz e avisa', (
    tester,
  ) async {
    final p = withResults();
    await openPeople(tester, profiles: p);
    await typePeople(tester, 'be');

    await tapAndSettle(tester, find.widgetWithText(FilledButton, 'Seguir'));
    expect(find.text('Seguindo'), findsNWidgets(2));
    expect(p.followCalls.single, ('u-beto', true));

    p.followError = const NetworkException();
    await tapAndSettle(tester, find.text('Seguindo').first);
    expect(find.text('Seguindo'), findsNWidgets(2), reason: 'desfez');
    expect(find.textContaining('Sem conexão'), findsOneWidget);
  });

  testWidgets(
    'seguir na busca aparece no perfil da pessoa, com o contador somado',
    (tester) async {
      final p = withResults();
      await openPeople(tester, profiles: p);
      await typePeople(tester, 'be');
      await tapAndSettle(tester, find.widgetWithText(FilledButton, 'Seguir'));

      await tapAndSettle(tester, find.text('Beto Silva'));
      expect(find.text('@beto'), findsOneWidget);
      expect(find.text('Seguindo'), findsOneWidget, reason: 'o perfil já sabe');
      expect(find.textContaining('4 seguidores'), findsOneWidget);
    },
  );

  testWidgets('nenhum resultado é diferente de erro', (tester) async {
    final p = FakeProfilesRepository()..searchResult = const [];
    await openPeople(tester, profiles: p);
    await typePeople(tester, 'xyz');
    expect(find.text('Ninguém encontrado'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsNothing);
  });

  testWidgets('erro de rede mostra mensagem e tenta de novo', (tester) async {
    final p = withResults()..searchError = const NetworkException();
    await openPeople(tester, profiles: p);
    await typePeople(tester, 'be');
    expect(find.textContaining('Sem conexão'), findsOneWidget);
    expect(find.text('Ninguém encontrado'), findsNothing);

    p.searchError = null;
    await tapAndSettle(tester, find.text('Tentar de novo'));
    await tester.pump(peopleSearchDebounce + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(find.text('Beto Silva'), findsOneWidget);
  });

  testWidgets(
    'limpar a busca volta à dica; o termo é preservado ao trocar de aba',
    (tester) async {
      final p = withResults();
      await openPeople(tester, profiles: p);
      await typePeople(tester, 'be');
      await tapAndSettle(tester, find.text('Jogos'));
      await tapAndSettle(tester, find.text('Pessoas'));
      await tester.pump(
        peopleSearchDebounce + const Duration(milliseconds: 50),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Beto Silva'),
        findsOneWidget,
        reason: 'a consulta é a mesma nas duas abas',
      );

      await tapAndSettle(tester, find.byTooltip('Limpar busca'));
      expect(find.text('Encontre pessoas'), findsOneWidget);
    },
  );

  testWidgets('a abas Jogos e Pessoas têm buscas independentes', (
    tester,
  ) async {
    final p = withResults();
    final h = await openPeople(tester, profiles: p);
    await typePeople(tester, 'be');
    expect(
      h.games.searches,
      isEmpty,
      reason: 'buscar pessoas não consulta jogos',
    );
  });
}
