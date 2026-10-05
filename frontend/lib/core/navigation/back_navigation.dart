import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Volta para a tela anterior; se a página foi aberta por link, sem pilha, vai para [fallback].
///
/// Passa sempre por `maybePop`, que consulta o `PopScope` da página: um formulário com alteração
/// não salva pergunta se pode descartar. `context.pop()` direto ignora o `PopScope`, e `go`
/// substituiria a página em silêncio.
Future<void> goBackOr(BuildContext context, String fallback) async {
  final handled = await Navigator.of(context).maybePop();
  if (handled || !context.mounted) return;
  // Primeira rota da pilha (link direto, recarga): vai para um destino útil.
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

/// Botão de voltar de uma subtela. Sem pilha (link direto, recarga), leva a um destino útil.
class FallbackBackButton extends StatelessWidget {
  const FallbackBackButton({super.key, required this.fallback});

  final String fallback;

  @override
  Widget build(BuildContext context) =>
      BackButton(onPressed: () => unawaited(goBackOr(context, fallback)));
}
