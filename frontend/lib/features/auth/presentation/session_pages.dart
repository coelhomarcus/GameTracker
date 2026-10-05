import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/providers.dart';
import '../../../core/design_system/async_content.dart';
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
        child: EmptyView(
          icon: Icons.cloud_off,
          title: 'Não foi possível conectar',
          message:
              'Sua sessão está guardada. Verifique a conexão e tente de novo.',
          action: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: Space.sm,
            children: [
              FilledButton(
                onPressed: controller.bootstrap,
                child: const Text('Tentar novamente'),
              ),
              TextButton(
                onPressed: controller.logout,
                child: const Text('Sair da conta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
