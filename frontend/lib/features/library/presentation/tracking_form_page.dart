import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/data/hours.dart';
import '../../../core/dates/date_only.dart';
import '../../../core/design_system/async_content.dart';
import '../../../core/design_system/game_cover.dart';
import '../../../core/design_system/game_status.dart';
import '../../../core/design_system/page_container.dart';
import '../../../core/design_system/section_header.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/network/error_messages.dart';
import '../../../core/navigation/back_navigation.dart';
import '../../auth/presentation/auth_form_scaffold.dart';
import '../../games/application/game_providers.dart';
import '../../games/data/game_models.dart';
import '../application/library_controller.dart';
import '../data/game_entry.dart';

/// Criar (`entryId == null`) ou editar um playthrough. Tudo é carregado pelos ids da rota,
/// então o formulário abre direto de um deep link.
class TrackingFormPage extends ConsumerWidget {
  const TrackingFormPage({super.key, required this.igdbId, this.entryId});

  final int igdbId;
  final String? entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameControllerProvider(igdbId));
    final library = ref.watch(libraryProvider);
    final title = entryId == null ? 'Novo registro' : 'Editar registro';

    Widget scaffold(Widget body) => Scaffold(
      appBar: AppBar(
        leading: FallbackBackButton(fallback: '/games/$igdbId'),
        title: Text(title),
      ),
      body: body,
    );

    return game.when(
      loading: () => scaffold(const LoadingView()),
      error: (e, _) => scaffold(
        ErrorView(
          message: describeError(e),
          onRetry: () => ref.invalidate(gameControllerProvider(igdbId)),
        ),
      ),
      data: (game) => library.when(
        loading: () => scaffold(const LoadingView()),
        error: (e, _) => scaffold(
          ErrorView(
            message: describeError(e),
            onRetry: () => ref.invalidate(libraryProvider),
          ),
        ),
        data: (entries) {
          GameEntry? entry;
          if (entryId != null) {
            for (final e in entries) {
              if (e.id == entryId) entry = e;
            }
            if (entry == null) {
              return scaffold(
                EmptyView(
                  icon: Icons.search_off,
                  title: 'Registro não encontrado',
                  message: 'Ele pode ter sido removido.',
                  action: FilledButton(
                    onPressed: () => context.go('/games/$igdbId'),
                    child: const Text('Voltar ao jogo'),
                  ),
                ),
              );
            }
          }
          final replays = entries.where((e) => e.game.id == game.id).length;
          return TrackingForm(
            game: game,
            entry: entry,
            existingForGame: replays,
          );
        },
      ),
    );
  }
}

/// Regras de validação do formulário, separadas da tela para serem testadas.
abstract final class TrackingRules {
  static String? hours(
    String text, {
    required DateOnly? start,
    required DateOnly? end,
    required DateOnly today,
  }) {
    if (text.trim().isEmpty) return null;
    final value = parseHours(text);
    if (value == null) return 'Use só números, como 12 ou 12,5.';
    if (value > maxHoursPlayed) {
      return 'O máximo é ${formatHours(maxHoursPlayed)} horas.';
    }
    final ceiling = maxPlausibleHours(start, end, today: today);
    if (value > ceiling) {
      final span = end != null ? 'entre início e fim' : 'entre o início e hoje';
      return 'Isso passa das ${ceiling.toInt()} h possíveis $span. Confira as datas.';
    }
    return null;
  }

  static String? period({required DateOnly? start, required DateOnly? end}) {
    if (start != null && end != null && start.isAfter(end)) {
      return 'O fim não pode ser antes do início.';
    }
    return null;
  }
}

class TrackingForm extends ConsumerStatefulWidget {
  const TrackingForm({
    super.key,
    required this.game,
    this.entry,
    this.existingForGame = 0,
    this.today,
  });

  final Game game;
  final GameEntry? entry;

  /// Registros que o usuário já tem deste jogo (para avisar que criar outro é um replay).
  final int existingForGame;

  /// Data de referência; injetável para testes.
  final DateOnly? today;

  @override
  ConsumerState<TrackingForm> createState() => _TrackingFormState();
}

class _TrackingFormState extends ConsumerState<TrackingForm> {
  final _formKey = GlobalKey<FormState>();
  late final DateOnly _today = widget.today ?? DateOnly.today();
  late final TextEditingController _platformText;
  late final TextEditingController _hours;
  late final TextEditingController _notes;

  late String _platform;

  /// "Outra": a plataforma é digitada em vez de escolhida entre as do catálogo.
  bool _customPlatform = false;
  late GameStatus _status;
  DateOnly? _start;
  DateOnly? _end;
  int? _rating;

  late final EntryDraft _initial;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.entry != null;
  bool get _hasPlatformOptions => _platformOptions.isNotEmpty;

  /// Sem plataformas no catálogo, ou com "Outra" escolhida, o campo é de texto.
  bool get _typedPlatform => !_hasPlatformOptions || _customPlatform;

  /// Plataformas do jogo; no modo edição mantém a atual mesmo que o cache não a liste.
  late final List<String> _platformOptions = [
    ...widget.game.platforms,
    if (widget.entry != null &&
        !widget.game.platforms.contains(widget.entry!.platform))
      widget.entry!.platform,
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _platform =
        e?.platform ??
        (widget.game.platforms.isNotEmpty ? widget.game.platforms.first : '');
    _status = e?.status ?? GameStatus.backlog;
    _start = e?.startedAt;
    _end = e?.finishedAt;
    _rating = e?.rating;
    // O campo digitado começa vazio quando há plataformas para escolher ("Outra").
    _platformText = TextEditingController(
      text: _hasPlatformOptions ? '' : _platform,
    );
    _hours = TextEditingController(
      text: e?.hoursPlayed == null ? '' : hoursInputText(e!.hoursPlayed!),
    );
    _notes = TextEditingController(text: e?.notes ?? '');
    _initial = _draft();
  }

  @override
  void dispose() {
    _platformText.dispose();
    _hours.dispose();
    _notes.dispose();
    super.dispose();
  }

  EntryDraft _draft() {
    final notes = _notes.text.trim();
    return EntryDraft(
      platform: _typedPlatform ? _platformText.text.trim() : _platform,
      status: _status,
      startedAt: _start,
      finishedAt: _end,
      hoursPlayed: parseHours(_hours.text),
      rating: _rating,
      notes: notes.isEmpty ? null : notes,
    );
  }

  bool get _dirty {
    final a = _initial;
    final b = _draft();
    final aNotes = a.notes?.trim() ?? '';
    return a.platform != b.platform ||
        a.status != b.status ||
        a.startedAt != b.startedAt ||
        a.finishedAt != b.finishedAt ||
        a.hoursPlayed != b.hoursPlayed ||
        a.rating != b.rating ||
        aNotes != (b.notes ?? '');
  }

  Future<void> _pickDate({required bool start}) async {
    final current = start ? _start : _end;
    final picked = await showDatePicker(
      context: context,
      initialDate: (current ?? _today).toLocalDateTime(),
      firstDate: DateTime(1970),
      lastDate: _today.toLocalDateTime(),
      helpText: start ? 'Data de início' : 'Data de fim',
      cancelText: 'Cancelar',
      confirmText: 'OK',
    );
    if (picked == null) return;
    setState(() {
      final date = DateOnly.fromLocal(picked);
      if (start) {
        _start = date;
      } else {
        _end = date;
      }
    });
    _formKey.currentState?.validate();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (TrackingRules.period(start: _start, end: _end) != null) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(libraryProvider.notifier);
    try {
      final draft = _draft();
      if (_editing) {
        await controller.edit(widget.entry!, draft);
      } else {
        await controller.create(widget.game.igdbId, draft);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(_editing ? 'Registro atualizado' : 'Registro criado'),
        ),
      );
      if (!mounted) return;
      // Já salvo: sair sem pedir confirmação de descarte.
      _saved = true;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/games/${widget.game.igdbId}');
      }
    } catch (e) {
      // Mantém tudo o que foi digitado; o usuário corrige ou tenta de novo.
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _saved = false;

  Future<void> _confirmDiscard() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar alterações?'),
        content: const Text('O que você preencheu não foi salvo.'),
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
      _saved = true;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/games/${widget.game.igdbId}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final periodError = TrackingRules.period(start: _start, end: _end);

    // Os campos de texto não chamam setState: sem ouvir os controllers, `canPop` ficaria
    // desatualizado e quem só digitou horas ou notas perderia tudo ao voltar.
    return ListenableBuilder(
      listenable: Listenable.merge([_hours, _notes, _platformText]),
      builder: (context, child) => PopScope(
        canPop: _saved || _saving || !_dirty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _confirmDiscard();
        },
        child: child!,
      ),
      child: Scaffold(
        appBar: AppBar(
          leading: FallbackBackButton(fallback: '/games/${widget.game.igdbId}'),
          title: Text(_editing ? 'Editar registro' : 'Novo registro'),
        ),
        // O salvar fica numa barra fora da lista: o corpo encolhe com o teclado, então ele nunca
        // some atrás dele nem do campo em foco.
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Form(
                  key: _formKey,
                  child: LayoutBuilder(
                    builder: (context, box) => ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: PageContainer.insetsFor(
                        box.maxWidth,
                        PageWidth.reading,
                      ).copyWith(top: Space.lg, bottom: Space.lg),
                      children: [
                        _header(text),
                        const SizedBox(height: Space.xl),
                        const SectionHeader(title: 'Status'),
                        _statusChips(),
                        const SizedBox(height: Space.xl),
                        const SectionHeader(title: 'Plataforma'),
                        _platformField(),
                        const SizedBox(height: Space.xl),
                        const SectionHeader(
                          title: 'Progresso',
                          hint: 'opcional',
                        ),
                        _periodRow(),
                        if (periodError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: Space.sm),
                            child: Text(
                              periodError,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        const SizedBox(height: Space.lg),
                        _hoursField(),
                        const SizedBox(height: Space.xl),
                        const SectionHeader(
                          title: 'Sua avaliação',
                          hint: 'opcional',
                        ),
                        _ratingField(text),
                        const SizedBox(height: Space.lg),
                        TextFormField(
                          controller: _notes,
                          enabled: !_saving,
                          decoration: const InputDecoration(
                            labelText: 'Notas pessoais',
                            helperText: 'Só você vê.',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          maxLines: 5,
                          minLines: 3,
                          maxLength: 2000,
                          keyboardType: TextInputType.multiline,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _saveBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(TextTheme text) {
    final existing = widget.existingForGame;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: Space.lg,
          children: [
            SizedBox(
              width: 72,
              child: GameCover(
                name: widget.game.name,
                url: widget.game.coverUrl,
                radius: Radii.cover,
              ),
            ),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(widget.game.name, style: text.titleLarge),
              ),
            ),
          ],
        ),
        if (!_editing && existing > 0) ...[
          const SizedBox(height: Space.md),
          Text(
            existing == 1
                ? 'Você já tem 1 registro deste jogo. Este será um novo registro.'
                : 'Você já tem $existing registros deste jogo. Este será um novo registro.',
            style: text.bodyMedium,
          ),
        ],
      ],
    );
  }

  Widget _statusChips() => Wrap(
    spacing: Space.sm,
    runSpacing: Space.sm,
    children: [
      for (final s in GameStatus.values)
        ChoiceChip(
          avatar: Icon(s.icon, size: 18),
          label: Text(s.label),
          selected: _status == s,
          onSelected: _saving ? null : (_) => setState(() => _status = s),
        ),
    ],
  );

  Widget _periodRow() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: Space.md,
    children: [
      Expanded(
        child: _DateField(
          label: 'Início',
          value: _start,
          enabled: !_saving,
          onPick: () => _pickDate(start: true),
          onClear: () => setState(() => _start = null),
        ),
      ),
      Expanded(
        child: _DateField(
          label: 'Fim',
          value: _end,
          enabled: !_saving,
          onPick: () => _pickDate(start: false),
          onClear: () => setState(() => _end = null),
        ),
      ),
    ],
  );

  Widget _hoursField() => TextFormField(
    controller: _hours,
    enabled: !_saving,
    decoration: const InputDecoration(
      labelText: 'Horas jogadas',
      suffixText: 'horas',
      helperText: 'Opcional. Aceita 12 ou 12,5.',
    ),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    textInputAction: TextInputAction.next,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    validator: (v) =>
        TrackingRules.hours(v ?? '', start: _start, end: _end, today: _today),
  );

  /// Salvar e o erro de rede ficam juntos, sempre à vista; os valores digitados não são limpos.
  Widget _saveBar() {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: LayoutBuilder(
        builder: (context, box) => Padding(
          padding: PageContainer.insetsFor(
            box.maxWidth,
            PageWidth.reading,
          ).copyWith(top: Space.sm, bottom: Space.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                FormErrorBanner(_error!),
                const SizedBox(height: Space.sm),
              ],
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Salvar registro'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _platformField() {
    final field = _typedPlatform
        ? TextFormField(
            controller: _platformText,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Plataforma',
              hintText: 'Ex.: PC',
            ),
            maxLength: 50,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Informe a plataforma' : null,
          )
        : null;
    if (!_hasPlatformOptions) return field!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final p in _platformOptions)
              ChoiceChip(
                label: Text(p),
                selected: !_customPlatform && _platform == p,
                onSelected: _saving
                    ? null
                    : (_) => setState(() {
                        _customPlatform = false;
                        _platform = p;
                      }),
              ),
            ChoiceChip(
              avatar: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Outra'),
              selected: _customPlatform,
              onSelected: _saving
                  ? null
                  : (_) => setState(() => _customPlatform = true),
            ),
          ],
        ),
        if (field != null) ...[const SizedBox(height: Space.md), field],
      ],
    );
  }

  /// Nota inteira de 1 a 10, ou "Sem nota". Sempre exibida como `8/10`.
  Widget _ratingField(TextTheme text) {
    final rating = _rating;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Space.md,
          children: [
            Text('Nota', style: text.titleMedium),
            Text(
              rating == null ? 'Sem nota' : '$rating/10',
              style: text.bodyLarge,
            ),
            if (rating != null)
              TextButton(
                onPressed: _saving
                    ? null
                    : () => setState(() => _rating = null),
                child: const Text('Sem nota'),
              ),
          ],
        ),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.xs,
          children: [
            for (var n = 1; n <= 10; n++)
              ChoiceChip(
                label: Semantics(
                  label: 'Nota $n de 10',
                  excludeSemantics: true,
                  child: Text('$n'),
                ),
                selected: rating == n,
                showCheckmark: false,
                onSelected: _saving
                    ? null
                    : (_) => setState(() => _rating = rating == n ? null : n),
              ),
          ],
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final DateOnly? value;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: value == null
          ? '$label: não definida'
          : '$label: ${value!.format()}',
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: enabled ? onPick : null,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: value == null
                ? const Icon(Icons.calendar_today_outlined)
                : IconButton(
                    tooltip: 'Limpar $label',
                    icon: const Icon(Icons.close),
                    onPressed: enabled ? onClear : null,
                  ),
          ),
          child: Text(value?.format() ?? 'Opcional'),
        ),
      ),
    );
  }
}
