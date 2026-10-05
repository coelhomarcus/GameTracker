import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/providers.dart';
import '../../../core/design_system/tokens.dart';

/// Enquanto a sessão guardada é restaurada.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Semantics(
        label: 'Carregando',
        child: const CircularProgressIndicator(),
      ),
    ),
  );
}

/// Credenciais guardadas, mas sem resposta do servidor: não força logout.
class RestoreUnavailablePage extends ConsumerWidget {
  const RestoreUnavailablePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(sessionControllerProvider.notifier);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Space.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: Space.lg),
                  Text(
                    'Não foi possível conectar',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: Space.sm),
                  const Text(
                    'Sua sessão está guardada. Verifique a conexão e tente de novo.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Space.xl),
                  FilledButton(
                    onPressed: controller.bootstrap,
                    child: const Text('Tentar novamente'),
                  ),
                  const SizedBox(height: Space.sm),
                  TextButton(
                    onPressed: controller.logout,
                    child: const Text('Sair da conta'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
