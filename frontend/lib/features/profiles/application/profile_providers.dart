import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../feed/application/feed_controller.dart';
import '../../feed/data/post_models.dart';
import '../../games/data/game_models.dart';
import '../../library/data/game_entry.dart';
import '../data/profile_models.dart';
import 'follow_store.dart';

/// Perfil de uma pessoa, pelo id (o username pode mudar, o id não).
final profileProvider = FutureProvider.autoDispose.family<UserProfile, String>((
  ref,
  userId,
) async {
  ref.watch(currentUserIdProvider);
  final profile = await ref.watch(profilesRepositoryProvider).profile(userId);
  // Dados novos do servidor já incluem qualquer follow feito nesta sessão.
  ref.read(followStoreProvider.notifier).sync(userId);
  return profile;
});

final profileFavoritesProvider = FutureProvider.autoDispose
    .family<List<Game>, String>((ref, userId) {
      ref.watch(currentUserIdProvider);
      return ref.watch(profilesRepositoryProvider).favorites(userId);
    });

/// Coleção pública de uma pessoa (somente leitura).
final profileCollectionProvider = FutureProvider.autoDispose
    .family<List<GameEntry>, String>((ref, userId) {
      ref.watch(currentUserIdProvider);
      return ref.watch(profilesRepositoryProvider).collection(userId);
    });

typedef UserPostsKey = ({String userId, bool activities});

/// Atividades ou publicações de um perfil, paginadas como o feed.
class UserPostsController extends PagedPostsController {
  UserPostsController(this.key);
  final UserPostsKey key;

  @override
  Future<PostPage> fetchPage(String? cursor) => ref
      .read(feedRepositoryProvider)
      .userPosts(key.userId, activities: key.activities, cursor: cursor);
}

final userPostsControllerProvider = AsyncNotifierProvider.autoDispose
    .family<UserPostsController, FeedState, UserPostsKey>(
      UserPostsController.new,
    );

/// Busca de pessoas: mesmo padrão da busca de jogos (debounce, mínimo de letras, cancelamento).
const peopleSearchDebounce = Duration(milliseconds: 400);
const peopleSearchMinChars = 2;

final peopleSearchProvider = FutureProvider.autoDispose
    .family<List<PersonResult>, String>((ref, query) async {
      final term = query.trim();
      if (term.length < peopleSearchMinChars) return const [];

      // Ao digitar mais, este provider é descartado: a espera é abandonada e a requisição cancelada.
      final cancelToken = CancelToken();
      ref.onDispose(() => cancelToken.cancel());
      await Future<void>.delayed(peopleSearchDebounce);
      if (cancelToken.isCancelled) return const [];

      final results = await ref
          .watch(profilesRepositoryProvider)
          .search(term, cancelToken: cancelToken);
      final follows = ref.read(followStoreProvider.notifier);
      for (final r in results) {
        follows.sync(r.user.id);
      }
      return results;
    });
