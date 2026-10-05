// Etapa 10: lista com busca e filtro, conversa pela rota (inclusive lado a lado), bolhas, atalhos
// do composer e o comportamento de rolagem quando chega mensagem.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gametracker/core/models/user_summary.dart';
import 'package:gametracker/core/realtime/chat_transport.dart';
import 'package:gametracker/features/chat/data/chat_models.dart';
import 'package:gametracker/features/chat/presentation/messages_page.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_chat.dart';
import '../../support/fake_feed.dart' show beto;
import '../../support/fake_profiles.dart';
import '../../support/harness.dart';

const cris = UserSummary(id: 'u-cris', username: 'cris', name: 'Cris Souza');
const joao = UserSummary(id: 'u-joao', username: 'joao_p', name: 'João Pêra');

LastMessage last(String text, {String from = 'u-beto', int minute = 0}) =>
    LastMessage(
      id: 'l$minute',
      content: text,
      senderId: from,
      createdAt: DateTime.now().subtract(Duration(minutes: minute + 1)),
    );

AppHarness harness() {
  final h = AppHarness();
  h.chat.list = [
    conversation(other: beto, last: last('olá, beto aqui', minute: 1)),
    conversation(
      id: 'conv-2',
      other: cris,
      unread: true,
      last: last('Você viu isso?', from: 'u-cris', minute: 5),
    ),
    conversation(
      id: 'conv-3',
      other: joao,
      last: last('combinado', from: meId, minute: 9),
    ),
  ];
  for (final id in ['conv-2', 'conv-3']) {
    h.chat.history[id] = [
      serverMessage('m-$id', text: 'oi de $id', conversation: id),
    ];
  }
  h.chat.history[convId] = [
    serverMessage('m1', text: 'olá, beto aqui', minute: 1),
  ];
  return h;
}

Future<AppHarness> openList(
  WidgetTester tester, {
  Size size = const Size(400, 900),
  double textScale = 1,
  AppHarness? h,
}) async {
  final harness0 = h ?? harness();
  await harness0.pump(tester, size: size, textScale: textScale);
  await tapAndSettle(tester, find.text('Mensagens').last);
  return harness0;
}

String uri(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first)).state.uri
        .toString();

Finder get search => find.widgetWithText(TextField, 'Buscar conversas');
Finder get composer => find.widgetWithText(TextField, 'Mensagem');

void main() {
  group('lista: busca e filtro', () {
    testWidgets('busca por nome ou username, sem caixa nem acentos', (
      tester,
    ) async {
      await openList(tester);
      for (final (q, shown, hidden) in [
        ('cris', 'Cris Souza', 'João Pêra'),
        ('SOUZA', 'Cris Souza', 'beto'),
        ('joao', 'João Pêra', 'Cris Souza'),
        ('joão', 'João Pêra', 'beto'),
        ('pera', 'João Pêra', 'Cris Souza'),
        ('joao_p', 'João Pêra', 'Cris Souza'),
      ]) {
        await tester.enterText(search, q);
        await tester.pumpAndSettle();
        expect(find.text(shown), findsOneWidget, reason: q);
        expect(find.text(hidden), findsNothing, reason: q);
      }
    });

    testWidgets('não busca no texto das mensagens', (tester) async {
      await openList(tester);
      await tester.enterText(search, 'combinado');
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma conversa encontrada'), findsOneWidget);
    });

    testWidgets('sem resultado: oferece limpar a busca', (tester) async {
      await openList(tester);
      await tester.enterText(search, 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma conversa encontrada'), findsOneWidget);
      await tapAndSettle(
        tester,
        find.widgetWithText(OutlinedButton, 'Limpar busca'),
      );
      expect(find.text('Nenhuma conversa encontrada'), findsNothing);
      expect(tester.widget<TextField>(search).controller!.text, isEmpty);
      expect(find.text('Cris Souza'), findsOneWidget);
    });

    testWidgets('chips contam conversas; "Não lidas" filtra', (tester) async {
      await openList(tester);
      expect(find.text('Todas (3)'), findsOneWidget);
      expect(find.text('Não lidas (1)'), findsOneWidget);
      await tapAndSettle(
        tester,
        find.widgetWithText(FilterChip, 'Não lidas (1)'),
      );
      expect(find.text('Cris Souza'), findsOneWidget);
      expect(find.text('beto'), findsNothing);
      await tapAndSettle(tester, find.widgetWithText(FilterChip, 'Todas (3)'));
      expect(find.text('beto'), findsOneWidget);
    });

    testWidgets(
      'busca e filtro combinam; "Não lidas" sem nenhuma mostra o vazio',
      (tester) async {
        await openList(tester);
        await tapAndSettle(
          tester,
          find.widgetWithText(FilterChip, 'Não lidas (1)'),
        );
        await tester.enterText(search, 'joao');
        await tester.pumpAndSettle();
        expect(find.text('Nenhuma conversa encontrada'), findsOneWidget);
        await tapAndSettle(
          tester,
          find.widgetWithText(OutlinedButton, 'Limpar busca'),
        );
        expect(
          find.text('Cris Souza'),
          findsOneWidget,
          reason: 'limpar zera busca e filtro',
        );
        expect(find.text('beto'), findsOneWidget);
      },
    );

    testWidgets('a ordem da lista é a do controlador (mais recente primeiro)', (
      tester,
    ) async {
      await openList(tester);
      double y(String name) => tester.getTopLeft(find.text(name)).dy;
      expect(y('beto'), lessThan(y('Cris Souza')));
      expect(y('Cris Souza'), lessThan(y('João Pêra')));
      await tester.enterText(search, 'o');
      await tester.pumpAndSettle();
      expect(
        y('beto'),
        lessThan(y('João Pêra')),
        reason: 'filtrar não reordena',
      );
    });

    testWidgets('busca e filtro sobrevivem à troca de aba e abrir conversa', (
      tester,
    ) async {
      await openList(tester);
      await tester.enterText(search, 'cris');
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text('Biblioteca').last);
      await tapAndSettle(tester, find.text('Mensagens').last);
      expect(tester.widget<TextField>(search).controller!.text, 'cris');
      await tapAndSettle(tester, find.text('Cris Souza'));
      await tapAndSettle(tester, find.byType(BackButton));
      expect(tester.widget<TextField>(search).controller!.text, 'cris');
      expect(find.text('beto'), findsNothing);
    });

    testWidgets('descartados ao sair da conta', (tester) async {
      await openList(tester);
      await tester.enterText(search, 'cris');
      await tapAndSettle(
        tester,
        find.widgetWithText(FilterChip, 'Não lidas (1)'),
      );
      await tapAndSettle(tester, find.text('Perfil').last);
      await tapAndSettle(tester, find.byTooltip('Configurações'));
      await tapSignOut(tester);
      await tester.enterText(find.byType(TextFormField).first, 'ana');
      await tester.enterText(find.byType(TextFormField).last, 'senha');
      await tapAndSettle(tester, find.widgetWithText(FilledButton, 'Entrar'));
      await goTo(tester, '/messages');
      expect(tester.widget<TextField>(search).controller!.text, isEmpty);
      expect(find.text('Todas (3)'), findsOneWidget);
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Todas (3)'))
            .selected,
        isTrue,
      );
    });

    testWidgets(
      'a linha mostra até duas linhas da última mensagem, "Você:" e o ponto de não lida',
      (tester) async {
        final h = harness();
        h.chat.list = [
          conversation(
            other: beto,
            unread: true,
            last: last('Uma mensagem bem longa ' * 8, from: meId),
          ),
        ];
        await openList(tester, h: h);
        final preview = tester.widget<Text>(
          find.textContaining('Você: Uma mensagem'),
        );
        expect(preview.maxLines, 2);
        expect(preview.overflow, TextOverflow.ellipsis);
        expect(find.text('Não lidas (1)'), findsOneWidget);
      },
    );

    testWidgets('sem conversas: convite a começar uma, sem busca nem filtros', (
      tester,
    ) async {
      final h = AppHarness();
      h.chat.list = [];
      await openList(tester, h: h);
      expect(find.text('Nenhuma conversa ainda'), findsOneWidget);
      expect(search, findsNothing);
    });
  });

  group('conversa pela rota', () {
    testWidgets(
      'no celular a conversa ocupa a tela toda, sem a barra inferior',
      (tester) async {
        final h = harness();
        await h.pump(tester);
        await goTo(tester, '/messages/$convId');
        expect(composer, findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
        await tapAndSettle(tester, find.byType(BackButton));
        expect(uri(tester), '/messages');
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.text('Cris Souza'), findsOneWidget);
      },
    );

    testWidgets('tocar numa conversa abre a rota dela', (tester) async {
      await openList(tester);
      await tapAndSettle(tester, find.text('Cris Souza'));
      expect(uri(tester), '/messages/conv-2');
      expect(find.text('oi de conv-2'), findsOneWidget);
    });

    testWidgets(
      'lado a lado: a rota decide a conversa e o rail continua à vista',
      (tester) async {
        final h = harness();
        await h.pump(tester, size: const Size(1100, 800));
        await goTo(tester, '/messages/conv-2');
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.text('oi de conv-2'), findsOneWidget);
        expect(
          find.text('beto'),
          findsOneWidget,
          reason: 'a lista está ao lado',
        );
        expect(find.byType(BackButton), findsNothing);
      },
    );

    testWidgets('lado a lado: trocar de conversa muda a rota e o painel', (
      tester,
    ) async {
      final h = harness();
      await h.pump(tester, size: const Size(1100, 800));
      await tapAndSettle(tester, find.text('Mensagens').last);
      expect(find.text('Escolha uma conversa'), findsOneWidget);

      await tapAndSettle(tester, find.text('Cris Souza'));
      expect(uri(tester), '/messages/conv-2');
      expect(find.text('oi de conv-2'), findsOneWidget);
      await tapAndSettle(tester, find.text('João Pêra'));
      expect(uri(tester), '/messages/conv-3');
      expect(find.text('oi de conv-3'), findsOneWidget);
      expect(find.text('oi de conv-2'), findsNothing);
    });

    testWidgets('a conversa selecionada fica destacada na lista', (
      tester,
    ) async {
      final h = harness();
      await h.pump(tester, size: const Size(1100, 800));
      await goTo(tester, '/messages/conv-2');
      final selected = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .where((t) => t.selected)
          .toList();
      expect(selected, hasLength(1));
      expect(((selected.single.title! as Text).data), 'Cris Souza');
    });

    testWidgets(
      'redimensionar mantém a mesma conversa, o rascunho e uma sala só',
      (tester) async {
        final h = harness();
        await h.pump(tester, size: const Size(400, 900));
        await goTo(tester, '/messages/conv-2');
        await tester.enterText(composer, 'rascunho aqui');
        await tester.pumpAndSettle();
        expect(h.transport.joins, ['conv-2']);

        tester.view.physicalSize = const Size(1100, 800);
        await tester.pumpAndSettle();
        expect(uri(tester), '/messages/conv-2');
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.text('oi de conv-2'), findsOneWidget);
        expect(
          tester.widget<TextField>(composer).controller!.text,
          'rascunho aqui',
        );

        tester.view.physicalSize = const Size(400, 900);
        await tester.pumpAndSettle();
        expect(uri(tester), '/messages/conv-2');
        expect(
          find.byType(NavigationBar),
          findsNothing,
          reason: 'tela cheia no celular',
        );
        expect(
          tester.widget<TextField>(composer).controller!.text,
          'rascunho aqui',
        );
        expect(
          h.transport.joins.where((j) => j == 'conv-2').length,
          lessThanOrEqualTo(2),
          reason: 'no máximo uma sala por montagem, nunca duas ao mesmo tempo',
        );
      },
    );

    testWidgets('só uma conversa fica montada por vez ao lado da lista', (
      tester,
    ) async {
      final h = harness();
      await h.pump(tester, size: const Size(1100, 800));
      await goTo(tester, '/messages/conv-2');
      await tapAndSettle(tester, find.text('João Pêra'));
      expect(
        find.byType(TextField).evaluate().where((e) {
          final f = e.widget as TextField;
          return f.decoration?.hintText == 'Mensagem';
        }),
        hasLength(1),
      );
    });

    testWidgets('o corte do layout lado a lado é 760 dp de espaço útil', (
      tester,
    ) async {
      final h = harness();
      await h.pump(tester, size: const Size(900, 800));
      await goTo(tester, '/messages/conv-2');
      // O que importa é o espaço da área, depois do rail e do divisor.
      final area = tester.getSize(find.byType(MessagesPage)).width;
      final chrome = 900 - area;

      tester.view.physicalSize = Size(759 + chrome, 800);
      await tester.pumpAndSettle();
      expect(find.text('beto'), findsNothing, reason: '759 dp: só a conversa');
      expect(composer, findsOneWidget);

      tester.view.physicalSize = Size(760 + chrome, 800);
      await tester.pumpAndSettle();
      expect(
        find.text('beto'),
        findsOneWidget,
        reason: '760 dp: a lista cabe ao lado',
      );
      expect(composer, findsOneWidget);
    });

    testWidgets('link direto sem sessão: entra e cai na conversa', (
      tester,
    ) async {
      final h = AppHarness(signedIn: false);
      await h.pump(tester);
      await goTo(tester, '/messages/$convId');
      expect(uri(tester).startsWith('/login'), isTrue);
      await tester.enterText(find.byType(TextFormField).first, 'ana');
      await tester.enterText(find.byType(TextFormField).last, 'senha');
      await tapAndSettle(tester, find.widgetWithText(FilledButton, 'Entrar'));
      expect(uri(tester), '/messages/$convId');
    });

    testWidgets('conversa inexistente: erro com saída para a lista', (
      tester,
    ) async {
      final h = harness();
      h.transport.rejectedRooms.add('zzz');
      await h.pump(tester);
      await goTo(tester, '/messages/zzz');
      expect(find.text('Tentar de novo'), findsOneWidget);
      await tapAndSettle(tester, find.byType(BackButton));
      expect(uri(tester), '/messages');
    });

    testWidgets('"Nova conversa" lado a lado abre pela rota', (tester) async {
      final h = harness();
      h.profiles.searchResult = [
        fakePerson(id: 'u-beto', username: 'beto', name: 'Beto'),
      ];
      await h.pump(tester, size: const Size(1100, 800));
      await tapAndSettle(tester, find.text('Mensagens').last);
      await tapAndSettle(tester, find.byTooltip('Nova conversa'));
      await tester.enterText(
        find.descendant(
          of: find.byType(SearchBar),
          matching: find.byType(EditableText),
        ),
        'be',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text('Beto').last);
      expect(h.chat.opened, ['u-beto']);
      expect(uri(tester), '/messages/$convId');
    });

    testWidgets(
      'o botão Mensagem no perfil abre a conversa e voltar leva à lista',
      (tester) async {
        final h = harness();
        h.profiles.profiles['u-beto'] = fakeProfile(name: 'Beto');
        await h.pump(tester);
        await goTo(tester, '/users/u-beto');
        await tapAndSettle(
          tester,
          find.widgetWithText(OutlinedButton, 'Mensagem'),
        );
        expect(uri(tester), '/messages/$convId');
        await tapAndSettle(tester, find.byType(BackButton));
        expect(uri(tester), '/messages');
      },
    );
  });

  group('conversa: bolhas e composer', () {
    // A coluna da conversa: a janela menos o rail, os divisores e, lado a lado, a lista de 320.
    for (final (width, column) in [
      (1700.0, 1700.0 - 80 - 1 - 320 - 1),
      (1100.0, 1100.0 - 80 - 1 - 320 - 1),
      (400.0, 400.0),
    ]) {
      testWidgets(
        'as bolhas têm no máximo 560 dp ou 80% da coluna (janela ${width.toInt()})',
        (tester) async {
          final h = harness();
          h.chat.history[convId] = [
            serverMessage('m1', text: 'palavra ' * 80, minute: 1),
            serverMessage('m2', text: 'minha ' * 80, minute: 2, mine: true),
          ];
          await h.pump(tester, size: Size(width, 900));
          await goTo(tester, '/messages/$convId');
          final limit = (column * 0.8).clamp(0.0, 560.0);
          for (final text in ['palavra palavra', 'minha minha']) {
            final w = tester.getSize(find.textContaining(text)).width;
            expect(w, lessThanOrEqualTo(limit), reason: 'janela $width');
            expect(
              w,
              // O texto quebra por palavra e tem recuo dos dois lados: não preenche tudo.
              greaterThan(limit * 0.7),
              reason: 'usa a largura permitida',
            );
          }
        },
      );
    }

    testWidgets(
      'as minhas usam o container primário; as recebidas, a superfície',
      (tester) async {
        final h = harness();
        h.chat.history[convId] = [
          serverMessage('m1', text: 'recebida', minute: 1),
          serverMessage('m2', text: 'minha', minute: 2, mine: true),
        ];
        await h.pump(tester);
        await goTo(tester, '/messages/$convId');
        final scheme = Theme.of(tester.element(find.byType(Scaffold).first))
            .colorScheme;
        Color? colorOf(String text) {
          final box = find
              .ancestor(of: find.text(text), matching: find.byType(Container))
              .first;
          return ((tester.widget<Container>(box).decoration) as BoxDecoration?)
              ?.color;
        }

        expect(colorOf('minha'), scheme.primaryContainer);
        expect(colorOf('recebida'), scheme.surfaceContainerHighest);
      },
    );

    testWidgets('Enter insere uma linha; Ctrl+Enter e Cmd+Enter enviam', (
      tester,
    ) async {
      final h = harness();
      await h.pump(tester, size: const Size(1100, 800));
      await goTo(tester, '/messages/$convId');
      await tester.tap(composer);
      await tester.enterText(composer, 'linha 1');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(h.chatServer.sends, isEmpty, reason: 'Enter sozinho não envia');

      await tester.enterText(composer, 'primeira');
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(h.chatServer.sends.map((s) => s['content']), ['primeira']);
      expect(tester.widget<TextField>(composer).controller!.text, isEmpty);

      await tester.enterText(composer, 'segunda');
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();
      expect(h.chatServer.sends.map((s) => s['content']), [
        'primeira',
        'segunda',
      ]);
    });

    testWidgets('Ctrl+Enter com o campo vazio não envia', (tester) async {
      final h = harness();
      await h.pump(tester, size: const Size(1100, 800));
      await goTo(tester, '/messages/$convId');
      await tester.tap(composer);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(h.chatServer.sends, isEmpty);
    });

    testWidgets('o botão de enviar continua acessível', (tester) async {
      final h = harness();
      await h.pump(tester);
      await goTo(tester, '/messages/$convId');
      await tester.enterText(composer, 'oi');
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.widgetWithIcon(IconButton, Icons.send));
      expect(h.chatServer.sends, hasLength(1));
    });
  });

  group('conversa: rolagem com mensagens novas', () {
    AppHarness longChat() {
      final h = harness();
      h.chat.pageSize = 200;
      h.chat.history[convId] = [
        for (var i = 0; i < 60; i++)
          serverMessage(
            'm$i',
            text: 'mensagem número $i',
            minute: i,
            mine: i.isOdd,
          ),
      ];
      return h;
    }

    Future<void> scrollUp(WidgetTester tester) async {
      await tester.drag(find.byType(ListView).last, const Offset(0, 600));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'lendo o histórico: a nova não arrasta, mostra "Novas mensagens" e nada pula',
      (tester) async {
        final h = longChat();
        await h.pump(tester, size: const Size(400, 700));
        await goTo(tester, '/messages/$convId');
        await scrollUp(tester);
        // Uma mensagem qualquer visível e a posição dela na tela.
        final probe = find.textContaining('mensagem número').first;
        final label = tester.widget<Text>(probe).data!;
        final before = tester.getTopLeft(find.text(label)).dy;
        expect(find.text('Novas mensagens'), findsNothing);

        h.chatServer.incoming('chegou agora', minute: 90);
        await tester.pumpAndSettle();

        expect(find.text('Novas mensagens'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text(label)).dy,
          closeTo(before, 1),
          reason: 'o que a pessoa lia não saiu do lugar',
        );
        expect(find.text('chegou agora'), findsNothing, reason: 'fora da tela');

        await tapAndSettle(tester, find.text('Novas mensagens'));
        expect(find.text('chegou agora'), findsOneWidget);
        expect(find.text('Novas mensagens'), findsNothing);
      },
    );

    testWidgets('rolar até o fim por conta própria esconde o botão', (
      tester,
    ) async {
      final h = longChat();
      await h.pump(tester, size: const Size(400, 700));
      await goTo(tester, '/messages/$convId');
      await scrollUp(tester);
      h.chatServer.incoming('nova', minute: 90);
      await tester.pumpAndSettle();
      expect(find.text('Novas mensagens'), findsOneWidget);
      await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(find.text('Novas mensagens'), findsNothing);
      expect(find.text('nova'), findsOneWidget);
    });

    testWidgets('perto do fim: acompanha a chegada, sem botão', (tester) async {
      final h = longChat();
      await h.pump(tester, size: const Size(400, 700));
      await goTo(tester, '/messages/$convId');
      h.chatServer.incoming('chegou', minute: 90);
      await tester.pumpAndSettle();
      expect(find.text('chegou'), findsOneWidget);
      expect(find.text('Novas mensagens'), findsNothing);
    });

    testWidgets(
      'enviar a própria mensagem leva ao fim, mesmo lendo o histórico',
      (tester) async {
        final h = longChat();
        await h.pump(tester, size: const Size(400, 700));
        await goTo(tester, '/messages/$convId');
        await scrollUp(tester);
        await tester.enterText(composer, 'minha nova');
        await tester.pumpAndSettle();
        await tapAndSettle(tester, find.widgetWithIcon(IconButton, Icons.send));
        expect(find.text('minha nova'), findsOneWidget);
        expect(find.text('Novas mensagens'), findsNothing);
      },
    );

    testWidgets(
      'carregar histórico antigo não mostra o botão nem move o que se lê',
      (tester) async {
        final h = harness();
        h.chat.pageSize = 20;
        h.chat.history[convId] = [
          for (var i = 0; i < 80; i++)
            serverMessage('m$i', text: 'mensagem número $i', minute: i),
        ];
        await h.pump(tester, size: const Size(400, 700));
        await goTo(tester, '/messages/$convId');
        for (var i = 0; i < 6; i++) {
          await tester.drag(find.byType(ListView).last, const Offset(0, 800));
          await tester.pumpAndSettle();
        }
        expect(find.text('Novas mensagens'), findsNothing);
        expect(
          h.chat.messageCalls.length,
          greaterThan(1),
          reason: 'páginas antigas foram pedidas',
        );
      },
    );

    testWidgets(
      'mensagem repetida na reconexão não duplica nem mostra o botão',
      (tester) async {
        final h = longChat();
        await h.pump(tester, size: const Size(400, 700));
        await goTo(tester, '/messages/$convId');
        final m = h.chatServer.incoming('uma só', minute: 90, id: 'dup');
        h.transport.emit(MessageReceived(messageJson(m)));
        await tester.pumpAndSettle();
        expect(find.text('uma só'), findsOneWidget);
      },
    );
  });

  group('layout', () {
    for (final (size, scale) in [
      (const Size(360, 800), 2.0),
      (const Size(390, 844), 1.0),
      (const Size(1440, 900), 1.0),
    ]) {
      testWidgets(
        '${size.width.toInt()} px, texto $scale×: lista e conversa sem overflow',
        (tester) async {
          final h = harness();
          await h.pump(tester, size: size, textScale: scale);
          await tapAndSettle(tester, find.text('Mensagens').last);
          expect(tester.takeException(), isNull);
          await goTo(tester, '/messages/conv-2');
          expect(tester.takeException(), isNull);
          await tester.enterText(composer, 'um texto ' * 30);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
