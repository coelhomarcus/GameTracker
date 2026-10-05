import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_info.dart';
import '../../../app/providers.dart';
import '../../../app/theme_mode.dart';
import '../../../core/design_system/page_container.dart';
import '../../../core/design_system/section_header.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/navigation/back_navigation.dart';
import '../../auth/presentation/session_state.dart';
import '../../push/application/push_controller.dart';

/// Configurações: aparência (preferência local), conta, versão e sair.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
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
            ).copyWith(top: Space.lg, bottom: Space.lg),
            children: [
              const SectionHeader(title: 'Aparência'),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto),
                    label: Text('Sistema'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode),
                    label: Text('Claro'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode),
                    label: Text('Escuro'),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (s) =>
                    ref.read(themeModeProvider.notifier).set(s.first),
              ),
              const SizedBox(height: Space.xs),
              Text('Guardado neste aparelho.', style: text.bodySmall),
              const SizedBox(height: Space.xl),
              const SectionHeader(title: 'Notificações'),
              const _PushTile(),
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
              OutlinedButton.icon(
                onPressed: () =>
                    ref.read(sessionControllerProvider.notifier).logout(),
                icon: const Icon(Icons.logout),
                label: const Text('Sair'),
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

/// Estado do push neste aparelho. Mostra sempre o motivo de não estar ativo.
class _PushTile extends ConsumerWidget {
  const _PushTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(pushControllerProvider);
    final (subtitle, action) = switch (status) {
      PushStatus.unsupported => (
        'Indisponível neste dispositivo. As notificações aparecem na central dentro do app.',
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
