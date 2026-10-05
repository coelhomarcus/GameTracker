import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../feed/application/feed_controller.dart';

/// Estado de "sigo esta pessoa" conhecido localmente. Busca e perfil leem daqui, então seguir em
/// uma tela aparece nas outras sem refetch.
class FollowInfo {
  const FollowInfo({required this.following, required this.followerDelta});

  final bool following;

  /// Ajuste a somar ao contador de seguidores que veio do servidor (+1 ao seguir, −1 ao deixar).
  final int followerDelta;
}

class FollowStore extends Notifier<Map<String, FollowInfo>> {
  final _pending = <String>{};

  @override
  Map<String, FollowInfo> build() {
    ref.watch(currentUserIdProvider);
    _pending.clear();
    return const {};
  }

  /// O servidor é a verdade: ao carregar um perfil ou um resultado de busca, o ajuste local é
  /// descartado (o contador novo já inclui a ação). Ignorado enquanto há uma alteração em
  /// andamento para esta pessoa, para não sobrescrever a resposta imediata da tela.
  void sync(String userId) {
    if (_pending.contains(userId) || !state.containsKey(userId)) return;
    state = {...state}..remove(userId);
  }

  bool isPending(String userId) => _pending.contains(userId);

  /// Resposta imediata com rollback em erro, uma alternância por vez por pessoa.
  /// [currentlyFollowing] é o que a tela está mostrando agora.
  Future<void> toggle(String userId, {required bool currentlyFollowing}) async {
    if (_pending.contains(userId)) return;
    final accountId = ref.read(currentUserIdProvider);
    final before = state[userId];
    final target = !currentlyFollowing;

    _pending.add(userId);
    state = {
      ...state,
      userId: FollowInfo(
        following: target,
        followerDelta: (before?.followerDelta ?? 0) + (target ? 1 : -1),
      ),
    };
    try {
      await ref
          .read(profilesRepositoryProvider)
          .setFollow(userId, follow: target);
      // Seguir muda o que o feed Seguindo mostra.
      ref.read(feedRevalidatorProvider).markStale();
    } catch (_) {
      if (ref.read(currentUserIdProvider) == accountId) {
        final next = {...state};
        if (before == null) {
          next.remove(userId);
        } else {
          next[userId] = before;
        }
        state = next;
      }
      rethrow;
    } finally {
      _pending.remove(userId);
    }
  }
}

final followStoreProvider =
    NotifierProvider<FollowStore, Map<String, FollowInfo>>(FollowStore.new);
