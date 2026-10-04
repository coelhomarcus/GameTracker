import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/error_messages.dart';
import '../application/follow_store.dart';

/// "Sigo esta pessoa?" como a tela deve mostrar: o ajuste local (resposta imediata) vence o
/// valor que veio do servidor.
bool effectiveFollowing(
  Map<String, FollowInfo> store,
  String userId, {
  required bool serverValue,
}) => store[userId]?.following ?? serverValue;

/// Contador de seguidores com o ajuste local somado.
int effectiveFollowerCount(
  Map<String, FollowInfo> store,
  String userId, {
  required int serverValue,
}) => serverValue + (store[userId]?.followerDelta ?? 0);

/// Seguir/Seguindo. Mesma resposta imediata e mesmo rollback em qualquer tela.
class FollowButton extends ConsumerWidget {
  const FollowButton({
    super.key,
    required this.userId,
    required this.serverFollowing,
    required this.name,
  });

  final String userId;
  final bool serverFollowing;

  /// Nome para o rótulo de acessibilidade.
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final following = effectiveFollowing(
      ref.watch(followStoreProvider),
      userId,
      serverValue: serverFollowing,
    );

    Future<void> toggle() async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref
            .read(followStoreProvider.notifier)
            .toggle(userId, currentlyFollowing: following);
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(describeError(e))));
      }
    }

    final label = following ? 'Seguindo' : 'Seguir';
    return Semantics(
      button: true,
      label: following ? 'Deixar de seguir $name' : 'Seguir $name',
      excludeSemantics: true,
      child: following
          ? OutlinedButton.icon(
              onPressed: toggle,
              icon: const Icon(Icons.check, size: 18),
              label: Text(label),
            )
          : FilledButton(onPressed: toggle, child: Text(label)),
    );
  }
}
