import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/design_system/async_content.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/design_system/user_avatar.dart';
import '../../../core/models/user_summary.dart';
import '../application/profile_providers.dart';
import '../data/profile_models.dart';
import 'follow_button.dart';

/// Busca de pessoas. No seletor de conversa (modal) traz o próprio campo; em Explorar a consulta
/// vem de fora ([query]) e só os resultados são desenhados. Termos curtos não consultam o
/// servidor; erro é diferente de "nenhuma pessoa encontrada".
class PeopleSearchView extends ConsumerStatefulWidget {
  const PeopleSearchView({
    super.key,
    this.onSelect,
    this.onOpenProfile,
    this.query,
    this.idle,
    this.autofocus = false,
  });

  /// Quando informado, tocar numa pessoa a escolhe (em vez de abrir o perfil) e não há botão de seguir.
  /// Usado para escolher com quem iniciar uma conversa.
  final void Function(UserSummary user)? onSelect;

  /// Chamado ao abrir o perfil de um resultado (Explorar guarda a pesquisa como recente).
  final void Function(UserSummary user)? onOpenProfile;

  /// Consulta controlada de fora: sem ela, a visão tem o próprio campo de busca.
  final String? query;

  /// O que mostrar enquanto o termo é curto demais para buscar (só com [query]).
  final Widget? idle;
  final bool autofocus;

  bool get _controlled => query != null;

  @override
  ConsumerState<PeopleSearchView> createState() => _PeopleSearchViewState();
}

class _PeopleSearchViewState extends ConsumerState<PeopleSearchView> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final term = (widget._controlled ? widget.query! : _query).trim();
    const hint = EmptyView(
      icon: Icons.group_outlined,
      title: 'Encontre pessoas',
      message: 'Busque pelo nome ou username. Digite pelo menos 2 letras.',
    );
    if (widget._controlled) {
      return term.length < peopleSearchMinChars
          ? (widget.idle ?? hint)
          : _results(term);
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.lg,
            Space.sm,
            Space.lg,
            Space.sm,
          ),
          child: SearchBar(
            controller: _controller,
            autoFocus: widget.autofocus,
            hintText: 'Buscar pessoas',
            leading: const Icon(Icons.search),
            trailing: [
              if (_query.isNotEmpty)
                IconButton(
                  tooltip: 'Limpar busca de pessoas',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _controller.clear();
                    setState(() => _query = '');
                  },
                ),
            ],
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: term.length < peopleSearchMinChars ? hint : _results(term),
        ),
      ],
    );
  }

  Widget _results(String term) {
    final results = ref.watch(peopleSearchProvider(term));
    return AsyncContent<List<PersonResult>>(
      value: results,
      onRetry: () => ref.invalidate(peopleSearchProvider(term)),
      data: (people) {
        if (people.isEmpty) {
          return EmptyView(
            icon: Icons.person_search_outlined,
            title: 'Ninguém encontrado',
            message: 'Nada para "$term".',
          );
        }
        return ListView.separated(
          key: const PageStorageKey('explore-people'),
          padding: const EdgeInsets.only(bottom: Space.xl),
          itemCount: people.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final person = people[i];
            final user = person.user;
            return ListTile(
              leading: UserAvatar(name: user.displayName, url: user.avatarUrl),
              title: Text(
                user.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@${user.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (person.bioOrNull != null)
                    Text(
                      person.bioOrNull!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
              trailing: widget.onSelect != null
                  ? null
                  : FollowButton(
                      userId: user.id,
                      serverFollowing: person.isFollowedByMe,
                      name: user.displayName,
                    ),
              onTap: () {
                if (widget.onSelect != null) {
                  widget.onSelect!(user);
                  return;
                }
                widget.onOpenProfile?.call(user);
                context.push('/users/${user.id}');
              },
            );
          },
        );
      },
    );
  }
}
