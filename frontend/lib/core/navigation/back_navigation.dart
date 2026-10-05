import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Volta para a tela anterior; se a página foi aberta por link, sem pilha, vai para [fallback].
///
/// Sem pilha, o `PopScope` da página é consultado antes (`maybePop`): um formulário com alteração
/// não salva pergunta se pode descartar em vez de ser substituído em silêncio por `go`.
Future<void> goBackOr(BuildContext context, String fallback) async {
  if (context.canPop()) {
    context.pop();
    return;
  }
  final handled = await Navigator.of(context).maybePop();
  if (!handled && context.mounted) context.go(fallback);
}

/// Botão de voltar de uma subtela. Sem pilha (link direto, recarga), leva a um destino útil.
class FallbackBackButton extends StatelessWidget {
  const FallbackBackButton({super.key, required this.fallback});

  final String fallback;

  @override
  Widget build(BuildContext context) =>
      BackButton(onPressed: () => unawaited(goBackOr(context, fallback)));
}
