import 'package:material_ui/material_ui.dart';

import 'game_cover.dart';
import 'game_status.dart';
import 'status_chip.dart';
import 'tokens.dart';

/// Capa 3:4 com título, status e legenda embaixo. Com [showDetails] falso mostra só a capa
/// (grade de biblioteca); o significado essencial vai no rótulo de acessibilidade.
///
/// Nada aqui depende de hover: foco e toque têm o mesmo destaque.
class GameCard extends StatefulWidget {
  const GameCard({
    super.key,
    required this.title,
    this.coverUrl,
    this.status,
    this.caption,
    this.onTap,
    this.overlay,
    this.showDetails = true,
  });

  final String title;
  final String? coverUrl;
  final GameStatus? status;

  /// Linha de apoio sob o status: plataforma, "2 registros" etc.
  final String? caption;
  final VoidCallback? onTap;

  /// Controle sobreposto ao canto da capa (menu de ações). Fica fora do alvo de toque da capa.
  final Widget? overlay;
  final bool showDetails;

  /// Colunas para [availableWidth], com cards de pelo menos [minWidth] e [spacing] entre eles.
  static int columnsFor(
    double availableWidth, {
    double minWidth = 132,
    double spacing = Space.md,
  }) {
    final columns = ((availableWidth + spacing) / (minWidth + spacing)).floor();
    return columns.clamp(1, 12);
  }

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard> {
  bool _focused = false;

  String get _semanticLabel =>
      [widget.title, ?widget.status?.label, ?widget.caption].join(', ');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cover = AnimatedContainer(
      duration: Motion.resolve(context, Motion.short),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.cover),
        border: Border.all(
          color: _focused ? theme.colorScheme.primary : Colors.transparent,
          width: 3,
        ),
      ),
      child: Stack(
        children: [
          Semantics(
            button: widget.onTap != null,
            focusable: widget.onTap != null,
            label: _semanticLabel,
            onTap: widget.onTap,
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.cover),
              onTap: widget.onTap,
              onFocusChange: (focused) => setState(() => _focused = focused),
              child: GameCover(
                name: widget.title,
                url: widget.coverUrl,
                radius: Radii.cover,
              ),
            ),
          ),
          if (widget.overlay != null)
            Positioned(top: 0, right: 0, child: widget.overlay!),
        ],
      ),
    );
    if (!widget.showDetails) return cover;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        cover,
        const SizedBox(height: Space.sm),
        Text(
          widget.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium,
        ),
        if (widget.status != null) ...[
          const SizedBox(height: Space.xs),
          StatusChip(widget.status!),
        ],
        if (widget.caption != null) ...[
          const SizedBox(height: Space.xs),
          Text(
            widget.caption!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
