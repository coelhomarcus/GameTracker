import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gametracker/core/network/api_client.dart';
import 'package:gametracker/core/network/app_exception.dart';
import 'package:gametracker/core/network/session_manager.dart';
import 'package:gametracker/core/storage/token_store.dart';

import '../support/fake_api.dart';

/// Servidor falso com a regra do backend: access token expirado → 401; refresh
/// token de uso único.
class Harness {
  Harness({String refreshToken = 'r0', this.accessValid = 'a1'})
    : store = MemoryTokenStore(refreshToken) {
    session = SessionManager(store: store, refreshCall: _refresh);
    session.onExpired = () => expired++;
    adapter = FakeAdapter(_handle);
    dio = createApiDio(session, baseUrl: 'http://fake', adapter: adapter);
  }

  final MemoryTokenStore store;
  late final SessionManager session;
  late final FakeAdapter adapter;
  late final Dio dio;

  /// Access token que o servidor aceita agora.
  String accessValid;
  int refreshCalls = 0;
  int expired = 0;
  int _next = 2;

  /// Se definido, o refresh só termina quando o completer for resolvido.
  Completer<void>? refreshGate;

  /// Se definido, o refresh falha com esta exceção.
  AppException? refreshFailure;

  /// Se verdadeiro, o servidor responde 401 mesmo com token novo.
  bool alwaysUnauthorized = false;

  Future<SessionTokens> _refresh(String refreshToken) async {
    refreshCalls++;
    await refreshGate?.future;
    final failure = refreshFailure;
    if (failure != null) throw failure;
    accessValid = 'a$_next';
    return SessionTokens(accessToken: accessValid, refreshToken: 'r${_next++}');
  }

  Future<ResponseBody> _handle(RequestOptions o) async {
    final auth = o.headers['Authorization'];
    if (o.path == '/slow') {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    if (alwaysUnauthorized || auth != 'Bearer $accessValid') {
      return errorResponse(401, 'unauthorized', 'Token inválido');
    }
    return jsonResponse(200, {'ok': true, 'auth': auth});
  }

  int hits(String path) => adapter.requests.where((r) => r.path == path).length;
}

void main() {
  group('refresh em 401', () {
    test(
      'vários 401 simultâneos disparam um único refresh e todos são repetidos',
      () async {
        final h = Harness();
        await h.session.start(
          const SessionTokens(accessToken: 'velho', refreshToken: 'r0'),
        );
        h.refreshGate = Completer<void>();

        final calls = [
          for (var i = 0; i < 5; i++) h.dio.get<dynamic>('/data$i'),
        ];
        await Future<void>.delayed(const Duration(milliseconds: 20));
        h.refreshGate!.complete();
        final results = await Future.wait(calls);

        expect(h.refreshCalls, 1);
        expect(results.every((r) => r.statusCode == 200), isTrue);
        expect(results.first.data['auth'], 'Bearer a2');
        for (var i = 0; i < 5; i++) {
          expect(
            h.hits('/data$i'),
            2,
            reason: 'uma tentativa original e uma repetição',
          );
        }
        expect(await h.store.read(), 'r2');
      },
    );

    test('request que falhou com token antigo não renova de novo se outra já renovou', () async {
      final h = Harness();
      await h.session.start(
        const SessionTokens(accessToken: 'velho', refreshToken: 'r0'),
      );
      final slow = h.dio.get<dynamic>('/slow');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final fast = h.dio.get<dynamic>('/fast');
      await Future.wait([slow, fast]);
      expect(h.refreshCalls, 1);
    });

    test(
      'repete no máximo uma vez, mesmo que o servidor continue recusando',
      () async {
        final h = Harness()..alwaysUnauthorized = true;
        await h.session.start(
          const SessionTokens(accessToken: 'velho', refreshToken: 'r0'),
        );
        await expectLater(
          h.dio.get<dynamic>('/data'),
          throwsA(isA<DioException>()),
        );
        expect(h.hits('/data'), 2);
        expect(h.refreshCalls, 1);
      },
    );

    test('refresh recusado limpa a sessão e avisa uma única vez', () async {
      final h = Harness()
        ..refreshFailure = const ApiException(
          401,
          'invalid_refresh_token',
          'inválido',
        );
      await h.session.start(
        const SessionTokens(accessToken: 'velho', refreshToken: 'r0'),
      );
      final calls = [
        for (var i = 0; i < 3; i++)
          h.dio
              .get<dynamic>('/data$i')
              .catchError(
                (_) =>
                    Response(requestOptions: RequestOptions(), statusCode: 0),
              ),
      ];
      await Future.wait(calls);
      expect(h.expired, 1);
      expect(h.session.accessToken, isNull);
      expect(await h.store.read(), isNull);
      expect(h.refreshCalls, 1, reason: 'sem loop de refresh');
    });

    test('rede indisponível no refresh preserva as credenciais', () async {
      final h = Harness()..refreshFailure = const NetworkException();
      await h.session.start(
        const SessionTokens(accessToken: 'velho', refreshToken: 'r0'),
      );
      await expectLater(
        h.dio.get<dynamic>('/data'),
        throwsA(isA<DioException>()),
      );
      expect(h.expired, 0);
      expect(await h.store.read(), 'r0');
    });

    test('erro que não é 401 não dispara refresh', () async {
      final h = Harness();
      h.accessValid = 'a1';
      await h.session.start(
        const SessionTokens(accessToken: 'a1', refreshToken: 'r0'),
      );
      final r = await h.dio.get<dynamic>('/data');
      expect(r.statusCode, 200);
      expect(h.refreshCalls, 0);
    });
  });

  group('logout e troca de conta', () {
    test(
      'logout durante o refresh: resultado tardio não restaura a conta',
      () async {
        final h = Harness();
        await h.session.start(
          const SessionTokens(accessToken: 'velho', refreshToken: 'r0'),
        );
        h.refreshGate = Completer<void>();
        final call = h.dio
            .get<dynamic>('/data')
            .then<Object?>((r) => r, onError: (Object e) => e);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        await h.session.clear();
        h.refreshGate!.complete();
        final result = await call;

        expect(result, isA<DioException>());
        expect((result as DioException).type, DioExceptionType.cancel);
        expect(h.session.accessToken, isNull);
        expect(
          await h.store.read(),
          isNull,
          reason: 'refresh tardio não regrava o token',
        );
        expect(h.expired, 0);
      },
    );

    test('resposta que chega depois do logout é descartada', () async {
      final h = Harness();
      h.accessValid = 'a1';
      await h.session.start(
        const SessionTokens(accessToken: 'a1', refreshToken: 'r0'),
      );
      final call = h.dio
          .get<dynamic>('/slow')
          .then<Object?>((r) => r, onError: (Object e) => e);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await h.session.clear();
      final result = await call;
      expect(result, isA<DioException>());
      expect((result as DioException).type, DioExceptionType.cancel);
    });

    test('start de outra conta invalida requisições da anterior', () async {
      final h = Harness();
      h.accessValid = 'a1';
      await h.session.start(
        const SessionTokens(accessToken: 'a1', refreshToken: 'r0'),
      );
      final call = h.dio
          .get<dynamic>('/slow')
          .then<Object?>((r) => r, onError: (Object e) => e);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await h.session.start(
        const SessionTokens(accessToken: 'b1', refreshToken: 'rb'),
      );
      expect(await call, isA<DioException>());
      expect(h.session.accessToken, 'b1');
      expect(await h.store.read(), 'rb');
    });

    test(
      'clear devolve o refresh token anterior para revogação remota',
      () async {
        final h = Harness();
        await h.session.start(
          const SessionTokens(accessToken: 'a1', refreshToken: 'r7'),
        );
        expect(await h.session.clear(), 'r7');
        expect(await h.session.clear(), isNull);
      },
    );
  });

  group('restore (bootstrap)', () {
    test('sem token guardado', () async {
      final h = Harness();
      await h.store.clear();
      expect(await h.session.restore(), RefreshOutcome.noSession);
    });

    test('token válido restaura a sessão', () async {
      final h = Harness();
      expect(await h.session.restore(), RefreshOutcome.refreshed);
      expect(h.session.accessToken, 'a2');
    });

    test('token revogado limpa e sinaliza expiração', () async {
      final h = Harness()
        ..refreshFailure = const ApiException(
          401,
          'invalid_refresh_token',
          'inválido',
        );
      expect(await h.session.restore(), RefreshOutcome.invalid);
      expect(await h.store.read(), isNull);
      expect(h.expired, 1);
    });

    test('falha de rede mantém o token e permite tentar de novo', () async {
      final h = Harness()..refreshFailure = const NetworkException();
      expect(await h.session.restore(), RefreshOutcome.unavailable);
      expect(await h.store.read(), 'r0');
      expect(h.expired, 0);

      h.refreshFailure = null;
      expect(await h.session.restore(), RefreshOutcome.refreshed);
    });

    test('erro 5xx também é indisponibilidade, não sessão inválida', () async {
      final h = Harness()
        ..refreshFailure = const ApiException(503, 'server_error', 'fora');
      expect(await h.session.restore(), RefreshOutcome.unavailable);
      expect(await h.store.read(), 'r0');
    });
  });

  group('mapDioException', () {
    DioException bad(int status, Object? data) => DioException(
      requestOptions: RequestOptions(),
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: RequestOptions(),
        statusCode: status,
        data: data,
      ),
    );

    test('envelope padrão', () {
      final e = mapDioException(
        bad(409, {
          'error': {'code': 'conflict', 'message': 'Username já cadastrado'},
        }),
      ) as ApiException;
      expect(
        (e.status, e.code, e.message),
        (409, 'conflict', 'Username já cadastrado'),
      );
    });

    test('rate limiter com corpo fora do envelope', () {
      final e = mapDioException(
        bad(429, 'Too many requests, please try again later.'),
      ) as ApiException;
      expect(e.isRateLimited, isTrue);
      expect(e.code, 'rate_limited');
      expect(e.message, contains('Muitas tentativas'));
    });

    test('corpo HTML de proxy 502', () {
      final e =
          mapDioException(bad(502, '<html>Bad gateway</html>')) as ApiException;
      expect(e.isServerError, isTrue);
    });

    test('timeout e conexão recusada viram NetworkException', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.connectionError,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(
          mapDioException(
            DioException(requestOptions: RequestOptions(), type: type),
          ),
          isA<NetworkException>(),
        );
      }
    });
  });
}
