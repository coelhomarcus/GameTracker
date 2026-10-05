import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_info.dart';
import '../../../app/providers.dart';
import '../../../app/theme_mode.dart';
import '../../../core/design_system/app_theme.dart';
import '../../../core/design_system/page_container.dart';
import '../../../core/design_system/section_header.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/navigation/back_navigation.dart';
import '../../auth/presentation/session_state.dart';
import '../../chat/application/chat_drafts.dart';
import '../../library/application/library_prefs.dart';
import '../../push/application/push_controller.dart';

/// Configurações, em uma coluna de leitura: Aparência, Biblioteca, Notificações, Conta e Sobre.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  /// Sair descarta a sessão, o socket e o estado da conta, inclusive rascunhos de conversa que
  /// ainda não foram enviados; nesse caso pergunta antes. Sem rascunho, sai direto.
  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final drafts = ref.read(chatDraftsProvider);
    if (drafts.isNotEmpty) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sair da conta?'),
          content: Text(
            drafts.length == 1
                ? 'Você tem uma mensagem escrita e não enviada. Ela será descartada.'
                : 'Você tem ${drafts.length} mensagens escritas e não enviadas. Elas serão descartadas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Continuar no app'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sair'),
            ),
          ],
        ),
      );
      if (leave != true) return;
    }
    await ref.read(sessionControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: const FallbackBackButton(fallback: '/me'),
        title: const Text('Configurações'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => ListView(
            padding: PageContainer.insetsFor(
              box.maxWidth,
              PageWidth.reading,
            ).copyWith(top: Space.lg, bottom: Space.xl),
            children: [
              const SectionHeader(title: 'Aparência'),
              const _ThemeChoice(),
              const SizedBox(height: Space.sm),
              Text('Preferência deste aparelho.', style: text.bodySmall),
              const SizedBox(height: Space.xl),
              const SectionHeader(title: 'Biblioteca'),
              const _LibraryPrefs(),
              const SizedBox(height: Space.xl),
              const SectionHeader(title: 'Notificações'),
              const _NotificationsSection(),
              const SizedBox(height: Space.xl),
              const SectionHeader(title: 'Conta'),
              if (session is SessionAuthenticated) ...[
                Text(session.user.displayName, style: text.bodyLarge),
                Text(
                  '@${session.user.username} · ${session.user.email}',
                  style: text.bodyMedium,
                ),
                const SizedBox(height: Space.md),
              ],
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.push('/me/edit'),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar perfil'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _logout(context, ref),
                    icon: const Icon(Icons.logout),
                    label: const Text('Sair'),
                  ),
                ],
              ),
              const SizedBox(height: Space.xl),
              const SectionHeader(title: 'Sobre'),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('GameTracker'),
                subtitle: Text('Versão $appVersion'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sistema, Claro ou Escuro: cada opção mostra uma amostra das cores e a escolhida fica marcada
/// (borda, ícone e texto, não só cor).
class _ThemeChoice extends ConsumerWidget {
  const _ThemeChoice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return Wrap(
      spacing: Space.md,
      runSpacing: Space.md,
      children: [
        for (final (value, label) in const [
          (ThemeMode.system, 'Sistema'),
          (ThemeMode.light, 'Claro'),
          (ThemeMode.dark, 'Escuro'),
        ])
          _ThemeOption(
            mode: value,
            label: label,
            selected: mode == value,
            onTap: () => ref.read(themeModeProvider.notifier).set(value),
          ),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // O texto e a amostra são só visuais: o nó acessível (rótulo, seleção, toque e foco) é um só.
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: onTap,
        child: ExcludeSemantics(
          child: AnimatedContainer(
            duration: Motion.resolve(context, Motion.short),
            constraints: const BoxConstraints(minWidth: 104),
            padding: const EdgeInsets.all(Space.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ThemeSample(mode: mode),
                const SizedBox(height: Space.sm),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: Space.xs,
                  children: [
                    if (selected)
                      Icon(Icons.check, size: 16, color: scheme.primary),
                    Text(label),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Miniatura de uma tela: fundo, uma barra de destaque e um cartão. "Sistema" divide a miniatura
/// entre claro e escuro.
class _ThemeSample extends StatelessWidget {
  const _ThemeSample({required this.mode});

  final ThemeMode mode;

  @override
  Widget build(BuildContext context) {
    final light = AppTheme.light().colorScheme;
    final dark = AppTheme.dark().colorScheme;
    Widget half(ColorScheme scheme) => ColoredBox(
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(Space.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 6, width: 24, color: scheme.primary),
            const Spacer(),
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.control),
        child: SizedBox(
          width: 88,
          height: 56,
          child: switch (mode) {
            ThemeMode.light => half(light),
            ThemeMode.dark => half(dark),
            ThemeMode.system => Row(
              children: [
                Expanded(child: half(light)),
                Expanded(child: half(dark)),
              ],
            ),
          },
        ),
      ),
    );
  }
}

/// Atalhos para o modo de exibição e a ordenação da Biblioteca: as mesmas preferências da própria
/// tela, não cópias.
class _LibraryPrefs extends ConsumerWidget {
  const _LibraryPrefs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(libraryPrefsProvider);
    final controller = ref.read(libraryPrefsProvider.notifier);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Exibição', style: text.titleMedium),
        const SizedBox(height: Space.sm),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: true,
              icon: Icon(Icons.grid_view),
              label: Text('Grade'),
            ),
            ButtonSegment(
              value: false,
              icon: Icon(Icons.view_list),
              label: Text('Lista'),
            ),
          ],
          selected: {prefs.grid},
          onSelectionChanged: (s) => controller.setGrid(s.first),
        ),
        const SizedBox(height: Space.lg),
        Text('Ordenar por', style: text.titleMedium),
        RadioGroup<LibrarySort>(
          groupValue: prefs.sort,
          onChanged: (sort) {
            if (sort != null) controller.setSort(sort);
          },
          child: Column(
            children: [
              for (final sort in LibrarySort.values)
                RadioListTile<LibrarySort>(
                  contentPadding: EdgeInsets.zero,
                  value: sort,
                  title: Text(sort.label),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A central de notificações e o estado do push neste aparelho.
class _NotificationsSection extends StatelessWidget {
  const _NotificationsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PushTile(),
        const SizedBox(height: Space.md),
        OutlinedButton.icon(
          onPressed: () => context.push('/notifications'),
          icon: const Icon(Icons.notifications_outlined),
          label: const Text('Abrir central de notificações'),
        ),
      ],
    );
  }
}

/// Estado do push neste aparelho. Mostra sempre o motivo de não estar ativo.
class _PushTile extends ConsumerWidget {
  const _PushTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(pushControllerProvider);
    final (subtitle, action) = switch (status) {
      PushStatus.unsupported => (
        'As notificações aparecem na central com o app aberto. Avisos com o app fechado não estão disponíveis nesta versão.',
        null,
      ),
      PushStatus.on => ('Ativadas neste aparelho.', null),
      PushStatus.registering => ('Ativando…', null),
      PushStatus.off => ('Desativadas neste aparelho.', 'Ativar'),
      PushStatus.denied => (
        'Bloqueadas nas configurações do sistema. Libere por lá para receber avisos.',
        'Tentar de novo',
      ),
      PushStatus.failed => (
        'Não foi possível ativar agora. Tente de novo.',
        'Tentar de novo',
      ),
    };
    final text = Theme.of(context).textTheme;
    // Coluna em vez de ListTile: com texto grande o botão não cabe no "trailing".
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              status == PushStatus.on
                  ? Icons.notifications_active
                  : Icons.notifications_off_outlined,
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notificações push', style: text.bodyLarge),
                  Text(subtitle, style: text.bodyMedium),
                ],
              ),
            ),
          ],
        ),
        if (action != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () =>
                  ref.read(pushControllerProvider.notifier).enable(),
              child: Text(action),
            ),
          ),
      ],
    );
  }
}
