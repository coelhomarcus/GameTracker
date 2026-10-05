import 'dart:async';
import 'dart:ui' as ui;

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/design_system/tokens.dart';
import '../../../core/design_system/user_avatar.dart';
import '../application/profile_image_processor.dart';
import '../data/profile_models.dart';

/// Chave da prévia (os testes comparam o que ela desenha com o arquivo exportado).
const cropPreviewKey = Key('crop-preview');

/// Abre o editor de recorte e devolve a imagem final (JPEG já nas dimensões exatas), ou `null`
/// se o usuário cancelou. Abstraído para os testes da edição de perfil não abrirem o editor real.
abstract interface class ProfileImageCropper {
  Future<PickedImage?> crop(
    BuildContext context,
    PickedImage image,
    ProfileImageKind kind, {
    required String name,
    String? avatarUrl,
  });
}

/// Tela cheia em janela estreita; diálogo de até 720 dp a partir de 600 dp.
class RouteProfileImageCropper implements ProfileImageCropper {
  const RouteProfileImageCropper();

  @override
  Future<PickedImage?> crop(
    BuildContext context,
    PickedImage image,
    ProfileImageKind kind, {
    required String name,
    String? avatarUrl,
  }) {
    final page = ProfileImageCropPage(
      image: image,
      kind: kind,
      name: name,
      avatarUrl: avatarUrl,
    );
    if (MediaQuery.sizeOf(context).width < Breakpoints.medium) {
      return Navigator.of(context).push<PickedImage>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => Scaffold(body: SafeArea(child: page)),
        ),
      );
    }
    final size = MediaQuery.sizeOf(context);
    return showDialog<PickedImage>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: size.width < 760 ? size.width - 40 : 720,
          height: (size.height * 0.9).clamp(420.0, 760.0),
          child: page,
        ),
      ),
    );
  }
}

final profileImageCropperProvider = Provider<ProfileImageCropper>(
  (ref) => const RouteProfileImageCropper(),
);

/// Fluxo: preparar a imagem → recortar → salvar. Não envia nada: devolve o arquivo final e quem
/// abriu decide o envio (o upload tem progresso e nova tentativa na tela de edição).
class ProfileImageCropPage extends ConsumerStatefulWidget {
  const ProfileImageCropPage({
    super.key,
    required this.image,
    required this.kind,
    required this.name,
    this.avatarUrl,
  });

  final PickedImage image;
  final ProfileImageKind kind;

  /// Identidade mostrada na prévia da capa (onde o avatar vai sobreposto).
  final String name;
  final String? avatarUrl;

  @override
  ConsumerState<ProfileImageCropPage> createState() =>
      _ProfileImageCropPageState();
}

class _ProfileImageCropPageState extends ConsumerState<ProfileImageCropPage> {
  final _controller = CropController();

  PreparedImage? _prepared;
  ui.Image? _decoded;
  String? _prepareError;
  String? _exportError;
  bool _exporting = false;

  /// Muda a cada "Restaurar": remontar o editor garante o mesmo enquadramento do primeiro uso.
  int _generation = 0;

  /// Moldura de recorte e imagem, em coordenadas da área de edição.
  Rect? _cropRect;
  Rect? _imageRect;

  /// Região recortada, em pixels da imagem preparada (alimenta a prévia e o aviso de resolução).
  Rect? _area;

  bool get _avatar => widget.kind == ProfileImageKind.avatar;
  String get _title => _avatar ? 'Ajustar foto' : 'Ajustar capa';
  String get _saveLabel => _avatar ? 'Salvar foto' : 'Salvar capa';

  /// Passo dos botões: 10% da moldura.
  static const _step = 0.1;

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  @override
  void dispose() {
    _decoded?.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    try {
      final prepared = await ref
          .read(profileImageProcessorProvider)
          .prepare(widget.image);
      final decoded = await _decode(prepared.bytes);
      if (!mounted) {
        decoded?.dispose();
        return;
      }
      setState(() {
        _prepared = prepared;
        _decoded = decoded;
      });
    } on ImageProcessingException catch (e) {
      if (mounted) setState(() => _prepareError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _prepareError = ProfileImageLimits.unsupportedMessage);
      }
    }
  }

  /// A prévia desenha direto da imagem preparada; se não decodificar, só ela some.
  Future<ui.Image?> _decode(Uint8List bytes) async {
    try {
      return await decodeImageFromList(bytes);
    } catch (_) {
      return null;
    }
  }

  void _updateArea() {
    final prepared = _prepared;
    final crop = _cropRect;
    final image = _imageRect;
    if (prepared == null || crop == null || image == null || image.isEmpty) {
      return;
    }
    final scale = prepared.width / image.width;
    setState(
      () => _area = Rect.fromLTWH(
        (crop.left - image.left) * scale,
        (crop.top - image.top) * scale,
        crop.width * scale,
        crop.height * scale,
      ),
    );
  }

  void _moveBy(double dx, double dy) {
    final crop = _cropRect;
    if (crop == null || _exporting) return;
    _controller.cropRect = crop.shift(
      Offset(dx * crop.width * _step, dy * crop.height * _step),
    );
  }

  /// Amplia ou reduz a moldura em torno do centro, mantendo a proporção. O controller corrige o
  /// retângulo para ficar dentro da imagem.
  void _resizeBy(double factor) {
    final crop = _cropRect;
    if (crop == null || _exporting) return;
    _controller.cropRect = Rect.fromCenter(
      center: crop.center,
      width: crop.width * factor,
      height: crop.height * factor,
    );
  }

  void _reset() {
    if (_prepared == null || _exporting) return;
    setState(() {
      _generation++;
      _exportError = null;
      _cropRect = null;
      _imageRect = null;
      _area = null;
    });
  }

  void _save() {
    if (_prepared == null || _exporting) return;
    setState(() {
      _exporting = true;
      _exportError = null;
    });
    _controller.crop();
  }

  Future<void> _onCropped(CropResult result) async {
    switch (result) {
      case CropSuccess(:final croppedImage):
        try {
          final file = await ref
              .read(profileImageProcessorProvider)
              .export(croppedImage, widget.kind);
          if (mounted) Navigator.of(context).pop(file);
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _exporting = false;
            _exportError = e is ImageProcessingException
                ? e.message
                : 'Não foi possível preparar a imagem. Tente de novo.';
          });
        }
      case CropFailure():
        if (mounted) {
          setState(() {
            _exporting = false;
            _exportError = 'Não foi possível recortar a imagem. Tente de novo.';
          });
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _moveBy(-1, 0),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _moveBy(1, 0),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _moveBy(0, -1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _moveBy(0, 1),
        const SingleActivator(LogicalKeyboardKey.equal): () => _resizeBy(0.9),
        const SingleActivator(LogicalKeyboardKey.minus): () => _resizeBy(1.1),
      },
      child: Focus(
        autofocus: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.sm,
                Space.sm,
                Space.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(_title, style: text.titleLarge),
                    ),
                  ),
                  TextButton(
                    onPressed: _exporting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ),
            Expanded(flex: 3, child: _editor()),
            if (_prepareError == null) ...[
              Flexible(flex: 2, fit: FlexFit.loose, child: _panel()),
              _actions(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _editor() {
    final scheme = Theme.of(context).colorScheme;
    final error = _prepareError;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40, color: scheme.error),
              const SizedBox(height: Space.md),
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: Space.lg),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fechar'),
              ),
            ],
          ),
        ),
      );
    }
    final prepared = _prepared;
    if (prepared == null) {
      return Center(
        child: Semantics(
          label: 'Preparando a imagem',
          child: const CircularProgressIndicator(),
        ),
      );
    }
    return Semantics(
      label:
          'Área de recorte. Arraste e use a pinça ou a roda do mouse para enquadrar, '
          'ou use os botões abaixo.',
      child: Crop(
        key: ValueKey(_generation),
        image: prepared.bytes,
        controller: _controller,
        onCropped: _onCropped,
        aspectRatio: widget.kind.aspectRatio,
        withCircleUi: _avatar,
        // A imagem se move sob uma moldura fixa; os botões ajustam a moldura pelo controller.
        interactive: true,
        fixCropRect: true,
        initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
          size: 0.9,
          aspectRatio: widget.kind.aspectRatio,
        ),
        baseColor: scheme.surfaceContainerHighest,
        maskColor: Colors.black54,
        progressIndicator: const CircularProgressIndicator(),
        onMoved: (viewportRect, imageBasedRect) {
          _cropRect = viewportRect;
          if (mounted) setState(() => _area = imageBasedRect);
        },
        onImageMoved: (viewportImageRect) {
          _imageRect = viewportImageRect;
          _updateArea();
        },
      ),
    );
  }

  Widget _panel() {
    final prepared = _prepared;
    final area = _area;
    final lowResolution =
        area != null && area.width < widget.kind.outputWidth - 0.5;
    final isGif =
        widget.image.mimeType == 'image/gif' ||
        prepared?.animatedSource == true;
    final scheme = Theme.of(context).colorScheme;
    final enabled = prepared != null && !_exporting;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (prepared != null) _preview(area),
          const SizedBox(height: Space.md),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              for (final (tooltip, icon, dx, dy) in [
                ('Mover área para a esquerda', Icons.arrow_back, -1.0, 0.0),
                ('Mover área para a direita', Icons.arrow_forward, 1.0, 0.0),
                ('Mover área para cima', Icons.arrow_upward, 0.0, -1.0),
                ('Mover área para baixo', Icons.arrow_downward, 0.0, 1.0),
              ])
                IconButton(
                  tooltip: tooltip,
                  icon: Icon(icon),
                  onPressed: enabled ? () => _moveBy(dx, dy) : null,
                ),
              IconButton(
                tooltip: 'Aumentar área',
                icon: const Icon(Icons.zoom_out),
                onPressed: enabled ? () => _resizeBy(1.1) : null,
              ),
              IconButton(
                tooltip: 'Diminuir área',
                icon: const Icon(Icons.zoom_in),
                onPressed: enabled ? () => _resizeBy(0.9) : null,
              ),
            ],
          ),
          if (isGif)
            _note(
              Icons.info_outline,
              'Este arquivo é um GIF. A foto será estática, com o primeiro quadro.',
            ),
          if (lowResolution)
            _note(
              Icons.info_outline,
              'Imagem pequena: a foto pode ficar com pouca nitidez.',
            ),
          if (_exportError != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.sm),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _exportError!,
                  style: TextStyle(color: scheme.error),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Fica fora da área rolável: salvar nunca some abaixo da dobra, nem com texto ampliado.
  Widget _actions() {
    final enabled = _prepared != null && !_exporting;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.md),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: Space.sm,
        runSpacing: Space.sm,
        children: [
          TextButton(
            onPressed: enabled ? _reset : null,
            child: const Text('Restaurar'),
          ),
          FilledButton(
            onPressed: enabled ? _save : null,
            child: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_saveLabel),
          ),
        ],
      ),
    );
  }

  Widget _note(IconData icon, String message) => Padding(
    padding: const EdgeInsets.only(top: Space.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Space.sm,
      children: [
        Icon(icon, size: 18),
        Expanded(child: Text(message)),
      ],
    ),
  );

  /// Prévia do que será salvo, desenhada a partir do mesmo enquadramento. A máscara circular e o
  /// avatar sobreposto existem só aqui; o arquivo exportado é o retângulo puro.
  Widget _preview(Rect? area) {
    final image = _decoded;
    if (_avatar) {
      return Center(
        child: Semantics(
          label: 'Prévia da foto',
          image: true,
          child: SizedBox(
            width: 88,
            height: 88,
            child: RepaintBoundary(
              key: cropPreviewKey,
              child: CustomPaint(
                painter: _PreviewPainter(image, area, circle: true),
              ),
            ),
          ),
        ),
      );
    }
    // O perfil mostra o avatar de 88 dp sobre a borda inferior esquerda de uma capa de ~390 dp.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final avatarSize = width * 0.226;
            return Semantics(
              label:
                  'Prévia da capa, com a posição aproximada da foto de perfil',
              image: true,
              child: Padding(
                padding: EdgeInsets.only(bottom: avatarSize / 2),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.cover),
                      child: AspectRatio(
                        aspectRatio: 3,
                        child: RepaintBoundary(
                          key: cropPreviewKey,
                          child: CustomPaint(
                            painter: _PreviewPainter(
                              image,
                              area,
                              circle: false,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: width * 0.04,
                      bottom: -avatarSize / 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 3,
                          ),
                        ),
                        child: UserAvatar(
                          name: widget.name,
                          url: widget.avatarUrl,
                          radius: avatarSize / 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  const _PreviewPainter(this.image, this.area, {required this.circle});

  final ui.Image? image;
  final Rect? area;
  final bool circle;

  @override
  void paint(Canvas canvas, Size size) {
    final dst = Offset.zero & size;
    final bounds = Paint()..color = const Color(0x22808080);
    if (circle) {
      canvas.drawOval(dst, bounds);
      canvas.clipPath(Path()..addOval(dst));
    } else {
      canvas.drawRect(dst, bounds);
    }
    final image = this.image;
    final area = this.area;
    if (image == null || area == null || area.isEmpty) return;
    final whole = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final src = area.intersect(whole);
    if (src.isEmpty) return;
    // Parte da moldura que cai fora da imagem fica vazia, como no arquivo exportado (fundo branco).
    final scaleX = size.width / area.width;
    final scaleY = size.height / area.height;
    final target = Rect.fromLTWH(
      (src.left - area.left) * scaleX,
      (src.top - area.top) * scaleY,
      src.width * scaleX,
      src.height * scaleY,
    );
    canvas.drawImageRect(
      image,
      src,
      target,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_PreviewPainter old) =>
      old.image != image || old.area != area || old.circle != circle;
}
