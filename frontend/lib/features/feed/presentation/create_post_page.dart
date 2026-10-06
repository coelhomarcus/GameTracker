import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/providers.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/network/error_messages.dart';
import '../../../core/navigation/back_navigation.dart';
import '../../auth/presentation/auth_form_scaffold.dart';
import '../../games/data/game_models.dart';
import '../../games/presentation/game_search_view.dart';
import '../../library/application/library_controller.dart';
import '../../library/data/game_entry.dart';
import '../application/post_store.dart';

const maxPostLength = 500;

/// Compor um post. Pode vir ligado a um registro (`entryId`) e com
/// um texto sugerido. Em falha o texto e os vínculos ficam como estão.
class CreatePostPage extends ConsumerStatefulWidget {
  const CreatePostPage({
    super.key,
    this.entryId,
    this.igdbId,
    this.initialText,
  });

  /// Registro ao qual o post fica ligado. Tem precedência sobre [igdbId] quando é válido.
  final String? entryId;

  /// Jogo (pelo `igdbId` do catálogo) ao qual o post fica ligado; é resolvido para o UUID.
  final int? igdbId;
  final String? initialText;

  @override
  ConsumerState<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends ConsumerState<CreatePostPage> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initialText ?? '',
  );
  late final String _initialText = widget.initialText ?? '';

  Game? _game;
  GameEntry? _entry;
  bool _loadingGame = false;

  /// O vínculo pedido (pela rota ou escolhido) não pôde ser resolvido. Publicar fica bloqueado
  /// até tentar de novo ou remover o vínculo de propósito: nunca sai um post genérico em silêncio.
  _LinkFailure? _linkFailure;
  bool _sending = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.entryId != null) {
      _resolveEntry(widget.entryId!);
    } else if (widget.igdbId != null) {
      _resolveGame(widget.igdbId!);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// O registro vem da coleção carregada, então a tela abre direto de um deep link. Se não for
  /// possível resolvê-lo, o jogo da rota (se houver) é o vínculo; senão, o usuário decide.
  Future<void> _resolveEntry(String id) async {
    setState(() {
      _loadingGame = true;
      _linkFailure = null;
    });
    try {
      final entries = await ref.read(libraryProvider.future);
      final match = entries.where((e) => e.id == id).firstOrNull;
      if (!mounted) return;
      if (match == null) {
        if (widget.igdbId != null) {
          await _resolveGame(widget.igdbId!);
          return;
        }
        setState(() {
          _loadingGame = false;
          _linkFailure = _LinkFailure(
            'Não encontramos o registro deste post.',
            () => _resolveEntry(id),
          );
        });
        return;
      }
      setState(() {
        _entry = match;
        _game = match.game;
        _loadingGame = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingGame = false;
        _linkFailure = _LinkFailure(describeError(e), () => _resolveEntry(id));
      });
    }
  }

  /// O backend vincula pelo UUID do jogo; a busca e a rota só trazem o `igdbId`.
  Future<void> _resolveGame(int igdbId) async {
    setState(() {
      _loadingGame = true;
      _linkFailure = null;
      _error = null;
    });
    try {
      final game = await ref.read(gamesRepositoryProvider).byIgdbId(igdbId);
      if (!mounted) return;
      setState(() {
        _game = game;
        _entry = null;
        _loadingGame = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingGame = false;
        _linkFailure = _LinkFailure(
          'Não foi possível vincular ao jogo. ${describeError(e)}',
          () => _resolveGame(igdbId),
        );
      });
    }
  }

  Future<void> _pickGame() async {
    final picked = await pickGame(context);
    if (picked == null || !mounted) return;
    await _resolveGame(picked.igdbId);
  }

  void _removeGame() => setState(() {
    _game = null;
    _entry = null;
    _linkFailure = null;
  });

  bool get _dirty =>
      !_done &&
      !_sending &&
      _text.text.trim().isNotEmpty &&
      _text.text != _initialText;

  Future<void> _publish() async {
    final content = _text.text.trim();
    if (_sending || content.isEmpty || content.length > maxPostLength) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(postStoreProvider.notifier)
          .create(content: content, gameId: _game?.id, gameEntryId: _entry?.id);
      messenger.showSnackBar(const SnackBar(content: Text('Publicado')));
      if (!mounted) return;
      _done = true;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/community');
      }
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmDiscard() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar publicação?'),
        content: const Text('O texto que você escreveu não foi publicado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuar editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      _done = true;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/community');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final library = ref.watch(libraryProvider).value ?? const <GameEntry>[];
    final entriesForGame = _game == null
        ? const <GameEntry>[]
        : library.where((e) => e.game.id == _game!.id).toList();

    return ListenableBuilder(
      listenable: _text,
      builder: (context, child) {
        final length = _text.text.trim().length;
        final canPublish =
            !_sending &&
            !_loadingGame &&
            _linkFailure == null &&
            length > 0 &&
            length <= maxPostLength;
        return PopScope(
          canPop: !_dirty,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmDiscard();
          },
          child: Scaffold(
            appBar: AppBar(
              leading: const FallbackBackButton(fallback: '/community'),
              title: const Text('Nova publicação'),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: Space.sm),
                  child: FilledButton(
                    onPressed: canPublish ? _publish : null,
                    child: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Publicar'),
                  ),
                ),
              ],
            ),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: ListView(
                    padding: const EdgeInsets.all(Space.lg),
                    children: [
                      if (_error != null) ...[
                        FormErrorBanner(_error!),
                        const SizedBox(height: Space.lg),
                      ],
                      TextField(
                        controller: _text,
                        enabled: !_sending,
                        autofocus: true,
                        minLines: 5,
                        maxLines: 10,
                        maxLength: maxPostLength,
                        keyboardType: TextInputType.multiline,
                        decoration: const InputDecoration(
                          labelText: 'O que você quer compartilhar?',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: Space.lg),
                      Text('Jogo (opcional)', style: text.titleSmall),
                      const SizedBox(height: Space.sm),
                      _gameLink(),
                      if (entriesForGame.isNotEmpty) ...[
                        const SizedBox(height: Space.lg),
                        Text('Registro (opcional)', style: text.titleSmall),
                        const SizedBox(height: Space.sm),
                        Wrap(
                          spacing: Space.sm,
                          runSpacing: Space.sm,
                          children: [
                            ChoiceChip(
                              label: const Text('Nenhum'),
                              selected: _entry == null,
                              onSelected: _sending
                                  ? null
                                  : (_) => setState(() => _entry = null),
                            ),
                            for (final e in entriesForGame)
                              ChoiceChip(
                                avatar: Icon(e.status.icon, size: 18),
                                label: Text(
                                  '${e.platform} · ${e.status.label}',
                                ),
                                selected: _entry?.id == e.id,
                                onSelected: _sending
                                    ? null
                                    : (_) => setState(() => _entry = e),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _gameLink() {
    if (_loadingGame) {
      return Row(
        spacing: Space.md,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: const Text('Vinculando ao jogo…'),
            ),
          ),
        ],
      );
    }
    final failure = _linkFailure;
    if (failure != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormErrorBanner(failure.message),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            children: [
              FilledButton.tonal(
                onPressed: failure.retry,
                child: const Text('Tentar de novo'),
              ),
              TextButton(
                onPressed: _removeGame,
                child: const Text('Publicar sem vínculo'),
              ),
            ],
          ),
        ],
      );
    }
    final game = _game;
    if (game != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: InputChip(
          avatar: const Icon(Icons.sports_esports, size: 18),
          label: Text(game.name),
          onDeleted: _sending ? null : _removeGame,
          deleteButtonTooltipMessage: 'Remover vínculo com o jogo',
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: _sending ? null : _pickGame,
        icon: const Icon(Icons.add_link),
        label: const Text('Vincular um jogo'),
      ),
    );
  }
}

/// Por que o vínculo falhou e como tentar de novo.
class _LinkFailure {
  const _LinkFailure(this.message, this.retry);

  final String message;
  final VoidCallback retry;
}
