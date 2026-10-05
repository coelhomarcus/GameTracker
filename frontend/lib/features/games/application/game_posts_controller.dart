import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../feed/application/feed_controller.dart';
import '../../feed/data/post_models.dart';

/// Posts sobre um jogo, paginados por cursor. A chave é o UUID interno do jogo (`Game.id`): o
/// endpoint não conhece o `igdbId`. Os posts ficam no `PostStore`; aqui só os ids e o cursor, e a
/// deduplicação, o erro de rodapé e o descarte ao trocar de conta vêm de [PagedPostsController].
class GamePostsController extends PagedPostsController {
  GamePostsController(this.gameId);
  final String gameId;

  @override
  Future<PostPage> fetchPage(String? cursor) =>
      ref.read(feedRepositoryProvider).gamePosts(gameId, cursor: cursor);
}

final gamePostsControllerProvider = AsyncNotifierProvider.autoDispose
    .family<GamePostsController, FeedState, String>(GamePostsController.new);
