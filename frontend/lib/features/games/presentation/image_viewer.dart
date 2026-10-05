import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/image_url.dart';

/// Galeria em tela cheia: abre na imagem tocada, com zoom e navegação por gesto,
/// botões e setas do teclado.
class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage({
    super.key,
    required this.urls,
    this.initialIndex = 0,
    this.title,
  });

  final List<String> urls;
  final int initialIndex;
  final String? title;

  static Future<void> open(
    BuildContext context, {
    required List<String> urls,
    required int initialIndex,
    String? title,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ImageViewerPage(
          urls: urls,
          initialIndex: initialIndex,
          title: title,
        ),
      ),
    );
  }

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final target = _index + delta;
    if (target < 0 || target >= widget.urls.length) return;
    _pages.animateToPage(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.urls.length;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _go(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _go(1),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text('${_index + 1} de $total'),
            leading: IconButton(
              tooltip: 'Fechar',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          body: Stack(
            children: [
              PageView.builder(
                controller: _pages,
                itemCount: total,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final url = ImageUrls.resolve(widget.urls[i])!;
                  return Semantics(
                    label: '${widget.title ?? 'Imagem'}, ${i + 1} de $total',
                    image: true,
                    child: InteractiveViewer(
                      maxScale: 5,
                      child: Center(
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                            size: 48,
                          ),
                          loadingBuilder: (context, child, progress) =>
                              progress == null
                              ? child
                              : const Center(
                                  child: CircularProgressIndicator(),
                                ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (_index > 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Imagem anterior',
                    color: Colors.white,
                    icon: const Icon(Icons.chevron_left, size: 36),
                    onPressed: () => _go(-1),
                  ),
                ),
              if (_index < total - 1)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Próxima imagem',
                    color: Colors.white,
                    icon: const Icon(Icons.chevron_right, size: 36),
                    onPressed: () => _go(1),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
