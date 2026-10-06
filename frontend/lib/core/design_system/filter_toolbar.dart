import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

/// Pesquisa, filtros, ordenação e modo de exibição em uma composição responsiva. Em largura
/// compacta a busca ocupa a primeira linha e os controles quebram abaixo; em largura ampla todos
/// os controles compartilham o mesmo [Wrap], sem rolagem horizontal.
///
/// A busca só aparece com [onQueryChanged]; sem ela, ordenação e modo de exibição seguem junto dos
/// filtros. [onClear] mostra "Limpar" e deve ser passado apenas quando há filtro ativo.
class FilterToolbar extends StatelessWidget {
  const FilterToolbar({
    super.key,
    this.query = '',
    this.onQueryChanged,
    this.searchHint = 'Buscar',
    this.filters = const [],
    this.sortBuilder,
    this.viewToggle,
    this.onClear,
    this.onSearchFocusChanged,
  });

  final String query;
  final ValueChanged<String>? onQueryChanged;
  final String searchHint;
  final List<Widget> filters;
  final Widget Function(bool compact)? sortBuilder;
  final Widget? viewToggle;
  final VoidCallback? onClear;
  final ValueChanged<bool>? onSearchFocusChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < Breakpoints.medium;
        final controls = <Widget>[
          ...filters,
          ?sortBuilder?.call(compact),
          ?viewToggle,
          if (onClear != null)
            TextButton(onPressed: onClear, child: const Text('Limpar')),
        ];
        final search = onQueryChanged == null
            ? null
            : _SearchField(
                query: query,
                hint: searchHint,
                onChanged: onQueryChanged!,
                onFocusChanged: onSearchFocusChanged,
              );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ?search,
              if (search != null && controls.isNotEmpty)
                const SizedBox(height: Space.sm),
              if (controls.isNotEmpty)
                Wrap(
                  spacing: Space.xs,
                  runSpacing: Space.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: controls,
                ),
            ],
          );
        }
        return Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (search != null)
              SizedBox(
                width: constraints.maxWidth.clamp(320, 360),
                child: search,
              ),
            ...controls,
          ],
        );
      },
    );
  }
}

/// Uma opção de [FilterMenuButton]; [value] `null` é "sem filtro".
typedef FilterOption<T> = ({T? value, String label});

/// Filtro como um botão discreto com menu: mostra [label] enquanto nada está filtrado e o nome da
/// opção escolhida (com destaque) quando há filtro. Substitui uma fileira de chips por um controle só.
class FilterMenuButton<T> extends StatelessWidget {
  const FilterMenuButton({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.tooltip,
  });

  /// Texto do botão sem filtro, por exemplo "Status".
  final String label;

  /// A primeira opção deve ser a que remove o filtro (`value: null`).
  final List<FilterOption<T>> options;
  final T? selected;
  final ValueChanged<T?> onSelected;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final index = options.indexWhere((o) => o.value == selected);
    final active = selected != null && index >= 0;
    final text = active ? options[index].label : label;
    final color = active ? scheme.onSecondaryContainer : scheme.onSurface;
    return PopupMenuButton<int>(
      tooltip: tooltip ?? 'Filtrar por ${label.toLowerCase()}',
      initialValue: index < 0 ? 0 : index,
      onSelected: (i) => onSelected(options[i].value),
      itemBuilder: (_) => [
        for (var i = 0; i < options.length; i++)
          CheckedPopupMenuItem(
            value: i,
            checked: i == (index < 0 ? 0 : index),
            child: Text(options[i].label),
          ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Center(
          widthFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: active ? scheme.secondaryContainer : null,
              borderRadius: BorderRadius.circular(Radii.control),
            ),
            child: Padding(
              padding: const EdgeInsets.only(
                left: Space.md,
                right: Space.xs,
                top: Space.sm,
                bottom: Space.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      text,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: color,
                        fontWeight: active ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, size: 20, color: color),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({
    required this.query,
    required this.hint,
    required this.onChanged,
    this.onFocusChanged,
  });

  final String query;
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool>? onFocusChanged;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final _controller = TextEditingController(text: widget.query);
  late final _focusNode = FocusNode()..addListener(_notifyFocus);

  void _notifyFocus() => widget.onFocusChanged?.call(_focusNode.hasFocus);

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
    _focusNode
      ..removeListener(_notifyFocus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
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
    this.compact = false,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: 'Ordenar por ${labelOf(selected)}',
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Center(
          widthFactor: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sort, size: 20),
                const SizedBox(width: Space.xs),
                Text(compact ? 'Ordenar' : 'Ordenar: ${labelOf(selected)}'),
              ],
            ),
          ),
        ),
      ),
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: true,
            tooltip: 'Mostrar como grade',
            icon: Icon(Icons.grid_view),
          ),
          ButtonSegment(
            value: false,
            tooltip: 'Mostrar como lista',
            icon: Icon(Icons.view_list),
          ),
        ],
        selected: {grid},
        onSelectionChanged: (selection) => onChanged(selection.single),
      ),
    );
  }
}
