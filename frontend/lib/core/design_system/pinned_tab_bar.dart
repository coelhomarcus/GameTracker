import 'package:material_ui/material_ui.dart';

/// Mantém um [TabBar] fixo abaixo da barra de título enquanto o conteúdo rola, em páginas de
/// rolagem única (`CustomScrollView`). Use dentro de `SliverPersistentHeader(pinned: true)`.
class PinnedTabBarDelegate extends SliverPersistentHeaderDelegate {
  const PinnedTabBarDelegate(this.tabBar, this.background);

  final TabBar tabBar;
  final Color background;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Material(
    color: background,
    elevation: overlapsContent ? 1 : 0,
    child: tabBar,
  );

  @override
  bool shouldRebuild(PinnedTabBarDelegate old) =>
      old.tabBar != tabBar || old.background != background;
}
