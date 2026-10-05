// Etapa 12: Configurações em seções, tema com amostra, atalhos da Biblioteca, notificações, conta.
import 'package:flutter_test/flutter_test.dart';
import 'package:gametracker/app/app_info.dart';
import 'package:gametracker/features/library/application/library_prefs.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_chat.dart';
import '../../support/fake_profiles.dart';
import '../../support/fake_repos.dart';
import '../../support/harness.dart';

Future<AppHarness> open(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  Size size = const Size(400, 3000),
  double textScale = 1,
  AppHarness? harness,
}) async {
  final h =
      harness ??
      AppHarness(
        library: FakeLibraryRepository([fakeEntry()]),
        profiles: FakeProfilesRepository()
          ..profiles['u1'] = fakeProfile(
            id: 'u1',
            username: 'ana',
            name: 'ANA',
          ),
      );
  await h.pump(tester, size: size, textScale: textScale, prefs: prefs);
  await goTo(tester, '/settings');
  return h;
}

String uri(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first)).state.uri
        .toString();

ThemeMode appThemeMode(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode ??
    ThemeMode.system;

void main() {
  group('estrutura', () {
    testWidgets('as seções, na ordem do plano', (tester) async {
      await open(tester);
      final order = [
        for (final t in [
          'Aparência',
          'Biblioteca',
          'Notificações',
          'Conta',
          'Sobre',
        ])
          tester.getTopLeft(find.text(t).first).dy,
      ];
      expect(order, orderedEquals([...order]..sort()));
      expect(order.toSet(), hasLength(5));
    });

    testWidgets('coluna de leitura de no máximo 680 dp', (tester) async {
      await open(tester, size: const Size(1440, 3000));
      final width = tester.getSize(find.byType(RadioGroup<LibrarySort>)).width;
      expect(width, lessThanOrEqualTo(680));
      expect(
        tester.getTopLeft(find.text('Aparência')).dx,
        greaterThan(300),
        reason: 'centralizada',
      );
    });

    testWidgets('Sobre: nome e versão, sem links nem ações inexistentes', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('GameTracker'), findsOneWidget);
      expect(find.text('Versão $appVersion'), findsOneWidget);
      for (final t in [
        'Termos',
        'Privacidade',
        'Exportar',
        'Excluir conta',
        'Apagar conta',
      ]) {
        expect(find.textContaining(t), findsNothing, reason: t);
      }
    });
  });

  group('aparência', () {
    testWidgets('três opções com amostra; a escolhida fica marcada', (
      tester,
    ) async {
      await open(tester);
      for (final t in ['Sistema', 'Claro', 'Escuro']) {
        expect(find.text(t), findsOneWidget);
      }
      expect(
        find.byIcon(Icons.check),
        findsOneWidget,
        reason: 'só a escolhida',
      );
      expect(find.text('Preferência deste aparelho.'), findsOneWidget);
    });

    testWidgets('trocar aplica na hora, persiste e move a marca', (
      tester,
    ) async {
      final h = await open(tester);
      await tapAndSettle(tester, find.text('Escuro'));
      expect(appThemeMode(tester), ThemeMode.dark);
      await tapAndSettle(tester, find.text('Claro'));
      expect(appThemeMode(tester), ThemeMode.light);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(
        find.descendant(
          of: find
              .ancestor(
                of: find.byIcon(Icons.check),
                matching: find.byType(Row),
              )
              .first,
          matching: find.text('Claro'),
        ),
        findsOneWidget,
        reason: 'a marca fica ao lado de "Claro"',
      );
      expect(h.library.listCalls, greaterThanOrEqualTo(0));
    });

    testWidgets(
      'cada opção é um item de grupo exclusivo com seleção anunciada',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await open(tester, prefs: {'theme.mode': 'dark'});
        expect(
          tester.getSemantics(find.bySemanticsLabel('Escuro')),
          matchesSemantics(
            label: 'Escuro',
            isButton: true,
            isSelected: true,
            hasSelectedState: true,
            isInMutuallyExclusiveGroup: true,
            hasTapAction: true,
            hasFocusAction: true,
            isFocusable: true,
          ),
        );
        semantics.dispose();
      },
    );

    testWidgets('as opções têm alvo de pelo menos 48 dp', (tester) async {
      await open(tester);
      for (final t in ['Sistema', 'Claro', 'Escuro']) {
        final size = tester.getSize(
          find.ancestor(of: find.text(t), matching: find.byType(InkWell)).first,
        );
        expect(size.height, greaterThanOrEqualTo(48), reason: t);
        expect(size.width, greaterThanOrEqualTo(48), reason: t);
      }
    });
  });

  group('biblioteca', () {
    testWidgets(
      'grade/lista e ordenação são as preferências da própria Biblioteca',
      (tester) async {
        final h = await open(
          tester,
          prefs: {'library.grid': true, 'library.sort': 'recent'},
        );
        expect(
          tester
              .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
              .selected,
          {true},
        );
        await tapAndSettle(tester, find.text('Lista'));
        await tapAndSettle(tester, find.text('Nome A–Z'));

        // A Biblioteca mostra o que foi escolhido aqui (mesmos providers, nada duplicado).
        await goTo(tester, '/library');
        expect(find.byType(ListTile), findsWidgets, reason: 'lista');
        expect(find.byTooltip('Ordenar por Nome A–Z'), findsOneWidget);
        expect(h.library.listCalls, greaterThan(0));

        // E o contrário: mudar na Biblioteca reflete em Configurações.
        await tapAndSettle(tester, find.byTooltip('Mostrar como grade'));
        await goTo(tester, '/settings');
        expect(
          tester
              .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
              .selected,
          {true},
        );
      },
    );

    testWidgets('a ordenação lista as quatro opções, com a atual marcada', (
      tester,
    ) async {
      await open(tester, prefs: {'library.sort': 'most_played'});
      for (final sort in LibrarySort.values) {
        expect(
          find.widgetWithText(RadioListTile<LibrarySort>, sort.label),
          findsOneWidget,
        );
      }
      final selected = tester
          .widgetList<RadioListTile<LibrarySort>>(
            find.byType(RadioListTile<LibrarySort>),
          )
          .where((r) => r.value == LibrarySort.mostPlayed);
      expect(selected, hasLength(1));
    });
  });

  group('notificações', () {
    testWidgets(
      'sem adaptador: explica o que existe e não oferece um interruptor inoperante',
      (tester) async {
        await open(tester);
        expect(
          find.text(
            'As notificações aparecem na central com o app aberto. '
            'Avisos com o app fechado não estão disponíveis nesta versão.',
          ),
          findsOneWidget,
        );
        expect(find.byType(Switch), findsNothing);
        expect(find.text('Ativar'), findsNothing);
      },
    );

    testWidgets('"Abrir central de notificações" abre a central', (
      tester,
    ) async {
      await open(tester);
      await tapAndSettle(tester, find.text('Abrir central de notificações'));
      expect(uri(tester), '/notifications');
      expect(find.text('Notificações'), findsWidgets);
    });
  });

  group('conta', () {
    testWidgets('mostra nome, handle e e-mail; Editar perfil abre a edição', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('ANA'), findsWidgets);
      expect(find.text('@ana · ana@example.test'), findsOneWidget);
      await tapAndSettle(tester, find.text('Editar perfil'));
      expect(uri(tester), '/me/edit');
    });

    testWidgets('sem rascunho de conversa, sair é direto', (tester) async {
      final auth = FakeAuthRepository();
      final h = AppHarness(
        auth: auth,
        profiles: FakeProfilesRepository()
          ..profiles['u1'] = fakeProfile(
            id: 'u1',
            username: 'ana',
            name: 'ANA',
          ),
      );
      await open(tester, harness: h);
      await tapAndSettle(tester, find.text('Sair'));
      expect(find.text('Sair da conta?'), findsNothing);
      expect(auth.logoutCalls, 1);
      expect(find.text('Entrar'), findsWidgets);
    });

    testWidgets('com mensagem escrita e não enviada, pergunta antes de sair', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      final h = AppHarness(
        auth: auth,
        profiles: FakeProfilesRepository()
          ..profiles['u1'] = fakeProfile(
            id: 'u1',
            username: 'ana',
            name: 'ANA',
          ),
      );
      h.chat.list = [conversation()];
      await h.pump(tester, size: const Size(400, 3000));
      await goTo(tester, '/messages/$convId');
      await tester.enterText(
        find.widgetWithText(TextField, 'Mensagem'),
        'ainda escrevendo',
      );
      await tester.pumpAndSettle();
      await goTo(tester, '/settings');

      await tapAndSettle(tester, find.text('Sair'));
      expect(find.text('Sair da conta?'), findsOneWidget);
      expect(
        find.textContaining('uma mensagem escrita e não enviada'),
        findsOneWidget,
      );
      expect(auth.logoutCalls, 0, reason: 'ainda não saiu');

      await tapAndSettle(tester, find.text('Continuar no app'));
      expect(find.text('Sair da conta?'), findsNothing);
      expect(auth.logoutCalls, 0);
      expect(uri(tester), '/settings');

      await tapAndSettle(tester, find.text('Sair'));
      await tapAndSettle(tester, find.widgetWithText(FilledButton, 'Sair'));
      expect(auth.logoutCalls, 1);
      expect(find.text('Entrar'), findsWidgets);
    });
  });

  group('layout', () {
    for (final (size, scale) in [
      (const Size(360, 800), 2.0),
      (const Size(390, 844), 1.0),
      (const Size(1440, 900), 1.0),
    ]) {
      testWidgets('${size.width.toInt()} px, texto $scale×: sem overflow', (
        tester,
      ) async {
        await open(tester, size: size, textScale: scale);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('Versão $appVersion'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
