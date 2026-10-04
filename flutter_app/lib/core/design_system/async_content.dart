import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../network/error_messages.dart';
import 'tokens.dart';

/// Os três estados de um dado remoto. Enquanto há dado anterior, ele continua na tela: um
/// refresh em andamento ou que falhou não troca a lista por um spinner ou por um erro.
/// Com [staleBanner], a falha do refresh é avisada acima do conteúdo.
class AsyncContent<T> extends StatelessWidget {
  const AsyncContent({
    super.key,
    required this.value,
    required this.data,
    required this.onRetry,
    this.loading,
    this.staleBanner = false,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback onRetry;
  final Widget? loading;
  final bool staleBanner;

  @override
  Widget build(BuildContext context) {
    if (value.hasValue) {
      final content = data(value.requireValue);
      if (staleBanner && value.hasError) {
        return Column(
          children: [
            _StaleBanner(
              message: describeError(value.error!),
              onRetry: onRetry,
            ),
            Expanded(child: content),
          ],
        );
      }
      return content;
    }
    return value.when(
      data: data,
      loading: () => loading ?? const LoadingView(),
      error: (error, _) =>
          ErrorView(message: describeError(error), onRetry: onRetry),
    );
  }
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Material(
        color: scheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.lg,
            vertical: Space.sm,
          ),
          child: Row(
            spacing: Space.md,
            children: [
              Icon(Icons.cloud_off, size: 20, color: scheme.onErrorContainer),
              Expanded(
                child: Text(
                  'Não foi possível atualizar. Mostrando os dados salvos.',
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
              TextButton(
                onPressed: onRetry,
                child: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      label: 'Carregando',
      child: const CircularProgressIndicator(),
    ),
  );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 40,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: Space.md),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: Space.lg),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado vazio com ação opcional.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: Space.lg),
              Text(title, style: text.titleMedium, textAlign: TextAlign.center),
              if (message != null) ...[
                const SizedBox(height: Space.sm),
                Text(message!, textAlign: TextAlign.center),
              ],
              if (action != null) ...[
                const SizedBox(height: Space.xl),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
