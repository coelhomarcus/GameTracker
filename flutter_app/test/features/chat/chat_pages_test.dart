import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gametracker/features/chat/application/chat_controller.dart';
import 'package:gametracker/features/chat/presentation/chat_room_page.dart';
import 'package:gametracker/core/models/user_summary.dart';
import 'package:gametracker/core/network/app_exception.dart';
import 'package:gametracker/core/realtime/chat_transport.dart';
import 'package:gametracker/features/chat/data/chat_models.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_chat.dart';
import '../../support/fake_feed.dart';
import '../../support/fake_profiles.dart';
import '../../support/fake_transport.dart';
import '../../support/harness.dart';

LastMessage last(String text, {String from = 'u-beto', int minute = 5}) =>
    LastMessage(
      id: 'l$minute',
      content: text,
      senderId: from,
      createdAt: DateTime.now().subtract(Duration(minutes: minute)),
    );

Finder get composer => find.widgetWithText(TextField, 'Mensagem');
Finder get sendButton => find.widgetWithIcon(IconButton, Icons.send);

Future<AppHarness> openMessages(
  WidgetTester tester, {
  AppHarness? harness,
  Size size = const Size(400, 900),
}) async {
  final h = harness ?? AppHarness();
  await h.pump(tester, size: size);
  await tapAndSettle(tester, find.text('Mensagens').last);
  return h;
}

Future<AppHarness> openRoom(
  WidgetTester tester, {
  AppHarness? harness,
  Size size = const Size(400, 900),
}) async {
  final h = harness ?? AppHarness();
  await h.pump(tester, size: size);
  await goTo(tester, '/messages/$convId');
  return h;
}

Future<void> typeAndSend(WidgetTester tester, String text) async {
  await tester.enterText(composer, text);
  await tester.pumpAndSettle();
  await tapAndSettle(tester, sendButton);
}

void main() {
  group('lista de conversas', () {
    testWidgets('mostra a pessoa, a prévia (com "Você:" nas minhas) e a hora', (
      tester,
    ) async {
      final h = AppHarness();
      h.chat.list = [
        conversation(id: 'a', last: last('oi, tudo bem?')),
        conversation(
          id: 'b',
          other: ana,
          last: last('combinado', from: meId, minute: 40),
        ),
      ];
      await openMessages(tester, harness: h);
      expect(find.text('beto'), findsOneWidget);
      expect(find.text('oi, tudo bem?'), findsOneWidget);
      expect(find.text('Você: combinado'), findsOneWidget);
      expect(find.text('há 5 min'), findsOneWidget);
    });

    testWidgets('não lida: ponto na linha e selo com a contagem na aba', (
      tester,
    ) async {
      final h = AppHarness();
      h.chat.list = [
        conversation(id: 'a', unread: true, last: last('nova!')),
        conversation(
          id: 'b',
          other: ana,
          unread: true,
          last: last('outra', minute: 9),
        ),
        conversation(
          id: 'c',
          other: const UserSummary(id: 'u-cris', username: 'cris'),
          last: last('lida', minute: 20),
        ),
      ];
      await h.pump(tester);
      expect(
        find.widgetWithText(Badge, '2'),
        findsOneWidget,
        reason: 'selo na aba, sem abrir Mensagens',
      );
      await tapAndSettle(tester, find.text('Mensagens').last);
      expect(find.byType(Badge), findsOneWidget);
    });

    testWidgets('sem conversas: estado vazio com ação', (tester) async {
      final h = AppHarness();
      h.chat.list = [];
      await openMessages(tester, harness: h);
      expect(find.text('Nenhuma conversa ainda'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Nova conversa'),
        findsOneWidget,
      );
      expect(find.byType(Badge), findsNothing);
    });

    testWidgets('erro ao carregar não é lista vazia e permite tentar de novo', (
      tester,
    ) async {
      final h = AppHarness();
      h.chat.conversationsError = const NetworkException();
      await openMessages(tester, harness: h);
      expect(find.textContaining('Sem conexão'), findsOneWidget);
      expect(find.text('Nenhuma conversa ainda'), findsNothing);
      h.chat.conversationsError = null;
      await tapAndSettle(tester, find.text('Tentar de novo'));
      expect(find.text('beto'), findsOneWidget);
    });

    testWidgets('tocar abre a conversa', (tester) async {
      final h = AppHarness();
      h.chat.history[convId] = [serverMessage('m1', text: 'olá!', minute: 1)];
      await openMessages(tester, harness: h);
      await tapAndSettle(tester, find.text('beto'));
      expect(find.text('olá!'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Mensagem'), findsOneWidget);
    });

    testWidgets(
      'em tela larga: lista e conversa lado a lado, sem botão de voltar',
      (tester) async {
        final h = AppHarness();
        h.chat.history[convId] = [serverMessage('m1', text: 'olá!', minute: 1)];
        await openMessages(tester, harness: h, size: const Size(1100, 800));
        expect(find.text('Selecione uma conversa'), findsOneWidget);

        await tapAndSettle(tester, find.text('beto'));
        expect(find.text('olá!'), findsOneWidget);
        expect(find.text('Selecione uma conversa'), findsNothing);
        expect(
          find.byType(BackButton),
          findsNothing,
          reason: 'painel de detalhe, não uma rota',
        );
        expect(
          find.text('Mensagens'),
          findsWidgets,
          reason: 'a lista continua visível',
        );
      },
    );

    testWidgets('puxar para atualizar refaz a consulta', (tester) async {
      final h = await openMessages(tester);
      final before = h.chat.conversationsCalls;
      await tester.fling(
        find.byType(Scrollable).last,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(h.chat.conversationsCalls, before + 1);
    });
  });

  group('nova conversa', () {
    testWidgets('escolher uma pessoa abre (ou reaproveita) a conversa', (
      tester,
    ) async {
      final h = AppHarness();
      h.chat.list = [];
      h.profiles.searchResult = [
        fakePerson(id: 'u-beto', username: 'beto', name: 'Beto Silva'),
      ];
      await openMessages(tester, harness: h);
      h.chat.list = [conversation(other: beto)];

      await tapAndSettle(
        tester,
        find.widgetWithText(FloatingActionButton, 'Nova conversa'),
      );
      await tester.enterText(
        find.descendant(
          of: find.byType(SearchBar),
          matching: find.byType(EditableText),
        ),
        'be',
      );
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(
        find.text('Seguir'),
        findsNothing,
        reason: 'no seletor não há botão de seguir',
      );
      await tapAndSettle(tester, find.text('Beto Silva'));

      expect(h.chat.opened, ['u-beto']);
      expect(
        find.widgetWithText(TextField, 'Mensagem'),
        findsOneWidget,
        reason: 'abriu a conversa',
      );
    });

    testWidgets('o botão Mensagem no perfil abre a conversa com a pessoa', (
      tester,
    ) async {
      final h = AppHarness();
      h.profiles.profiles['u-beto'] = fakeProfile(name: 'Beto');
      await h.pump(tester);
      await goTo(tester, '/users/u-beto');
      await tapAndSettle(
        tester,
        find.widgetWithText(OutlinedButton, 'Mensagem'),
      );
      expect(h.chat.opened, ['u-beto']);
      expect(find.widgetWithText(TextField, 'Mensagem'), findsOneWidget);
    });

    testWidgets('o perfil próprio não tem botão Mensagem', (tester) async {
      final h = AppHarness();
      h.profiles.profiles['u1'] = fakeProfile(
        id: 'u1',
        username: 'ana',
        name: 'ANA',
      );
      await h.pump(tester);
      await tapAndSettle(tester, find.text('Perfil').last);
      expect(find.widgetWithText(OutlinedButton, 'Mensagem'), findsNothing);
    });

    testWidgets('falha ao abrir a conversa avisa e não navega', (tester) async {
      final h = AppHarness();
      h.profiles.profiles['u-beto'] = fakeProfile(name: 'Beto');
      await h.pump(tester);
      await goTo(tester, '/users/u-beto');
      h.chat.conversationsError = const NetworkException();
      await tapAndSettle(
        tester,
        find.widgetWithText(OutlinedButton, 'Mensagem'),
      );
      expect(find.textContaining('Sem conexão'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Mensagem'), findsNothing);
    });
  });

  group('conversa: histórico', () {
    testWidgets(
      'mostra as mensagens com separador de dia e a hora do fim do grupo',
      (tester) async {
        final h = AppHarness();
        h.chat.history[convId] = [
          serverMessage('m1', text: 'primeira', minute: 1),
          serverMessage('m2', text: 'segunda', minute: 2),
          serverMessage('m3', text: 'minha resposta', minute: 3, mine: true),
        ];
        await openRoom(tester, harness: h);
        expect(find.text('primeira'), findsOneWidget);
        expect(find.text('segunda'), findsOneWidget);
        expect(find.text('minha resposta'), findsOneWidget);
        expect(find.text('Início da conversa'), findsOneWidget);
        // Minha mensagem à direita, a da outra pessoa à esquerda.
        final mineX = tester.getCenter(find.text('minha resposta')).dx;
        final theirsX = tester.getCenter(find.text('primeira')).dx;
        expect(mineX, greaterThan(theirsX));
      },
    );

    testWidgets('conversa nova: convida a dizer oi', (tester) async {
      await openRoom(tester);
      expect(find.text('Diga oi para beto'), findsOneWidget);
    });

    testWidgets(
      'histórico longo carrega mais antigas ao rolar para cima, sem duplicar',
      (tester) async {
        final h = AppHarness();
        h.chat.pageSize = 10;
        h.chat.history[convId] = [
          for (var i = 1; i <= 25; i++)
            serverMessage(
              'm${i.toString().padLeft(2, '0')}',
              text: 'msg $i',
              minute: i,
            ),
        ];
        await openRoom(tester, harness: h, size: const Size(400, 500));
        expect(find.text('msg 25'), findsOneWidget);

        for (var i = 0; i < 8; i++) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, 500),
          );
          await tester.pumpAndSettle();
        }
        expect(
          find.text('Início da conversa', skipOffstage: false),
          findsOneWidget,
        );
        // A lista é lazy: confere o estado (todas as 25, sem repetir) e não só o que está construído.
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ChatRoomView)),
        );
        final messages = container
            .read(chatControllerProvider(convId))
            .requireValue
            .messages;
        expect(messages.length, 25);
        expect(
          messages.map((m) => m.id).toSet().length,
          25,
          reason: 'sem duplicatas',
        );
        expect(
          h.chat.messageCalls.where((c) => c.$2 != null).length,
          2,
          reason: '25 mensagens em páginas de 10',
        );
      },
    );

    testWidgets('conversa inexistente mostra erro com saída', (tester) async {
      final h = AppHarness();
      h.chat.list = [];
      await h.pump(tester);
      await goTo(tester, '/messages/nao-existe');
      expect(find.text('Não encontrado.'), findsOneWidget);
    });
  });

  group('conversa: enviar', () {
    testWidgets(
      'a mensagem aparece na hora, a caixa limpa, e o horário vem com o ACK',
      (tester) async {
        final h = AppHarness();
        await openRoom(tester, harness: h);
        await typeAndSend(tester, 'Olá, Beto!');

        expect(find.text('Olá, Beto!'), findsOneWidget);
        expect(tester.widget<TextField>(composer).controller!.text, isEmpty);
        expect(find.text('Enviando…'), findsNothing, reason: 'o ACK já chegou');
        expect(h.chatServer.stored, 1);
        expect(find.byIcon(Icons.done), findsOneWidget);
      },
    );

    testWidgets('enviar fica desabilitado sem texto e com só espaços', (
      tester,
    ) async {
      await openRoom(tester);
      expect(tester.widget<IconButton>(sendButton).onPressed, isNull);
      await tester.enterText(composer, '   ');
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(sendButton).onPressed, isNull);
      await tester.enterText(composer, 'ok');
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(sendButton).onPressed, isNotNull);
    });

    testWidgets('perto do limite aparece o contador', (tester) async {
      await openRoom(tester);
      await tester.enterText(composer, 'x' * 1850);
      await tester.pumpAndSettle();
      expect(find.text('1850/2000'), findsOneWidget);
    });

    testWidgets('evento antes do ACK não duplica a mensagem na tela', (
      tester,
    ) async {
      final h = AppHarness();
      await openRoom(tester, harness: h);
      h.chatServer.eventBeforeAck = true;
      await typeAndSend(tester, 'uma só');
      expect(find.text('uma só'), findsOneWidget);
    });

    testWidgets('ACK perdido: mostra "Confirmando…" e confirma sem duplicar', (
      tester,
    ) async {
      final h = AppHarness();
      await openRoom(tester, harness: h);
      h.chatServer.dropAcks = 1;
      await tester.enterText(composer, 'importante');
      await tester.pumpAndSettle();
      await tester.tap(sendButton);
      await tester.pump();
      await tester.pump();
      expect(find.text('Confirmando…'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Confirmando…'), findsNothing);
      expect(find.text('importante'), findsOneWidget);
      expect(
        h.chatServer.stored,
        1,
        reason: 'o reenvio não duplicou no servidor',
      );
      expect(h.chatServer.sends.length, 2);
    });

    testWidgets(
      'não entregue: o texto continua, com "Tentar de novo" e "Descartar"',
      (tester) async {
        final h = AppHarness();
        await openRoom(tester, harness: h);
        h.chatServer.ignoreSends = 3;
        await typeAndSend(tester, 'não saiu');
        await tester.pump(const Duration(seconds: 10));
        await tester.pumpAndSettle();

        expect(
          find.text('não saiu'),
          findsOneWidget,
          reason: 'o texto não se perde',
        );
        expect(find.text('Não enviada'), findsOneWidget);
        expect(find.text('Tentar de novo'), findsOneWidget);

        await tapAndSettle(tester, find.text('Tentar de novo'));
        expect(find.text('Não enviada'), findsNothing);
        expect(find.text('não saiu'), findsOneWidget);
        expect(h.chatServer.stored, 1);
      },
    );

    testWidgets('descartar remove a mensagem não entregue', (tester) async {
      final h = AppHarness();
      await openRoom(tester, harness: h);
      h.chatServer.ignoreSends = 3;
      await typeAndSend(tester, 'descartar');
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text('Descartar'));
      expect(find.text('descartar'), findsNothing);
    });

    testWidgets('recusa do servidor aparece como não enviada', (tester) async {
      final h = AppHarness();
      await openRoom(tester, harness: h);
      h.chatServer.rejectWith = 'Conversa não encontrada';
      await typeAndSend(tester, 'negada');
      await tester.pumpAndSettle();
      expect(find.text('Não enviada'), findsOneWidget);
    });

    testWidgets('o rascunho sobrevive a sair e voltar da conversa', (
      tester,
    ) async {
      final h = AppHarness();
      await openRoom(tester, harness: h);
      await tester.enterText(composer, 'ainda estou escrevendo');
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await goTo(tester, '/messages/$convId');
      expect(
        tester.widget<TextField>(composer).controller!.text,
        'ainda estou escrevendo',
      );
    });

    testWidgets('depois de enviar, o rascunho some', (tester) async {
      final h = AppHarness();
      await openRoom(tester, harness: h);
      await typeAndSend(tester, 'enviada');
      await goTo(tester, '/messages');
      await goTo(tester, '/messages/$convId');
      expect(tester.widget<TextField>(composer).controller!.text, isEmpty);
    });
  });

  group('conversa: conexão', () {
    testWidgets(
      'sem conexão: aviso, mensagem na fila e entrega única ao reconectar',
      (tester) async {
        final h = AppHarness();
        await openRoom(tester, harness: h);
        h.transport.defaultOutcome = const ConnectFail();
        h.transport.drop();
        await tester.pumpAndSettle();
        expect(find.textContaining('Sem conexão'), findsOneWidget);
        expect(find.text('Tentar agora'), findsOneWidget);

        await typeAndSend(tester, 'na fila');
        expect(find.text('na fila'), findsOneWidget);
        expect(find.text('Enviando…'), findsOneWidget);
        expect(h.chatServer.sends, isEmpty);

        h.transport.defaultOutcome = const ConnectOk();
        await tapAndSettle(tester, find.text('Tentar agora'));
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(find.textContaining('Sem conexão'), findsNothing);
        expect(find.text('Enviando…'), findsNothing);
        expect(h.chatServer.stored, 1);
        expect(find.text('na fila'), findsOneWidget);
      },
    );

    testWidgets('o que chegou durante a queda aparece depois de reconectar', (
      tester,
    ) async {
      final h = AppHarness();
      h.chat.history[convId] = [serverMessage('m1', text: 'antes', minute: 1)];
      await openRoom(tester, harness: h);
      h.transport.drop();
      h.chat.history[convId]!.add(
        serverMessage('m2', text: 'durante a queda', minute: 2),
      );
      await tester.pumpAndSettle();
      expect(find.text('durante a queda'), findsOneWidget);
      expect(find.text('antes'), findsOneWidget);
    });
  });

  group('conversa: ao vivo', () {
    testWidgets('mensagem da outra pessoa aparece na hora', (tester) async {
      final h = AppHarness();
      await openRoom(tester, harness: h);
      h.chatServer.incoming('chegou agora');
      await tester.pumpAndSettle();
      expect(find.text('chegou agora'), findsOneWidget);
    });

    testWidgets(
      'digitando e online aparecem sob o nome; desconhecido não afirma offline',
      (tester) async {
        final h = AppHarness();
        await openRoom(tester, harness: h);
        expect(find.text('online'), findsNothing);
        expect(find.text('digitando…'), findsNothing);

        h.transport.emit(const PresenceChanged(userId: 'u-beto', online: true));
        await tester.pumpAndSettle();
        expect(find.text('online'), findsOneWidget);

        h.transport.emit(
          const TypingChanged(
            conversationId: convId,
            userId: 'u-beto',
            typing: true,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('digitando…'), findsOneWidget);
        expect(
          find.text('online'),
          findsNothing,
          reason: 'digitando tem prioridade',
        );

        await tester.pump(const Duration(seconds: 5));
        expect(
          find.text('digitando…'),
          findsNothing,
          reason: 'expira sem o aviso de parada',
        );
      },
    );

    testWidgets('snapshot de presença inicial mostra online', (tester) async {
      final h = AppHarness();
      h.transport.online = ['u-beto'];
      await openRoom(tester, harness: h);
      expect(find.text('online'), findsOneWidget);
    });

    testWidgets('escrever avisa a outra pessoa (uma vez na janela)', (
      tester,
    ) async {
      final h = AppHarness();
      await openRoom(tester, harness: h);
      await tester.enterText(composer, 'o');
      await tester.enterText(composer, 'ol');
      await tester.enterText(composer, 'olá');
      await tester.pump();
      expect(h.transport.sent.where((e) => e.$1 == 'typing:start').length, 1);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('abrir a conversa marca como lida e zera o selo', (
      tester,
    ) async {
      final h = AppHarness();
      h.chat.list = [conversation(unread: true, last: last('nova'))];
      h.chat.history[convId] = [serverMessage('m1', text: 'nova', minute: 1)];
      await h.pump(tester);
      expect(find.widgetWithText(Badge, '1'), findsOneWidget);

      await goTo(tester, '/messages/$convId');
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(h.chat.markReadCalls, [convId]);
      await goTo(tester, '/messages');
      expect(find.byType(Badge), findsNothing);
    });

    testWidgets('titular leva ao perfil da outra pessoa', (tester) async {
      final h = AppHarness();
      h.profiles.profiles['u-beto'] = fakeProfile(name: 'Beto');
      await openRoom(tester, harness: h);
      await tapAndSettle(tester, find.text('beto').first);
      expect(find.text('@beto'), findsOneWidget);
    });
  });

  testWidgets('layout a 360 px com texto 200% não estoura', (tester) async {
    final h = AppHarness();
    h.chat.history[convId] = [
      serverMessage('m1', text: 'Uma mensagem bem comprida ' * 6, minute: 1),
      serverMessage(
        'm2',
        text: 'e a resposta também é longa ' * 5,
        minute: 2,
        mine: true,
      ),
    ];
    await h.pump(tester, size: const Size(360, 800), textScale: 2.0);
    await goTo(tester, '/messages/$convId');
    expect(tester.takeException(), isNull);
  });
}
