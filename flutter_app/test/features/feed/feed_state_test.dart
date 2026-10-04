import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gametracker/app/providers.dart';
import 'package:gametracker/core/network/app_exception.dart';
import 'package:gametracker/features/auth/data/auth_repository.dart';
import 'package:gametracker/features/feed/application/comments_controller.dart';
import 'package:gametracker/features/feed/application/feed_controller.dart';
import 'package:gametracker/features/feed/application/post_store.dart';
import 'package:gametracker/features/feed/data/post_models.dart';

import '../../support/fake_auth.dart';
import '../../support/fake_feed.dart';

Future<ProviderContainer> makeContainer(
  FakeFeedRepository feed, {
  FakeAuthRepository? auth,
  DateTime Function()? clock,
}) async {
  final c = ProviderContainer(
    retry: noAutomaticRetry,
    overrides: [
      ...fakeAuthOverrides(
        auth ??
            (FakeAuthRepository()
              ..restoreResult = Restored(fakeUser('u-ana', 'ana'))),
      ),
      feedRepositoryProvider.overrideWithValue(feed),
      if (clock != null) clockProvider.overrideWithValue(clock),
    ],
  );
  addTearDown(c.dispose);
  c.read(sessionControllerProvider);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  return c;
}

List<Post> posts(int n, {String prefix = 'p'}) => [
  for (var i = 1; i <= n; i++) fakePost(id: '$prefix$i', content: 'post $i'),
];

void main() {
  group('PostStore: curtida', () {
    test('é otimista e confirma no servidor', () async {
      final feed = FakeFeedRepository();
      final c = await makeContainer(feed);
      final store = c.read(postStoreProvider.notifier)
        ..upsert([fakePost(id: 'p1', likes: 2)]);

      await store.toggleLike('p1');
      final p = c.read(postStoreProvider)['p1']!;
      expect((p.likedByMe, p.likeCount), (true, 3));
      expect(feed.likeCalls, [('p1', true)]);

      await store.toggleLike('p1');
      expect(feed.likeCalls.last, ('p1', false));
      expect(
        (
          c.read(postStoreProvider)['p1']!.likedByMe,
          c.read(postStoreProvider)['p1']!.likeCount,
        ),
        (false, 2),
      );
    });

    test('a tela vê o novo valor antes de o servidor responder', () async {
      final gate = Completer<void>();
      final feed = FakeFeedRepository()..likeGate = gate;
      final c = await makeContainer(feed);
      final store = c.read(postStoreProvider.notifier)
        ..upsert([fakePost(id: 'p1')]);

      final pending = store.toggleLike('p1');
      await Future<void>.delayed(Duration.zero);
      expect(
        c.read(postStoreProvider)['p1']!.likedByMe,
        isTrue,
        reason: 'resposta imediata',
      );
      expect(store.isLikePending('p1'), isTrue);

      gate.complete();
      await pending;
      expect(store.isLikePending('p1'), isFalse);
    });

    test(
      'desfaz exatamente o estado anterior quando o servidor falha',
      () async {
        final feed = FakeFeedRepository()..likeError = const NetworkException();
        final c = await makeContainer(feed);
        final store = c.read(postStoreProvider.notifier)
          ..upsert([fakePost(id: 'p1', likes: 4, liked: true)]);

        await expectLater(
          store.toggleLike('p1'),
          throwsA(isA<NetworkException>()),
        );
        final p = c.read(postStoreProvider)['p1']!;
        expect((p.likedByMe, p.likeCount), (true, 4));
        expect(
          store.isLikePending('p1'),
          isFalse,
          reason: 'permite tentar de novo',
        );
      },
    );

    test(
      'toques enquanto pendente não geram requisições nem invertem a ordem',
      () async {
        final gate = Completer<void>();
        final feed = FakeFeedRepository()..likeGate = gate;
        final c = await makeContainer(feed);
        final store = c.read(postStoreProvider.notifier)
          ..upsert([fakePost(id: 'p1')]);

        final first = store.toggleLike('p1');
        await store.toggleLike('p1');
        await store.toggleLike('p1');
        expect(feed.likeCalls.length, 1);
        expect(c.read(postStoreProvider)['p1']!.likedByMe, isTrue);

        gate.complete();
        await first;
      },
    );

    test('contagem nunca fica negativa', () async {
      final c = await makeContainer(FakeFeedRepository());
      final store = c.read(postStoreProvider.notifier)
        ..upsert([fakePost(id: 'p1', likes: 0, liked: true)]);
      await store.toggleLike('p1');
      expect(c.read(postStoreProvider)['p1']!.likeCount, 0);
    });

    test('post desconhecido é ignorado', () async {
      final feed = FakeFeedRepository();
      final c = await makeContainer(feed);
      await c.read(postStoreProvider.notifier).toggleLike('nada');
      expect(feed.likeCalls, isEmpty);
    });

    test('o store é descartado ao sair da conta', () async {
      final auth = FakeAuthRepository()
        ..restoreResult = Restored(fakeUser('u-ana', 'ana'));
      final c = await makeContainer(FakeFeedRepository(), auth: auth);
      c.read(postStoreProvider.notifier).upsert([fakePost(id: 'p1')]);
      expect(c.read(postStoreProvider), isNotEmpty);
      await c.read(sessionControllerProvider.notifier).logout();
      expect(c.read(postStoreProvider), isEmpty);
    });
  });

  group('FeedController', () {
    test('carrega a primeira página e coloca os posts no store', () async {
      final feed = FakeFeedRepository(general: posts(5));
      final c = await makeContainer(feed);
      final state = await c.read(
        feedControllerProvider(FeedScope.general).future,
      );
      expect(state.ids, ['p1', 'p2']);
      expect(state.hasMore, isTrue);
      expect(c.read(postStoreProvider).keys, containsAll(['p1', 'p2']));
      expect(
        feed.feedCalls.single.$1,
        FeedScope.general,
        reason: 'escopo sempre explícito',
      );
    });

    test(
      'paginação anexa sem duplicar mesmo se o servidor repetir um item',
      () async {
        final feed = FakeFeedRepository(general: posts(5))
          ..duplicateOnNextPage = fakePost(id: 'p2');
        final c = await makeContainer(feed);
        await c.read(feedControllerProvider(FeedScope.general).future);

        await c
            .read(feedControllerProvider(FeedScope.general).notifier)
            .loadMore();
        final state = c.read(feedControllerProvider(FeedScope.general)).value!;
        expect(state.ids, ['p1', 'p2', 'p3', 'p4'], reason: 'p2 não duplicado');
        expect(state.ids.toSet().length, state.ids.length);
      },
    );

    test('percorre até o fim e para de buscar', () async {
      final feed = FakeFeedRepository(general: posts(5));
      final c = await makeContainer(feed);
      final ctl = c.read(feedControllerProvider(FeedScope.general).notifier);
      await c.read(feedControllerProvider(FeedScope.general).future);
      await ctl.loadMore();
      await ctl.loadMore();
      final state = c.read(feedControllerProvider(FeedScope.general)).value!;
      expect(state.ids.length, 5);
      expect(state.hasMore, isFalse);

      final calls = feed.feedCalls.length;
      await ctl.loadMore();
      expect(
        feed.feedCalls.length,
        calls,
        reason: 'sem mais páginas, sem requisição',
      );
    });

    test(
      'duas chamadas simultâneas de loadMore carregam uma única página',
      () async {
        final feed = FakeFeedRepository(general: posts(8));
        final c = await makeContainer(feed);
        final ctl = c.read(feedControllerProvider(FeedScope.general).notifier);
        await c.read(feedControllerProvider(FeedScope.general).future);

        await Future.wait([ctl.loadMore(), ctl.loadMore(), ctl.loadMore()]);
        expect(feed.feedCalls.where((call) => call.$2 != null).length, 1);
        expect(
          c.read(feedControllerProvider(FeedScope.general)).value!.ids.length,
          4,
        );
      },
    );

    test('erro de rodapé mantém a lista e permite tentar de novo', () async {
      final feed = FakeFeedRepository(general: posts(5))
        ..pageTwoError = const NetworkException();
      final c = await makeContainer(feed);
      final ctl = c.read(feedControllerProvider(FeedScope.general).notifier);
      await c.read(feedControllerProvider(FeedScope.general).future);

      await ctl.loadMore();
      var state = c.read(feedControllerProvider(FeedScope.general)).value!;
      expect(state.loadMoreError, isA<NetworkException>());
      expect(state.loadingMore, isFalse);
      expect(state.ids, ['p1', 'p2'], reason: 'a lista carregada continua');
      expect(state.hasMore, isTrue);

      feed.pageTwoError = null;
      await ctl.loadMore();
      state = c.read(feedControllerProvider(FeedScope.general)).value!;
      expect(state.loadMoreError, isNull);
      expect(state.ids.length, 4);
    });

    test('Geral e Seguindo são independentes; o post compartilhado tem uma curtida só', () async {
      final shared = fakePost(id: 'shared');
      final feed = FakeFeedRepository(
        general: [shared],
        following: [
          shared,
          fakePost(id: 'only'),
        ],
      );
      final c = await makeContainer(feed);
      await c.read(feedControllerProvider(FeedScope.general).future);
      await c.read(feedControllerProvider(FeedScope.following).future);

      await c.read(postStoreProvider.notifier).toggleLike('shared');
      // Os dois feeds guardam só ids; ambos leem o mesmo post curtido.
      expect(c.read(postStoreProvider)['shared']!.likedByMe, isTrue);
      expect(c.read(feedControllerProvider(FeedScope.general)).value!.ids, [
        'shared',
      ]);
      expect(c.read(feedControllerProvider(FeedScope.following)).value!.ids, [
        'shared',
        'only',
      ]);
    });

    test('Seguindo vazio é um estado válido, não erro', () async {
      final c = await makeContainer(FakeFeedRepository());
      final state = await c.read(
        feedControllerProvider(FeedScope.following).future,
      );
      expect(state.ids, isEmpty);
      expect(state.hasMore, isFalse);
    });

    test(
      'falha na primeira página vira erro recuperável por refresh',
      () async {
        final feed = FakeFeedRepository(general: posts(2))
          ..feedError = const NetworkException();
        final c = await makeContainer(feed);
        c.listen(feedControllerProvider(FeedScope.general), (_, _) {});
        await expectLater(
          c.read(feedControllerProvider(FeedScope.general).future),
          throwsA(isA<NetworkException>()),
        );

        feed.feedError = null;
        await c
            .read(feedControllerProvider(FeedScope.general).notifier)
            .refresh();
        expect(c.read(feedControllerProvider(FeedScope.general)).value!.ids, [
          'p1',
          'p2',
        ]);
      },
    );

    test('post criado entra no topo do Geral sem refetch', () async {
      final feed = FakeFeedRepository(general: posts(3));
      final c = await makeContainer(feed);
      await c.read(feedControllerProvider(FeedScope.general).future);
      final before = feed.feedCalls.length;

      final created = await c
          .read(postStoreProvider.notifier)
          .create(content: 'Olá!');
      expect(
        c.read(feedControllerProvider(FeedScope.general)).value!.ids.first,
        created.id,
      );
      expect(c.read(postStoreProvider)[created.id]!.content, 'Olá!');
      expect(feed.feedCalls.length, before);
    });

    test('o store repassa registro e jogo ao repositório', () async {
      final feed = FakeFeedRepository();
      final c = await makeContainer(feed);
      final store = c.read(postStoreProvider.notifier);
      await store.create(content: 'a', gameId: 'g1', gameEntryId: 'e1');
      await store.create(content: 'b', gameId: 'g1');
      await store.create(content: 'c');
      expect(feed.created.map((e) => (e.gameId, e.gameEntryId)).toList(), [
        ('g1', 'e1'),
        ('g1', null),
        (null, null),
      ]);
    });

    test('falha ao criar não altera o feed', () async {
      final feed = FakeFeedRepository(general: posts(2))
        ..createError = const NetworkException();
      final c = await makeContainer(feed);
      await c.read(feedControllerProvider(FeedScope.general).future);
      await expectLater(
        c.read(postStoreProvider.notifier).create(content: 'x'),
        throwsA(isA<NetworkException>()),
      );
      expect(c.read(feedControllerProvider(FeedScope.general)).value!.ids, [
        'p1',
        'p2',
      ]);
    });

    test(
      'revalida depois de 30 s ou quando marcado como desatualizado',
      () async {
        var now = DateTime.utc(2026, 6, 1, 12);
        final feed = FakeFeedRepository(general: posts(2));
        final c = await makeContainer(feed, clock: () => now);
        c.listen(feedControllerProvider(FeedScope.general), (_, _) {});
        await c.read(feedControllerProvider(FeedScope.general).future);
        expect(feed.feedCalls.length, 1);
        final revalidator = c.read(feedRevalidatorProvider);

        now = now.add(const Duration(seconds: 10));
        revalidator.revalidateIfStale();
        await c.read(feedControllerProvider(FeedScope.general).future);
        expect(feed.feedCalls.length, 1, reason: 'ainda fresco');

        revalidator.markStale();
        revalidator.revalidateIfStale();
        await c.read(feedControllerProvider(FeedScope.general).future);
        expect(feed.feedCalls.length, 2, reason: 'marcado como desatualizado');

        now = now.add(const Duration(seconds: 45));
        revalidator.revalidateIfStale();
        await c.read(feedControllerProvider(FeedScope.general).future);
        expect(feed.feedCalls.length, 3, reason: 'passou de 30 s');
      },
    );

    test('o feed é descartado ao sair da conta', () async {
      final auth = FakeAuthRepository()
        ..restoreResult = Restored(fakeUser('u-ana', 'ana'));
      final c = await makeContainer(
        FakeFeedRepository(general: posts(2)),
        auth: auth,
      );
      expect(
        (await c.read(feedControllerProvider(FeedScope.general).future)).ids,
        isNotEmpty,
      );
      await c.read(sessionControllerProvider.notifier).logout();
      expect(
        (await c.read(feedControllerProvider(FeedScope.general).future)).ids,
        isEmpty,
      );
    });
  });

  group('CommentsController', () {
    FakeFeedRepository withThread() =>
        FakeFeedRepository()
          ..commentTrees['p1'] = [
            fakeComment(
              id: 'a',
              likes: 1,
              replies: [
                fakeComment(
                  id: 'b',
                  parent: 'a',
                  replies: [fakeComment(id: 'c', parent: 'b')],
                ),
              ],
            ),
          ];

    test('carrega a árvore inteira e sincroniza o contador do post', () async {
      final feed = withThread();
      final c = await makeContainer(feed);
      c.read(postStoreProvider.notifier).upsert([
        fakePost(id: 'p1', comments: 0),
      ]);
      c.listen(commentsControllerProvider('p1'), (_, _) {});
      final tree = await c.read(commentsControllerProvider('p1').future);
      expect(countComments(tree), 3);
      expect(
        c.read(postStoreProvider)['p1']!.commentCount,
        3,
        reason: 'contador vem da árvore',
      );
    });

    test(
      'curtir uma resposta profunda é otimista e preserva o resto',
      () async {
        final feed = withThread();
        final c = await makeContainer(feed);
        c.listen(commentsControllerProvider('p1'), (_, _) {});
        await c.read(commentsControllerProvider('p1').future);

        await c.read(commentsControllerProvider('p1').notifier).toggleLike('c');
        final tree = c.read(commentsControllerProvider('p1')).value!;
        expect(findCommentInTree(tree, 'c')!.likedByMe, isTrue);
        expect(findCommentInTree(tree, 'c')!.likeCount, 1);
        expect(
          findCommentInTree(tree, 'a')!.likeCount,
          1,
          reason: 'pai intacto',
        );
        expect(countComments(tree), 3);
        expect(feed.commentLikeCalls, [('c', true)]);
      },
    );

    test('curtida de comentário desfeita quando o servidor falha', () async {
      final feed = withThread()..likeError = const NetworkException();
      final c = await makeContainer(feed);
      c.listen(commentsControllerProvider('p1'), (_, _) {});
      await c.read(commentsControllerProvider('p1').future);

      await expectLater(
        c.read(commentsControllerProvider('p1').notifier).toggleLike('a'),
        throwsA(isA<NetworkException>()),
      );
      final a = findCommentInTree(
        c.read(commentsControllerProvider('p1')).value!,
        'a',
      )!;
      expect((a.likedByMe, a.likeCount), (false, 1));
    });

    test('comentar recarrega a árvore e atualiza o contador do post', () async {
      final feed = withThread();
      final c = await makeContainer(feed);
      c.read(postStoreProvider.notifier).upsert([
        fakePost(id: 'p1', comments: 3),
      ]);
      c.listen(commentsControllerProvider('p1'), (_, _) {});
      await c.read(commentsControllerProvider('p1').future);

      await c
          .read(commentsControllerProvider('p1').notifier)
          .add('novo', parentCommentId: 'c');
      final tree = c.read(commentsControllerProvider('p1')).value!;
      expect(countComments(tree), 4);
      expect(
        findCommentInTree(tree, 'c')!.replies.single.content,
        'novo',
        reason: 'resposta aninhada ao alvo',
      );
      expect(c.read(postStoreProvider)['p1']!.commentCount, 4);
      expect(feed.addedComments.single.parent, 'c');
    });

    test(
      'falha ao comentar lança e não altera a árvore nem o contador',
      () async {
        final feed = withThread()..commentError = const NetworkException();
        final c = await makeContainer(feed);
        c.read(postStoreProvider.notifier).upsert([
          fakePost(id: 'p1', comments: 3),
        ]);
        c.listen(commentsControllerProvider('p1'), (_, _) {});
        await c.read(commentsControllerProvider('p1').future);

        await expectLater(
          c.read(commentsControllerProvider('p1').notifier).add('x'),
          throwsA(isA<NetworkException>()),
        );
        expect(
          countComments(c.read(commentsControllerProvider('p1')).value!),
          3,
        );
        expect(c.read(postStoreProvider)['p1']!.commentCount, 3);
        expect(feed.addedComments, isEmpty, reason: 'sem retry silencioso');
      },
    );
  });
}
