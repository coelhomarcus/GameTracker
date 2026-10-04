import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:gametracker/app/providers.dart';
import 'package:gametracker/core/design_system/game_status.dart';
import 'package:gametracker/core/network/app_exception.dart';
import 'package:gametracker/features/auth/data/auth_repository.dart';
import 'package:gametracker/features/games/application/game_providers.dart';
import 'package:gametracker/features/games/data/game_models.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_repos.dart';
import '../../support/fixtures.dart';

ProviderContainer makeContainer(FakeGamesRepository games) {
  final c = ProviderContainer(
    retry: noAutomaticRetry,
    overrides: [
      ...fakeAuthOverrides(
        FakeAuthRepository()..restoreResult = Restored(fakeUser()),
      ),
      gamesRepositoryProvider.overrideWithValue(games),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

/// Espera a sessão restaurar: ao mudar o usuário, providers dependentes são recriados.
Future<ProviderContainer> makeSettled(FakeGamesRepository games) async {
  final c = makeContainer(games);
  c.read(sessionControllerProvider);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  return c;
}

/// Providers `autoDispose` perdem o estado sem ouvinte; a tela real mantém um aberto.
void keepAlive(ProviderContainer c, ProviderListenable<Object?> provider) {
  c.listen(provider, (_, _) {});
}

void main() {
  group('contrato: respostas reais do backend', () {
    test('GET /games/igdb/:id com favorito e sinopse', () {
      final g = Game.fromJson(
        fixtureBody('games_by_igdb') as Map<String, dynamic>,
      );
      expect(g.igdbId, 900001);
      expect(
        g.id,
        isNot(g.igdbId.toString()),
        reason: 'UUID interno e igdbId são identificadores distintos',
      );
      expect(g.platforms, ['PC', 'PlayStation 5']);
      expect(g.summary, 'Sinopse de teste.');
    });

    test('jogo com metadados incompletos', () {
      final g = Game.fromJson(
        fixtureBody('games_by_igdb_incomplete') as Map<String, dynamic>,
      );
      expect(g.summary, isNull);
      expect(g.coverUrl, isNull);
      expect(g.genres, isEmpty);
      expect(g.screenshots, isEmpty);
    });

    test('estatísticas contam playthroughs por status', () {
      // As contagens dependem do banco de onde a fixture foi gravada; o contrato é a forma.
      final json = fixtureBody('game_stats') as Map<String, dynamic>;
      expect(
        json.keys,
        containsAll(['backlog', 'playing', 'completed', 'dropped']),
      );
      final s = GameStats.fromJson(json);
      expect(s.total, s.backlog + s.playing + s.completed + s.dropped);
      expect(s.forStatus(GameStatus.completed), s.completed);
      expect(s.forStatus(GameStatus.playing), s.playing);
    });

    test('resultado de busca da IGDB (formato do backend)', () {
      final r = GameSummary.fromJson({
        'igdbId': 1942,
        'name': 'The Witcher 3',
        'summary': null,
        'coverUrl': 'http://localhost:3100/api/images/cover?url=x',
        'screenshots': <String>[],
        'platforms': ['PC'],
        'genres': ['RPG'],
      });
      expect(r.igdbId, 1942);
      expect(r.name, 'The Witcher 3');
      expect(r.platforms, ['PC']);
    });

    test('jogador com horas string', () {
      final p = GamePlayer.fromJson({
        'user': {'id': 'u', 'username': 'ana', 'name': null, 'avatarUrl': null},
        'status': 'playing',
        'hoursPlayed': '3.5',
      });
      expect(p.hoursPlayed, 3.5);
      expect(p.user.displayName, 'ana', reason: 'sem nome cai no username');
    });
  });

  group('favorito', () {
    test('atualiza na hora e confirma no servidor', () async {
      final games = FakeGamesRepository();
      final c = await makeSettled(games);
      keepAlive(c, gameControllerProvider(900001));
      await c.read(gameControllerProvider(900001).future);

      await c.read(gameControllerProvider(900001).notifier).toggleFavorite();
      expect(
        c.read(gameControllerProvider(900001)).value!.isFavoritedByMe,
        isTrue,
      );
      expect(games.favoriteCalls, [
        ('g-900001', true),
      ], reason: 'favoritar usa o UUID do jogo, não o igdbId');
    });

    test('desfaz quando o servidor falha', () async {
      final games = FakeGamesRepository()
        ..favoriteError = const NetworkException();
      final c = await makeSettled(games);
      keepAlive(c, gameControllerProvider(900001));
      await c.read(gameControllerProvider(900001).future);

      await expectLater(
        c.read(gameControllerProvider(900001).notifier).toggleFavorite(),
        throwsA(isA<NetworkException>()),
      );
      expect(
        c.read(gameControllerProvider(900001)).value!.isFavoritedByMe,
        isFalse,
      );
    });

    test(
      'toques repetidos enquanto pendente não geram requisições duplicadas',
      () async {
        final gate = Completer<void>();
        final games = FakeGamesRepository()..favoriteGate = gate;
        final c = await makeSettled(games);
        keepAlive(c, gameControllerProvider(900001));
        await c.read(gameControllerProvider(900001).future);
        final ctl = c.read(gameControllerProvider(900001).notifier);

        final first = ctl.toggleFavorite();
        await ctl.toggleFavorite();
        await ctl.toggleFavorite();
        expect(games.favoriteCalls.length, 1);
        expect(
          c.read(gameControllerProvider(900001)).value!.isFavoritedByMe,
          isTrue,
        );

        gate.complete();
        await first;
        expect(ctl.isTogglingFavorite, isFalse);
      },
    );

    test('jogo inexistente vira erro, não crash', () async {
      final games = FakeGamesRepository()
        ..gameError = const ApiException(
          404,
          'not_found',
          'Jogo não encontrado',
        );
      final c = await makeSettled(games);
      keepAlive(c, gameControllerProvider(900001));
      await expectLater(
        c.read(gameControllerProvider(1).future),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('busca', () {
    test('termo curto não consulta o servidor', () async {
      final games = FakeGamesRepository();
      final c = makeContainer(games);
      expect(await c.read(gameSearchProvider('a').future), isEmpty);
      expect(await c.read(gameSearchProvider('  ').future), isEmpty);
      expect(games.searches, isEmpty);
    });

    test('espera o debounce antes de consultar', () {
      fakeAsync((async) {
        final games = FakeGamesRepository()
          ..searchResult = const [
            GameSummary(igdbId: 1, name: 'Zelda', platforms: [], genres: []),
          ];
        final c = makeContainer(games);
        List<GameSummary>? result;
        final sub = c.listen(
          gameSearchProvider('zelda'),
          (_, next) => result = next.value,
        );

        async.elapse(searchDebounce - const Duration(milliseconds: 50));
        expect(games.searches, isEmpty);
        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();
        expect(games.searches, ['zelda']);
        expect(result?.single.name, 'Zelda');
        sub.close();
      });
    });

    test('digitar mais antes do debounce abandona a consulta anterior', () {
      fakeAsync((async) {
        final games = FakeGamesRepository();
        final c = makeContainer(games);
        final s1 = c.listen(gameSearchProvider('ze'), (_, _) {});
        async.elapse(const Duration(milliseconds: 200));
        s1.close();
        final s2 = c.listen(gameSearchProvider('zel'), (_, _) {});
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(games.searches, [
          'zel',
        ], reason: 'a busca de "ze" nunca foi enviada');
        s2.close();
      });
    });

    test('termo é aparado antes de enviar', () {
      fakeAsync((async) {
        final games = FakeGamesRepository();
        final c = makeContainer(games);
        final sub = c.listen(gameSearchProvider('  zelda  '), (_, _) {});
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(games.searches, ['zelda']);
        sub.close();
      });
    });

    test('erro de busca é distinto de lista vazia', () async {
      final games = FakeGamesRepository()
        ..searchError = const ApiException(
          503,
          'igdb_not_configured',
          'IGDB não configurada',
        );
      final c = makeContainer(games);
      final sub = c.listen(gameSearchProvider('zelda'), (_, _) {});
      await Future<void>.delayed(
        searchDebounce + const Duration(milliseconds: 100),
      );
      expect(c.read(gameSearchProvider('zelda')).hasError, isTrue);
      expect(c.read(gameSearchProvider('zelda')).error, isA<ApiException>());
      sub.close();
    });
  });
}
