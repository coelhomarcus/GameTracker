import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/design_system/tokens.dart';
import '../../../core/models/user_summary.dart';
import '../../../core/network/error_messages.dart';
import '../../profiles/presentation/people_search_view.dart';
import '../application/chat_drafts.dart';
import '../application/chat_providers.dart';
import '../application/conversations_controller.dart';

/// Escolher uma pessoa para conversar. Devolve a pessoa escolhida ou `null`.
Future<UserSummary?> pickPerson(BuildContext context) {
  return showModalBottomSheet<UserSummary>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Nova conversa',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          Expanded(
            child: PeopleSearchView(
              onSelect: (user) => Navigator.of(context).pop(user),
              autofocus: true,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Cria (ou reaproveita) a conversa 1:1 com [userId] e a abre. O backend garante uma só conversa
/// por par, mesmo que as duas pessoas iniciem ao mesmo tempo.
Future<void> startConversation(
  BuildContext context,
  WidgetRef ref,
  String userId,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final wide = MediaQuery.sizeOf(context).width >= 840;
  try {
    final id = await ref.read(chatRepositoryProvider).openWith(userId);
    // A conversa pode ser nova: a lista em cache precisa conhecê-la antes de a tela abrir.
    await ref.read(conversationsControllerProvider.notifier).refresh();
    if (wide) {
      ref.read(selectedConversationProvider.notifier).select(id);
      router.go('/messages');
    } else {
      router.push('/messages/$id');
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(describeError(e))));
  }
}
