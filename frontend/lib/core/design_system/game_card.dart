import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'game_cover.dart';
import 'game_status.dart';
import 'status_chip.dart';
import 'tokens.dart';

/// Geometria única para a grade real e seu skeleton.
@immutable
class GameGridGeometry {
  const GameGridGeometry({
    required this.columns,
    required this.cardWidth,
    required this.cardExtent,
    required this.titleExtent,
    required this.statusExtent,
    required this.captionExtent,
  });

  static const spacing = Space.md;

  final int columns;
  final double cardWidth;
  final double cardExtent;
  final double titleExtent;
  final double statusExtent;
  final double captionExtent;

  static int columnsFor(double availableWidth) {
    final minWidth = availableWidth < Breakpoints.medium ? 148.0 : 176.0;
    return ((availableWidth + spacing) / (minWidth + spacing)).floor().clamp(
      1,
      12,
    );
  }

  static GameGridGeometry resolve(BuildContext context, double availableWidth) {
    final columns = columnsFor(availableWidth);
    final cardWidth =
        (availableWidth - spacing * math.max(0, columns - 1)) / columns;
    final (titleExtent, statusExtent, captionExtent) = _textExtents(context);
    final cardExtent = cardExtentFor(context, cardWidth);
    return GameGridGeometry(
      columns: columns,
      cardWidth: cardWidth,
      cardExtent: cardExtent,
      titleExtent: titleExtent,
      statusExtent: statusExtent,
      captionExtent: captionExtent,
    );
  }

  /// Altura de um card quando sua largura já foi determinada pelo container.
  static double cardExtentFor(BuildContext context, double cardWidth) {
    final (titleExtent, statusExtent, captionExtent) = _textExtents(context);
    return cardWidth * 4 / 3 +
        Space.sm +
        titleExtent +
        Space.xs +
        statusExtent +
        Space.xs +
        captionExtent;
  }

  static (double, double, double) _textExtents(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final text = Theme.of(context).textTheme;
    final titleExtent = _lineExtent(text.titleMedium, scaler) * 2;
    final statusExtent = _lineExtent(text.labelSmall, scaler) + Space.xs * 2;
    final captionExtent = _lineExtent(text.bodyMedium, scaler);
    return (titleExtent, statusExtent, captionExtent);
  }

  static double _lineExtent(TextStyle? style, TextScaler scaler) {
    final fontSize = style?.fontSize ?? 14;
    return scaler.scale(fontSize) * (style?.height ?? 1);
  }
}

enum _GameCardVariant { cover, collection }

/// Card de jogo com contratos explícitos para capa isolada e coleção identificável.
///
/// Nada depende de hover: foco e toque recebem o mesmo destaque. Na variante
/// [GameCard.collection], `status: null` significa “Vários status”.
class GameCard extends StatefulWidget {
  const GameCard.cover({
    super.key,
    required this.title,
    this.coverUrl,
    this.onTap,
    this.semanticDescription,
    this.overlay,
    this.badge,
  }) : _variant = _GameCardVariant.cover,
       status = null,
       caption = null,
       trailing = null;

  const GameCard.collection({
    super.key,
    required this.title,
    required this.status,
    required this.caption,
    this.coverUrl,
    this.onTap,
    this.trailing,
  }) : _variant = _GameCardVariant.collection,
       semanticDescription = null,
       overlay = null,
       badge = null;

  final _GameCardVariant _variant;
  final String title;
  final String? coverUrl;
  final GameStatus? status;
  final String? caption;
  final VoidCallback? onTap;

  /// Complemento lido na variante de capa, usado enquanto Perfil e Explorar ainda não migraram.
  final String? semanticDescription;

  /// Controles e indicadores temporários das superfícies que ainda usam apenas a capa.
  final Widget? overlay;
  final Widget? badge;

  /// Ação separada no rodapé do card de coleção.
  final Widget? trailing;

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard> {
  bool _focused = false;

  String get _semanticLabel => [
    widget.title,
    if (widget._variant == _GameCardVariant.collection)
      widget.status?.label ?? 'Vários status',
    ?widget.caption,
    ?widget.semanticDescription,
  ].join(', ');

  @override
  Widget build(BuildContext context) => switch (widget._variant) {
    _GameCardVariant.cover => _coverCard(context),
    _GameCardVariant.collection => _collectionCard(context),
  };

  Widget _coverCard(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
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
              onFocusChange: _setFocused,
              child: GameCover(
                name: widget.title,
                url: widget.coverUrl,
                radius: Radii.cover,
              ),
            ),
          ),
          if (widget.badge != null)
            Positioned(
              left: Space.xs,
              bottom: Space.xs,
              child: IgnorePointer(
                child: ExcludeSemantics(child: widget.badge!),
              ),
            ),
          if (widget.overlay != null)
            Positioned(top: 0, right: 0, child: widget.overlay!),
        ],
      ),
    );
  }

  Widget _collectionCard(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final geometry = GameGridGeometry.resolve(
          context,
          constraints.maxWidth,
        );
        return AnimatedContainer(
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
              Positioned.fill(
                child: Semantics(
                  button: widget.onTap != null,
                  focusable: widget.onTap != null,
                  label: _semanticLabel,
                  onTap: widget.onTap,
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Radii.cover),
                    onTap: widget.onTap,
                    onFocusChange: _setFocused,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GameCover(
                          name: widget.title,
                          url: widget.coverUrl,
                          radius: Radii.cover,
                        ),
                        const SizedBox(height: Space.sm),
                        SizedBox(
                          height: geometry.titleExtent,
                          child: Text(
                            widget.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(height: Space.xs),
                        widget.status == null
                            ? const StatusChip.mixed()
                            : StatusChip(widget.status!),
                        const SizedBox(height: Space.xs),
                        Padding(
                          padding: EdgeInsets.only(
                            right: widget.trailing == null ? 0 : 48,
                          ),
                          child: Text(
                            widget.caption!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (widget.trailing != null)
                Positioned(right: 0, bottom: 0, child: widget.trailing!),
            ],
          ),
        );
      },
    );
  }

  void _setFocused(bool focused) {
    if (_focused != focused) setState(() => _focused = focused);
  }
}
