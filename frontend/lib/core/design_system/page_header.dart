import 'package:material_ui/material_ui.dart';

import 'page_container.dart';
import 'tokens.dart';

/// Cabeçalho alinhado à mesma coluna de conteúdo usada pelo corpo da página.
class PageHeader extends StatelessWidget implements PreferredSizeWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.width = PageWidth.reading,
    this.action,
    this.utilities = const [],
    this.bottom,
  });

  final String title;
  final PageWidth width;
  final Widget? action;
  final List<Widget> utilities;

  /// Abas ou controles abaixo do título, alinhados à mesma coluna de conteúdo.
  final PreferredSizeWidget? bottom;

  static const _titleHeight = 72.0;

  @override
  Size get preferredSize =>
      Size.fromHeight(_titleHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: _titleHeight,
      titleSpacing: 0,
      title: PageContainer(
        width: width,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            if (action != null) ...[const SizedBox(width: Space.md), action!],
            for (final utility in utilities) utility,
          ],
        ),
      ),
      bottom: bottom == null
          ? null
          : PreferredSize(
              preferredSize: bottom!.preferredSize,
              child: PageContainer(width: width, child: bottom!),
            ),
    );
  }
}
