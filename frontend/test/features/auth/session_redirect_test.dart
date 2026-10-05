import 'package:flutter_test/flutter_test.dart';
import 'package:gametracker/app/router.dart';
import 'package:gametracker/features/auth/presentation/session_state.dart';

import '../../support/fake_auth.dart';

String? go(SessionState s, String uri) => sessionRedirect(s, Uri.parse(uri));

void main() {
  final authed = SessionAuthenticated(fakeUser());
  const anon = SessionUnauthenticated();

  group('não autenticado', () {
    test('rota protegida vai ao login lembrando o destino', () {
      expect(
        go(anon, '/games/42'),
        '/login?from=${Uri.encodeQueryComponent('/games/42')}',
      );
    });

    test('mantém query do destino', () {
      expect(
        go(anon, '/games/42?tab=2'),
        '/login?from=${Uri.encodeQueryComponent('/games/42?tab=2')}',
      );
    });

    test('login e cadastro são públicos', () {
      expect(go(anon, '/login'), isNull);
      expect(go(anon, '/register?from=%2Fme'), isNull);
    });
  });

  group('inicializando e sem conexão', () {
    test('deep link espera a sessão sem perder o destino', () {
      const s = SessionInitializing();
      expect(
        go(s, '/games/42'),
        '/splash?from=${Uri.encodeQueryComponent('/games/42')}',
      );
      expect(go(s, '/splash?from=%2Fgames%2F42'), isNull);
    });

    test('restauração indisponível mostra a tela de nova tentativa', () {
      const s = SessionRestoreUnavailable();
      expect(
        go(s, '/library'),
        '/restore?from=${Uri.encodeQueryComponent('/library')}',
      );
      expect(go(s, '/restore'), isNull);
    });

    test(
      'splash vira login sem perder o destino quando a sessão não existe',
      () {
        expect(
          go(anon, '/splash?from=%2Fgames%2F42'),
          '/login?from=${Uri.encodeQueryComponent('/games/42')}',
        );
      },
    );
  });

  group('autenticado', () {
    test('login vai ao destino pedido ou à Biblioteca', () {
      expect(go(authed, '/login'), '/library');
      expect(go(authed, '/login?from=%2Fgames%2F42'), '/games/42');
      expect(go(authed, '/splash?from=%2Fme'), '/me');
      expect(go(authed, '/restore'), '/library');
    });

    test('rota protegida passa', () {
      expect(go(authed, '/games/42'), isNull);
    });
  });

  group('destino seguro', () {
    test('rejeita URL externa, protocolo relativo e rotas de sessão', () {
      expect(safeDestination('https://evil.example'), isNull);
      expect(safeDestination('//evil.example'), isNull);
      expect(safeDestination('javascript:alert(1)'), isNull);
      expect(safeDestination('/login'), isNull);
      expect(safeDestination('/splash'), isNull);
      expect(safeDestination(''), isNull);
      expect(safeDestination(null), isNull);
    });

    test('aceita caminho interno', () {
      expect(safeDestination('/games/42?x=1'), '/games/42?x=1');
    });

    test('from externo no login autenticado cai na Biblioteca', () {
      expect(go(authed, '/login?from=https%3A%2F%2Fevil.example'), '/library');
    });
  });
}
