import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/design_system/async_content.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/design_system/user_avatar.dart';
import '../application/profile_providers.dart';
import '../data/profile_models.dart';
import 'follow_button.dart';

/// Busca de pessoas (aba Pessoas de Explorar). Termos curtos não consultam o servidor; erro é
/// diferente de "nenhuma pessoa encontrada".
class PeopleSearchView extends ConsumerStatefulWidget {
  const PeopleSearchView({super.key});

  @override
  ConsumerState<PeopleSearchView> createState() => _PeopleSearchViewState();
}

class _PeopleSearchViewState extends ConsumerState<PeopleSearchView>
    with AutomaticKeepAliveClientMixin {
  final _controller = TextEditingController();
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final term = _query.trim();
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
          child: term.length < peopleSearchMinChars
              ? const EmptyView(
                  icon: Icons.group_outlined,
                  title: 'Encontre pessoas',
                  message: 'Busque pelo nome ou username. Digite pelo menos 2 letras.',
                )
              : _results(term),
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
              subtitle: Text(
                person.bioOrNull == null
                    ? '@${user.username}'
                    : '@${user.username} · ${person.bioOrNull}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: FollowButton(
                userId: user.id,
                serverFollowing: person.isFollowedByMe,
                name: user.displayName,
              ),
              onTap: () => context.push('/users/${user.id}'),
            );
          },
        );
      },
    );
  }
}
