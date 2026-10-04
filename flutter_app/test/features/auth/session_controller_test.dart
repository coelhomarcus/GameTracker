import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gametracker/app/providers.dart';
import 'package:gametracker/core/network/app_exception.dart';
import 'package:gametracker/features/auth/data/auth_repository.dart';
import 'package:gametracker/features/auth/presentation/session_state.dart';

import '../../support/fake_auth.dart';

ProviderContainer makeContainer(FakeAuthRepository repo) {
  final c = ProviderContainer(
    retry: noAutomaticRetry,
    overrides: fakeAuthOverrides(repo),
  );
  addTearDown(c.dispose);
  return c;
}

Future<SessionState> settle(ProviderContainer c) async {
  c.read(sessionControllerProvider);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  return c.read(sessionControllerProvider);
}

void main() {
  group('bootstrap', () {
    test('começa inicializando e restaura a sessão', () async {
      final repo = FakeAuthRepository()..restoreResult = Restored(fakeUser());
      final c = makeContainer(repo);
      expect(c.read(sessionControllerProvider), isA<SessionInitializing>());
      final state = await settle(c);
      expect(state, isA<SessionAuthenticated>());
      expect((state as SessionAuthenticated).user.id, 'u1');
    });

    test('sem sessão guardada vai para não autenticado', () async {
      final c = makeContainer(FakeAuthRepository());
      expect(await settle(c), isA<SessionUnauthenticated>());
    });

    test(
      'rede indisponível não vira logout e permite tentar de novo',
      () async {
        final repo = FakeAuthRepository()
          ..restoreResult = const RestoreUnavailable();
        final c = makeContainer(repo);
        expect(await settle(c), isA<SessionRestoreUnavailable>());

        repo.restoreResult = Restored(fakeUser());
        await c.read(sessionControllerProvider.notifier).bootstrap();
        expect(c.read(sessionControllerProvider), isA<SessionAuthenticated>());
        expect(repo.restoreCalls, 2);
      },
    );
  });

  group('ações', () {
    test('login com sucesso autentica', () async {
      final repo = FakeAuthRepository();
      final c = makeContainer(repo);
      await settle(c);
      await c
          .read(sessionControllerProvider.notifier)
          .login('ana', 'senha-longa');
      expect(c.read(sessionControllerProvider), isA<SessionAuthenticated>());
    });

    test('login recusado propaga o erro e mantém o estado', () async {
      final repo = FakeAuthRepository()
        ..loginError = const ApiException(
          401,
          'invalid_credentials',
          'Credenciais inválidas',
        );
      final c = makeContainer(repo);
      await settle(c);
      await expectLater(
        c.read(sessionControllerProvider.notifier).login('ana', 'errada'),
        throwsA(isA<ApiException>()),
      );
      expect(c.read(sessionControllerProvider), isA<SessionUnauthenticated>());
    });

    test('logout encerra a sessão e chama o repositório', () async {
      final repo = FakeAuthRepository()..restoreResult = Restored(fakeUser());
      final c = makeContainer(repo);
      await settle(c);
      await c.read(sessionControllerProvider.notifier).logout();
      expect(c.read(sessionControllerProvider), isA<SessionUnauthenticated>());
      expect(repo.logoutCalls, 1);
    });

    test('refresh recusado durante o uso devolve ao login', () async {
      final repo = FakeAuthRepository()..restoreResult = Restored(fakeUser());
      final c = makeContainer(repo);
      await settle(c);
      c.read(sessionManagerProvider).onExpired!();
      expect(c.read(sessionControllerProvider), isA<SessionUnauthenticated>());
    });
  });

  group('isolamento entre contas', () {
    test(
      'estado derivado da sessão é descartado ao sair e ao trocar de conta',
      () async {
        final repo = FakeAuthRepository()
          ..restoreResult = Restored(fakeUser('u1', 'ana'));
        final c = makeContainer(repo);
        final created = <String?>[];
        final userData = Provider<Object>((ref) {
          created.add(ref.watch(currentUserIdProvider));
          return Object();
        });

        await settle(c);
        final first = c.read(userData);
        expect(c.read(currentUserIdProvider), 'u1');

        await c.read(sessionControllerProvider.notifier).logout();
        final afterLogout = c.read(userData);
        expect(
          identical(first, afterLogout),
          isFalse,
          reason: 'dados da conta anterior descartados',
        );

        repo.nextUser = fakeUser('u2', 'beto');
        await c
            .read(sessionControllerProvider.notifier)
            .login('beto', 'senha-longa');
        final second = c.read(userData);
        expect(identical(afterLogout, second), isFalse);
        expect(created, ['u1', null, 'u2']);
      },
    );
  });
}
