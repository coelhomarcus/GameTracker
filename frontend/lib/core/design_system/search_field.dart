import 'package:material_ui/material_ui.dart';

/// Apresentação compartilhada das buscas da plataforma.
///
/// O estado, debounce e consulta continuam pertencendo à feature. Este widget consolida
/// semântica, limpar, foco e ação do teclado sem esconder o [SearchBar] dos testes e da árvore.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
    this.onSubmitted,
    this.autofocus = false,
    this.clearTooltip = 'Limpar busca',
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final String clearTooltip;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: SearchBar(
        controller: controller,
        autoFocus: autofocus,
        hintText: hintText,
        leading: const Icon(Icons.search),
        textInputAction: TextInputAction.search,
        trailing: [
          if (controller.text.isNotEmpty)
            IconButton(
              tooltip: clearTooltip,
              icon: const Icon(Icons.close),
              onPressed: onClear,
            ),
        ],
        onChanged: onChanged,
        onSubmitted: onSubmitted,
      ),
    );
  }
}
