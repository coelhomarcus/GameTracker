import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

/// Pesquisa, filtros, ordenação e modo de exibição. Tudo quebra em linhas conforme o espaço e o
/// tamanho do texto; nenhum controle depende de rolagem horizontal.
///
/// A busca só aparece com [onQueryChanged]. [filters] costuma ser uma lista de `FilterChip`;
/// [onClear] mostra "Limpar" e deve ser passado apenas quando há filtro ativo.
class FilterToolbar extends StatelessWidget {
  const FilterToolbar({
    super.key,
    this.query = '',
    this.onQueryChanged,
    this.searchHint = 'Buscar',
    this.filters = const [],
    this.sort,
    this.viewToggle,
    this.onClear,
  });

  final String query;
  final ValueChanged<String>? onQueryChanged;
  final String searchHint;
  final List<Widget> filters;
  final Widget? sort;
  final Widget? viewToggle;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final hasRow =
        filters.isNotEmpty ||
        sort != null ||
        viewToggle != null ||
        onClear != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onQueryChanged != null)
          _SearchField(
            query: query,
            hint: searchHint,
            onChanged: onQueryChanged!,
          ),
        if (onQueryChanged != null && hasRow) const SizedBox(height: Space.sm),
        if (hasRow)
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...filters,
              ?sort,
              ?viewToggle,
              if (onClear != null)
                TextButton(onPressed: onClear, child: const Text('Limpar')),
            ],
          ),
      ],
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({
    required this.query,
    required this.hint,
    required this.onChanged,
  });

  final String query;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final _controller = TextEditingController(text: widget.query);

  @override
  void didUpdateWidget(_SearchField old) {
    super.didUpdateWidget(old);
    // A consulta pode mudar de fora (limpar filtros); o campo acompanha.
    if (widget.query != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.query,
        selection: TextSelection.collapsed(offset: widget.query.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => _controller.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Limpar busca',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}

/// Menu de ordenação. O botão mostra o critério atual na dica de ferramenta.
class SortMenu<T> extends StatelessWidget {
  const SortMenu({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: 'Ordenar por ${labelOf(selected)}',
      icon: const Icon(Icons.sort),
      initialValue: selected,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final value in values)
          CheckedPopupMenuItem(
            value: value,
            checked: value == selected,
            child: Text(labelOf(value)),
          ),
      ],
    );
  }
}

/// Alterna entre grade e lista.
class ViewModeToggle extends StatelessWidget {
  const ViewModeToggle({
    super.key,
    required this.grid,
    required this.onChanged,
  });

  final bool grid;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: grid ? 'Mostrar como lista' : 'Mostrar como grade',
      icon: Icon(grid ? Icons.view_list : Icons.grid_view),
      onPressed: () => onChanged(!grid),
    );
  }
}
