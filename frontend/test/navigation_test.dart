// Etapa 03 do redesign: navegação, cabeçalhos, ação principal e retorno de subtelas.
import 'package:flutter_test/flutter_test.dart';
import 'package:gametracker/core/design_system/game_status.dart';
import 'package:gametracker/features/notifications/presentation/notifications_bell.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'support/fake_auth.dart';
import 'support/fake_chat.dart';
import 'support/fake_feed.dart';
import 'support/fake_profiles.dart';
import 'support/fake_repos.dart';
import 'support/harness.dart';

AppHarness harness() {
  final me = fakeUser();
  final h = AppHarness(
    library: FakeLibraryRepository([
      fakeEntry(id: 'e1', status: GameStatus.completed),
      fakeEntry(
        id: 'e2',
        game: fakeGame(igdbId: 900002, name: 'Jogo Fixture Dois'),
        status: GameStatus.playing,
      ),
    ]),
    feed: FakeFeedRepository(general: [fakePost()])..posts = {'p1': fakePost()},
  );
  h.profiles.profiles[me.id] = fakeProfile(
    id: me.id,
    username: me.username,
    name: me.displayName,
  );
  return h;
}

/// Rota do topo da pilha, inclusive a empilhada por `push` (que o `routeInformationProvider`
/// não reflete).
String location(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first)).state.uri.path;

Future<void> select(WidgetTester tester, String label) =>
    tapAndSettle(tester, find.text(label).last);

void main() {
  group('voltar em link direto (sem pilha)', () {
    for (final (path, fallback, label) in [
      ('/games/900001', '/library', 'jogo → Biblioteca'),
      ('/posts/p1', '/community', 'post → Comunidade'),
      ('/me/edit', '/me', 'edição → Perfil'),
      ('/settings', '/me', 'configurações → Perfil'),
      ('/messages/$convId', '/messages', 'conversa → Mensagens'),
      ('/posts/new', '/community', 'novo post → Comunidade'),
      ('/games/900001/playthroughs/new', '/games/900001', 'registro → jogo'),
    ]) {
      testWidgets(label, (tester) async {
        await harness().pump(tester);
        await goTo(tester, path);
        expect(location(tester), path);
        expect(
          find.byType(NavigationBar),
          findsNothing,
          reason: 'sem pilha: só a subtela',
        );

        await tapAndSettle(tester, find.byType(BackButton));
        expect(location(tester), fallback);
      });
    }

    testWidgets(
      'formulário com alteração pergunta antes de sair do link direto',
      (tester) async {
        await harness().pump(tester);
        await goTo(tester, '/posts/new');
        await tester.enterText(find.byType(TextField).first, 'rascunho');
        await tester.pumpAndSettle();

        await tapAndSettle(tester, find.byType(BackButton));
        expect(find.text('Descartar publicação?'), findsOneWidget);
        expect(location(tester), '/posts/new');

        await tapAndSettle(tester, find.text('Continuar editando'));
        expect(location(tester), '/posts/new');
        expect(find.text('rascunho'), findsOneWidget);

        await tapAndSettle(tester, find.byType(BackButton));
        await tapAndSettle(tester, find.text('Descartar'));
        expect(location(tester), '/community');
      },
    );

    for (final (path, fallback) in [
      ('/posts/nao-existe', '/community'),
      ('/users/nao-existe', '/community'),
      ('/messages/nao-existe', '/messages'),
    ]) {
      testWidgets('$path inexistente: erro com retry e saída', (tester) async {
        await harness().pump(tester);
        await goTo(tester, path);
        expect(find.text('Tentar de novo'), findsOneWidget);
        await tapAndSettle(tester, find.byType(BackButton));
        expect(location(tester), fallback);
      });
    }

    testWidgets('com pilha, voltar desfaz o push', (tester) async {
      await harness().pump(tester);
      await tester.tap(find.text('Jogo Fixture Um').first);
      await tester.pumpAndSettle();
      expect(location(tester), '/games/900001');
      await tapAndSettle(tester, find.byType(BackButton));
      expect(location(tester), '/library');
    });

    testWidgets('jogo com endereço inválido mostra saída, não tela em branco', (
      tester,
    ) async {
      await harness().pump(tester);
      await goTo(tester, '/games/abc');
      expect(find.text('Jogo não encontrado'), findsOneWidget);
      await tapAndSettle(
        tester,
        find.widgetWithText(FilledButton, 'Ir para a Biblioteca'),
      );
      expect(location(tester), '/library');
    });
  });

  testWidgets('link direto sem sessão: entra, cai no destino e volta ao app', (
    tester,
  ) async {
    await AppHarness(signedIn: false).pump(tester);
    await goTo(tester, '/games/900001');
    expect(location(tester), '/login');

    await tester.enterText(find.byType(TextFormField).first, 'ana');
    await tester.enterText(find.byType(TextFormField).last, 'senha');
    await tapAndSettle(tester, find.widgetWithText(FilledButton, 'Entrar'));
    expect(location(tester), '/games/900001');

    await tapAndSettle(tester, find.byType(BackButton));
    expect(location(tester), '/library');
  });

  group('ação principal', () {
    const actions = {
      'Biblioteca': 'Adicionar jogo',
      'Comunidade': 'Publicar',
      'Mensagens': 'Nova conversa',
    };

    for (final entry in actions.entries) {
      testWidgets('${entry.key}: FAB em janela estreita, nunca os dois', (
        tester,
      ) async {
        await harness().pump(tester, size: const Size(390, 800));
        await select(tester, entry.key);
        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(
          find.widgetWithText(FloatingActionButton, entry.value),
          findsOneWidget,
        );
        expect(
          find.byType(IconButton).evaluate().where((e) {
            final b = e.widget as IconButton;
            return b.tooltip == entry.value;
          }),
          isEmpty,
        );
      });

      testWidgets('${entry.key}: botão no cabeçalho em janela larga', (
        tester,
      ) async {
        await harness().pump(tester, size: const Size(900, 800));
        await select(tester, entry.key);
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byWidgetPredicate(
              (w) =>
                  (w is FilledButton || w is IconButton) &&
                  _hasLabel(w, entry.value),
            ),
          ),
          findsOneWidget,
        );
      });
    }

    testWidgets('o corte é 600 dp, o mesmo da navegação', (tester) async {
      await harness().pump(tester, size: const Size(599, 800));
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      await harness().pump(tester, size: const Size(600, 800));
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byType(NavigationRail), findsOneWidget);
    });

    testWidgets('o botão do cabeçalho executa a ação', (tester) async {
      await harness().pump(tester, size: const Size(900, 800));
      await select(tester, 'Comunidade');
      await tapAndSettle(
        tester,
        find.descendant(
          of: find.byType(AppBar),
          matching: find.widgetWithText(FilledButton, 'Publicar'),
        ),
      );
      expect(location(tester), '/posts/new');
    });
  });

  group('cabeçalhos dos destinos', () {
    for (final label in ['Biblioteca', 'Explorar', 'Comunidade', 'Perfil']) {
      testWidgets('$label tem o sino de notificações', (tester) async {
        await harness().pump(tester, size: const Size(390, 800));
        await select(tester, label);
        expect(find.byType(NotificationsBell), findsOneWidget);
      });
    }

    testWidgets('Perfil tem engrenagem; Mensagens tem cabeçalho próprio', (
      tester,
    ) async {
      await harness().pump(tester, size: const Size(390, 800));
      await select(tester, 'Perfil');
      expect(find.byTooltip('Configurações'), findsOneWidget);
      await select(tester, 'Mensagens');
      expect(find.byType(NotificationsBell), findsNothing);
      expect(find.byTooltip('Configurações'), findsNothing);
    });
  });

  group('rail e troca de destino', () {
    testWidgets('rail expandido só a partir de 1240 dp', (tester) async {
      await harness().pump(tester, size: const Size(1239, 800));
      expect(
        tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
        isFalse,
      );
      await harness().pump(tester, size: const Size(1240, 800));
      expect(
        tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
        isTrue,
      );
    });

    testWidgets('redimensionar mantém o destino selecionado', (tester) async {
      await harness().pump(tester, size: const Size(400, 800));
      await select(tester, 'Comunidade');
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );

      tester.view.physicalSize = const Size(900, 800);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        2,
      );
      expect(location(tester), '/community');
    });

    testWidgets('tocar no destino ativo não apaga o filtro da Biblioteca', (
      tester,
    ) async {
      await harness().pump(tester, size: const Size(400, 800));
      await tapAndSettle(
        tester,
        find.widgetWithText(FilterChip, 'Jogando (1)'),
      );
      expect(find.text('Jogo Fixture Um'), findsNothing);
      await select(tester, 'Biblioteca');
      expect(find.text('Jogo Fixture Um'), findsNothing);
      expect(find.text('Jogo Fixture Dois'), findsWidgets);
    });

    testWidgets('tocar no destino ativo volta à raiz dele', (tester) async {
      await harness().pump(tester, size: const Size(400, 800));
      await select(tester, 'Perfil');
      await tapAndSettle(tester, find.byTooltip('Configurações'));
      expect(location(tester), '/settings');
      // /settings é empilhada por cima do shell; voltar e tocar no destino leva à raiz.
      await tapAndSettle(tester, find.byType(BackButton));
      await select(tester, 'Perfil');
      expect(location(tester), '/me');
    });
  });
}

bool _hasLabel(Widget w, String label) => switch (w) {
  IconButton(:final tooltip) => tooltip == label,
  FilledButton() =>
    find
        .descendant(of: find.byWidget(w), matching: find.text(label))
        .evaluate()
        .isNotEmpty,
  _ => false,
};
