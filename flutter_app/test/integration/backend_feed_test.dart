// Feed, posts e comentários contra o backend real (ambiente isolado, nunca produção).
//
//   flutter test test/integration --dart-define=GT_BACKEND=http://localhost:3100
//
// Requer o jogo sintético 900001 no cache (docs/contract-fixtures/capture.mjs).
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gametracker/core/design_system/game_status.dart';
import 'package:gametracker/core/network/api_client.dart';
import 'package:gametracker/core/network/app_exception.dart';
import 'package:gametracker/core/network/session_manager.dart';
import 'package:gametracker/core/storage/token_store.dart';
import 'package:gametracker/features/auth/data/auth_api.dart';
import 'package:gametracker/features/feed/data/feed_repository.dart';
import 'package:gametracker/features/feed/data/post_models.dart';
import 'package:gametracker/features/games/data/games_repository.dart';
import 'package:gametracker/features/library/data/game_entry.dart';
import 'package:gametracker/features/library/data/library_repository.dart';

const backend = String.fromEnvironment('GT_BACKEND');

class Account {
  Account(this.id, this.dio)
    : feed = RemoteFeedRepository(dio),
      library = RemoteLibraryRepository(dio),
      games = RemoteGamesRepository(dio);
  final String id;
  final Dio dio;
  final RemoteFeedRepository feed;
  final RemoteLibraryRepository library;
  final RemoteGamesRepository games;

  Future<void> follow(String userId) async =>
      dio.post<void>('/users/$userId/follow');
}

Future<Account> signUp(String prefix) async {
  final n = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final authApi = AuthApi(createAuthDio(baseUrl: '$backend/api'));
  final session = SessionManager(
    store: MemoryTokenStore(),
    refreshCall: authApi.refresh,
  );
  final r = await authApi.register(
    name: prefix,
    username: '${prefix}_$n',
    email: '${prefix}_$n@example.test',
    password: 'senha-fixture-123',
  );
  await session.start(r.tokens);
  return Account(r.user.id, createApiDio(session, baseUrl: '$backend/api'));
}

void main() {
  final skip = backend.isEmpty
      ? 'defina --dart-define=GT_BACKEND=http://localhost:3100'
      : null;

  test(
    'post sem vínculo: cria, lê pelo id e aparece no Geral do autor e no Seguindo de quem o segue',
    skip: skip,
    () async {
      final a = await signUp('fa');
      final b = await signUp('fb');
      final post = await a.feed.create(content: 'Olá, comunidade!');
      expect(post.author.id, a.id);
      expect((post.game, post.entry), (null, null));
      expect(post.createdAt.isUtc, isTrue);

      expect((await b.feed.post(post.id)).content, 'Olá, comunidade!');
      expect(
        (await b.feed.feed(FeedScope.general)).items
            .any((p) => p.id == post.id),
        isTrue,
      );
      expect(
        (await b.feed.feed(FeedScope.following)).items,
        isEmpty,
        reason: 'B ainda não segue ninguém',
      );

      await b.follow(a.id);
      expect(
        (await b.feed.feed(FeedScope.following)).items.map((p) => p.id),
        contains(post.id),
      );
      expect(
        (await a.feed.feed(FeedScope.following)).items
            .any((p) => p.author.id == a.id),
        isFalse,
        reason: 'o Seguindo exclui os próprios posts',
      );
    },
  );

  test(
    'post vinculado a um jogo (sem registro) e a um registro',
    skip: skip,
    () async {
      final a = await signUp('fc');
      final game = await a.games.byIgdbId(900001);

      final withGame = await a.feed.create(
        content: 'Quero jogar',
        gameId: game.id,
      );
      expect(withGame.game?.igdbId, 900001);
      expect(withGame.entry, isNull);

      final entry = await a.library.create(
        900001,
        const EntryDraft(platform: 'PC', status: GameStatus.completed),
      );
      final withEntry = await a.feed.create(
        content: 'Zerei!',
        gameEntryId: entry.id,
        gameId: game.id,
      );
      expect(withEntry.entry?.id, entry.id);
      expect(
        withEntry.game?.id,
        game.id,
        reason: 'o backend derivou o jogo do registro',
      );
    },
  );

  test(
    'registro de outro usuário não pode ser usado em um post',
    skip: skip,
    () async {
      final a = await signUp('fd');
      final b = await signUp('fe');
      final entry = await a.library.create(
        900001,
        const EntryDraft(platform: 'PC', status: GameStatus.backlog),
      );
      await expectLater(
        b.feed.create(content: 'roubando', gameEntryId: entry.id),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
      );
    },
  );

  test(
    'curtir e descurtir são idempotentes e refletem em likedByMe e likeCount',
    skip: skip,
    () async {
      final a = await signUp('ff');
      final b = await signUp('fg');
      final post = await a.feed.create(content: 'curta-me');

      await b.feed.setLike(post.id, liked: true);
      await b.feed.setLike(post.id, liked: true);
      var seen = await b.feed.post(post.id);
      expect((seen.likedByMe, seen.likeCount), (true, 1));
      expect(
        (await a.feed.post(post.id)).likedByMe,
        isFalse,
        reason: 'likedByMe é por espectador',
      );

      await b.feed.setLike(post.id, liked: false);
      await b.feed.setLike(post.id, liked: false);
      seen = await b.feed.post(post.id);
      expect((seen.likedByMe, seen.likeCount), (false, 0));
    },
  );

  test(
    'comentários: árvore, respostas profundas, curtidas e contador do post',
    skip: skip,
    () async {
      final a = await signUp('fh');
      final b = await signUp('fi');
      final post = await a.feed.create(content: 'discutam');

      await b.feed.addComment(post.id, 'raiz');
      var tree = await a.feed.comments(post.id);
      final root = tree.single;
      await a.feed.addComment(post.id, 'nível 1', parentCommentId: root.id);
      tree = await a.feed.comments(post.id);
      final l1 = tree.single.replies.single;
      await b.feed.addComment(post.id, 'nível 2', parentCommentId: l1.id);
      tree = await a.feed.comments(post.id);
      final l2 = tree.single.replies.single.replies.single;
      await a.feed.addComment(post.id, 'nível 3', parentCommentId: l2.id);

      tree = await a.feed.comments(post.id);
      expect(countComments(tree), 4);
      expect(findCommentInTree(tree, l2.id)!.replies.single.content, 'nível 3');
      expect(
        (await a.feed.post(post.id)).commentCount,
        4,
        reason: 'o contador do post conta todos os níveis',
      );

      await a.feed.setCommentLike(l2.id, liked: true);
      await a.feed.setCommentLike(l2.id, liked: true);
      final liked = findCommentInTree(await a.feed.comments(post.id), l2.id)!;
      expect((liked.likedByMe, liked.likeCount), (true, 1));
      await a.feed.setCommentLike(l2.id, liked: false);
      expect(
        findCommentInTree(await a.feed.comments(post.id), l2.id)!.likeCount,
        0,
      );
    },
  );

  test(
    'paginação por cursor: mais de uma página, sem duplicar nem perder posts',
    skip: skip,
    () async {
      final a = await signUp('fj');
      final b = await signUp('fk');
      const total = 23;
      for (var i = 1; i <= total; i++) {
        await a.feed.create(content: 'post $i');
      }
      await b.follow(a.id);

      final ids = <String>[];
      String? cursor;
      var pages = 0;
      do {
        final page = await b.feed.feed(FeedScope.following, cursor: cursor);
        ids.addAll(page.items.map((p) => p.id));
        cursor = page.nextCursor;
        pages++;
      } while (cursor != null && pages < 10);

      expect(pages, 2, reason: '23 posts em páginas de 20');
      expect(ids.length, total);
      expect(ids.toSet().length, total, reason: 'sem duplicatas');
      final firstPage = await b.feed.feed(FeedScope.following);
      expect(
        firstPage.items.first.content,
        'post 23',
        reason: 'mais recente primeiro',
      );
    },
  );

  test(
    'atividade automática guarda o status do momento e sobrevive à exclusão do registro',
    skip: skip,
    () async {
      final a = await signUp('fl');
      final entry = await a.library.create(
        900001,
        const EntryDraft(platform: 'PC', status: GameStatus.playing),
      );
      await a.library.update(
        entry,
        EntryDraft.fromEntry(entry).withStatus(GameStatus.completed),
      );
      await Future<void>.delayed(
        const Duration(milliseconds: 500),
      ); // atividade é criada de forma assíncrona

      Future<List<Post>> activities() async {
        final r = await a.dio.get<Map<String, dynamic>>(
          '/users/${a.id}/posts',
          queryParameters: {'type': 'activity'},
        );
        return PostPage.fromJson(r.data!).items;
      }

      var list = await activities();
      final statuses = list.map((p) => p.activityStatus).toSet();
      expect(
        statuses,
        containsAll([GameStatus.playing, GameStatus.completed]),
        reason: 'um post por mudança, com o status de cada momento',
      );
      expect(list.every((p) => p.entry?.id == entry.id), isTrue);

      await a.library.delete(entry.id);
      list = await activities();
      expect(list.length, 2, reason: 'o histórico continua');
      expect(
        list.every((p) => p.entry == null),
        isTrue,
        reason: 'registro apagado vira nulo, o post fica',
      );
      expect(
        list.map((p) => p.activityStatus).toSet(),
        containsAll([GameStatus.playing, GameStatus.completed]),
      );
    },
  );

  test(
    'post inexistente e texto acima do limite viram erros de domínio',
    skip: skip,
    () async {
      final a = await signUp('fm');
      await expectLater(
        a.feed.post('00000000-0000-0000-0000-000000000000'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
      );
      await expectLater(
        a.feed.create(content: 'x' * 501),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 400)),
      );
    },
  );
}

extension on EntryDraft {
  EntryDraft withStatus(GameStatus s) => EntryDraft(
    platform: platform,
    status: s,
    startedAt: startedAt,
    finishedAt: finishedAt,
    hoursPlayed: hoursPlayed,
    rating: rating,
    notes: notes,
  );
}
