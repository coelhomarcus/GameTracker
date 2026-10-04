import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gametracker/core/realtime/chat_connection.dart';
import 'package:gametracker/core/realtime/chat_transport.dart';

import '../support/fake_transport.dart';

class Harness {
  Harness({this._refreshResult = TokenRefresh.refreshed}) {
    connection = ChatConnection(
      transport: transport,
      accessToken: () async => token,
      refresh: (used) async {
        refreshCalls.add(used);
        if (_refreshResult == TokenRefresh.refreshed) {
          token = 'novo-${refreshCalls.length}';
        }
        return _refreshResult;
      },
      backoff: (attempt) => Duration(seconds: attempt + 1),
    );
    connection.states.listen(states.add);
    connection.resynced.listen((_) => resyncs++);
  }

  final transport = FakeChatTransport();
  late final ChatConnection connection;
  String? token = 'token-0';
  final TokenRefresh _refreshResult;
  final refreshCalls = <String?>[];
  final states = <ChatConnectionState>[];
  int resyncs = 0;

  List<ChatConnectionStatus> get statuses =>
      states.map((s) => s.status).toList();
}

void run(void Function(FakeAsync async, Harness h) body, {Harness? harness}) {
  fakeAsync((async) {
    final h = harness ?? Harness();
    body(async, h);
  });
}

void main() {
  test('conecta com o token atual e avisa que sincronizou', () {
    run((async, h) {
      h.connection.start();
      async.flushMicrotasks();
      expect(h.transport.connectTokens, ['token-0']);
      expect(h.connection.state.isConnected, isTrue);
      expect(h.statuses, [
        ChatConnectionStatus.connecting,
        ChatConnectionStatus.connected,
      ]);
      expect(h.resyncs, 1);
    });
  });

  test('iniciar duas vezes não abre duas conexões', () {
    run((async, h) {
      h.connection.start();
      h.connection.start();
      async.flushMicrotasks();
      expect(h.transport.connectTokens.length, 1);
    });
  });

  test(
    'servidor recusa o token: renova a sessão e reconecta com o token novo',
    () {
      run((async, h) {
        h.transport.outcomes.add(const ConnectAuthError());
        h.connection.start();
        async.flushMicrotasks();
        expect(h.refreshCalls, [
          'token-0',
        ], reason: 'a renovação recebe o token que foi recusado');
        expect(h.transport.connectTokens, ['token-0', 'novo-1']);
        expect(h.connection.state.isConnected, isTrue);
      });
    },
  );

  test('sessão encerrada ao renovar: para de vez, sem insistir', () {
    run((async, h) {
      final harness = Harness(refreshResult: TokenRefresh.sessionEnded);
      harness.transport.defaultOutcome = const ConnectAuthError();
      harness.connection.start();
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 2));
      expect(harness.transport.connectTokens.length, 1);
      expect(harness.connection.state.status, ChatConnectionStatus.stopped);
    });
  });

  test('renovar a cada tentativa não vira um laço apertado: depois de 2 vai ao backoff', () {
    run((async, h) {
      h.transport.defaultOutcome = const ConnectAuthError();
      h.connection.start();
      async.flushMicrotasks();
      // 1 tentativa inicial + 2 repetições imediatas, depois espera.
      expect(h.transport.connectTokens.length, 3);
      expect(h.connection.state.status, ChatConnectionStatus.waiting);
    });
  });

  test('falha de rede: espera com backoff crescente e reconecta', () {
    run((async, h) {
      h.transport.outcomes.addAll([const ConnectFail(), const ConnectFail()]);
      h.connection.start();
      async.flushMicrotasks();
      expect(h.transport.connectTokens.length, 1);
      expect(h.connection.state.status, ChatConnectionStatus.waiting);
      expect(h.connection.state.attempt, 1);

      async.elapse(const Duration(milliseconds: 900));
      expect(
        h.transport.connectTokens.length,
        1,
        reason: 'primeira espera é de 1 s',
      );
      async.elapse(const Duration(milliseconds: 200));
      expect(h.transport.connectTokens.length, 2);
      expect(h.connection.state.attempt, 2);

      async.elapse(const Duration(milliseconds: 1800));
      expect(
        h.transport.connectTokens.length,
        2,
        reason: 'segunda espera é de 2 s',
      );
      async.elapse(const Duration(milliseconds: 200));
      expect(h.transport.connectTokens.length, 3);
      expect(h.connection.state.isConnected, isTrue);
      expect(
        h.connection.state.attempt,
        0,
        reason: 'conectou: zera as tentativas',
      );
    });
  });

  test('queda depois de conectado: reconecta na hora, sem backoff', () {
    run((async, h) {
      h.connection.start();
      async.flushMicrotasks();
      h.transport.drop();
      async.flushMicrotasks();
      expect(h.transport.connectTokens.length, 2);
      expect(h.connection.state.isConnected, isTrue);
      expect(
        h.resyncs,
        2,
        reason: 'cada reconexão pede sincronização do histórico',
      );
    });
  });

  test(
    'entra nas salas desejadas e reentra em todas depois de cada reconexão',
    () {
      run((async, h) {
        h.connection.start();
        async.flushMicrotasks();
        unawaited(h.connection.joinRoom('c1'));
        unawaited(h.connection.joinRoom('c2'));
        async.flushMicrotasks();
        expect(h.transport.joins, ['c1', 'c2']);

        h.transport.drop();
        async.flushMicrotasks();
        expect(h.transport.joins, [
          'c1',
          'c2',
          'c1',
          'c2',
        ], reason: 'o servidor esquece as salas ao reconectar');
      });
    },
  );

  test('sala pedida sem conexão é entrada quando a conexão volta', () {
    run((async, h) {
      h.transport.outcomes.add(const ConnectFail());
      h.connection.start();
      async.flushMicrotasks();
      bool? joined;
      h.connection.joinRoom('c1').then((v) => joined = v);
      async.flushMicrotasks();
      expect(joined, isFalse, reason: 'ainda sem conexão');
      expect(h.transport.joins, isEmpty);

      async.elapse(const Duration(seconds: 2));
      expect(h.transport.joins, ['c1']);
    });
  });

  test('sala recusada pelo servidor deixa de ser desejada', () {
    run((async, h) {
      h.transport.rejectedRooms.add('c1');
      h.connection.start();
      async.flushMicrotasks();
      bool? joined;
      h.connection.joinRoom('c1').then((v) => joined = v);
      async.flushMicrotasks();
      expect(joined, isFalse);

      h.transport.drop();
      async.flushMicrotasks();
      expect(h.transport.joins, [
        'c1',
      ], reason: 'não tenta de novo uma sala recusada');
    });
  });

  test('sair da sala avisa o servidor e não reentra depois', () {
    run((async, h) {
      h.connection.start();
      async.flushMicrotasks();
      unawaited(h.connection.joinRoom('c1'));
      async.flushMicrotasks();
      h.connection.leaveRoom('c1');
      expect(h.transport.sent.single.$1, 'conversation:leave');
      expect(h.transport.sent.single.$2['conversationId'], 'c1');
      h.transport.drop();
      async.flushMicrotasks();
      expect(h.transport.joins, ['c1']);
    });
  });

  test('ACK de entrada que não chega na reconexão derruba a conexão e tenta de novo', () {
    run((async, h) {
      var joinCalls = 0;
      h.transport.onRequest = (event, payload) {
        if (event == 'conversation:join' && ++joinCalls == 2) {
          // 1ª: entrada normal. 2ª: reentrada depois da queda, sem resposta.
          throw const RequestTimeoutException();
        }
        return {'ok': true};
      };
      h.connection.start();
      async.flushMicrotasks();
      unawaited(h.connection.joinRoom('c1'));
      async.flushMicrotasks();
      expect(joinCalls, 1);

      h.transport.drop();
      async.flushMicrotasks();
      // A reentrada deu timeout: a conexão não presta, é derrubada e refeita (sem backoff).
      async.elapse(const Duration(seconds: 3));
      expect(h.transport.connectTokens.length, 3);
      expect(h.connection.state.isConnected, isTrue);
      expect(joinCalls, 3, reason: 'na terceira conexão a entrada funcionou');
    });
  });

  test('reconnectNow encurta a espera do backoff', () {
    run((async, h) {
      h.transport.outcomes.add(const ConnectFail());
      h.connection.start();
      async.flushMicrotasks();
      expect(h.connection.state.status, ChatConnectionStatus.waiting);

      h.connection.reconnectNow();
      async.flushMicrotasks();
      expect(h.transport.connectTokens.length, 2, reason: 'não esperou o 1 s');
      expect(h.connection.state.isConnected, isTrue);
    });
  });

  test('reconnectNow com a conexão parada recomeça', () {
    run((async, h) {
      h.connection.reconnectNow();
      async.flushMicrotasks();
      expect(h.connection.state.isConnected, isTrue);
    });
  });

  test('stop fecha o socket, esquece as salas e para de tentar', () {
    run((async, h) {
      h.connection.start();
      async.flushMicrotasks();
      unawaited(h.connection.joinRoom('c1'));
      async.flushMicrotasks();

      unawaited(h.connection.stop());
      async.flushMicrotasks();
      expect(h.connection.state.status, ChatConnectionStatus.stopped);
      expect(h.transport.isConnected, isFalse);
      async.elapse(const Duration(minutes: 1));
      expect(h.transport.connectTokens.length, 1);

      h.connection.start();
      async.flushMicrotasks();
      expect(h.transport.joins, [
        'c1',
      ], reason: 'a sala da sessão anterior não volta');
    });
  });

  test('stop durante o backoff cancela a próxima tentativa', () {
    run((async, h) {
      h.transport.defaultOutcome = const ConnectFail();
      h.connection.start();
      async.flushMicrotasks();
      unawaited(h.connection.stop());
      async.elapse(const Duration(minutes: 1));
      expect(h.transport.connectTokens.length, 1);
    });
  });

  test('sem token (sessão acabou): para sem tentar conectar', () {
    run((async, h) {
      h.token = null;
      h.connection.start();
      async.flushMicrotasks();
      expect(h.transport.connectTokens, isEmpty);
      expect(h.connection.state.status, ChatConnectionStatus.stopped);
    });
  });

  test('verify: conexão que responde segue como está', () {
    run((async, h) {
      h.connection.start();
      async.flushMicrotasks();
      unawaited(h.connection.joinRoom('c1'));
      async.flushMicrotasks();
      unawaited(h.connection.verify());
      async.flushMicrotasks();
      expect(h.transport.connectTokens.length, 1);
    });
  });

  test('verify: conexão morta em silêncio é derrubada e refeita', () {
    run((async, h) {
      h.connection.start();
      async.flushMicrotasks();
      unawaited(h.connection.joinRoom('c1'));
      async.flushMicrotasks();
      h.transport.onRequest = (event, payload) => event == 'presence:get'
          ? throw const RequestTimeoutException()
          : {'ok': true};
      unawaited(h.connection.verify());
      async.flushMicrotasks();
      expect(h.transport.connectTokens.length, 2);
      expect(h.connection.state.isConnected, isTrue);
    });
  });

  test('verify sem conexão apenas reconecta', () {
    run((async, h) {
      h.transport.outcomes.add(const ConnectFail());
      h.connection.start();
      async.flushMicrotasks();
      unawaited(h.connection.verify());
      async.flushMicrotasks();
      expect(h.connection.state.isConnected, isTrue);
    });
  });
}
