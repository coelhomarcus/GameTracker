import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../data/profile_models.dart';

/// Falha ao preparar ou exportar a imagem, com mensagem para o usuário.
class ImageProcessingException implements Exception {
  const ImageProcessingException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Tamanho e proporção da imagem exportada para cada tipo de foto.
extension ProfileImageSpec on ProfileImageKind {
  int get outputWidth => this == ProfileImageKind.avatar ? 400 : 1500;
  int get outputHeight => this == ProfileImageKind.avatar ? 400 : 500;
  double get aspectRatio => outputWidth / outputHeight;
  String get exportFileName =>
      this == ProfileImageKind.avatar ? 'avatar.jpg' : 'banner.jpg';
}

/// Imagem normalizada para o editor: orientação aplicada, no máximo 2048 px no maior lado.
class PreparedImage {
  const PreparedImage({
    required this.bytes,
    required this.width,
    required this.height,
    required this.animatedSource,
  });

  /// PNG sem perdas: o recorte e a codificação final em JPEG são a única perda da imagem.
  final Uint8List bytes;
  final int width;
  final int height;

  /// A origem tinha vários quadros (GIF/WebP animado); só o primeiro foi usado.
  final bool animatedSource;
}

abstract final class ProfileImageLimits {
  static const maxInputBytes = PickedImage.maxBytes;
  static const maxPixels = 24 * 1000 * 1000;
  static const maxPreparedSide = 2048;
  static const jpegQuality = 85;

  static const unsupportedMessage = 'Use uma imagem JPG, PNG ou WebP.';
}

/// Prepara e exporta a foto. Abstraído para os testes de tela não decodificarem imagens de verdade.
abstract interface class ProfileImageProcessor {
  Future<PreparedImage> prepare(PickedImage image);

  /// [cropped] são os bytes do recorte feito no editor. Devolve JPEG com as dimensões exatas de [kind].
  Future<PickedImage> export(Uint8List cropped, ProfileImageKind kind);
}

/// Usa `compute` para tirar a decodificação do isolate da interface (no web roda inline).
class ImagePackageProcessor implements ProfileImageProcessor {
  const ImagePackageProcessor();

  @override
  Future<PreparedImage> prepare(PickedImage image) =>
      compute(prepareProfileImageSync, Uint8List.fromList(image.bytes));

  @override
  Future<PickedImage> export(Uint8List cropped, ProfileImageKind kind) async {
    final bytes = await compute(
      _export,
      _ExportRequest(cropped, kind.outputWidth, kind.outputHeight),
    );
    return PickedImage(
      bytes: bytes,
      fileName: kind.exportFileName,
      mimeType: 'image/jpeg',
    );
  }
}

final profileImageProcessorProvider = Provider<ProfileImageProcessor>(
  (ref) => const ImagePackageProcessor(),
);

const _supportedFormats = {
  img.ImageFormat.jpg,
  img.ImageFormat.png,
  img.ImageFormat.webp,
  img.ImageFormat.gif,
};

/// Valida (tamanho do arquivo e número de pixels, antes de decodificar tudo), aplica a orientação
/// EXIF e limita o maior lado a 2048 px. GIF e WebP animados usam o primeiro quadro.
PreparedImage prepareProfileImageSync(Uint8List bytes) {
  if (bytes.length > ProfileImageLimits.maxInputBytes) {
    throw const ImageProcessingException(
      'A imagem passa de 8 MB. Escolha uma menor.',
    );
  }
  final img.Decoder? decoder;
  final img.DecodeInfo? info;
  final img.Image? decoded;
  try {
    decoder = img.findDecoderForData(bytes);
    if (decoder == null || !_supportedFormats.contains(decoder.format)) {
      throw const ImageProcessingException(
        ProfileImageLimits.unsupportedMessage,
      );
    }
    info = decoder.startDecode(bytes);
    if (info == null || info.width <= 0 || info.height <= 0) {
      throw const ImageProcessingException(
        ProfileImageLimits.unsupportedMessage,
      );
    }
    // O teto vem do cabeçalho: uma foto de centenas de megapixels não chega a ser decodificada.
    if (info.width * info.height > ProfileImageLimits.maxPixels) {
      throw const ImageProcessingException(
        'A imagem tem resolução alta demais (máximo de 24 milhões de pixels). '
        'Reduza o tamanho e tente de novo.',
      );
    }
    decoded = decoder.decodeFrame(0);
  } on ImageProcessingException {
    rethrow;
  } catch (_) {
    // O pacote lança RangeError/FormatException em arquivo truncado ou corrompido.
    throw const ImageProcessingException(ProfileImageLimits.unsupportedMessage);
  }
  if (decoded == null) {
    throw const ImageProcessingException(ProfileImageLimits.unsupportedMessage);
  }

  var image = img.bakeOrientation(decoded);
  final longest = image.width > image.height ? image.width : image.height;
  if (longest > ProfileImageLimits.maxPreparedSide) {
    final landscape = image.width >= image.height;
    image = img.copyResize(
      image,
      width: landscape ? ProfileImageLimits.maxPreparedSide : null,
      height: landscape ? null : ProfileImageLimits.maxPreparedSide,
      interpolation: img.Interpolation.average,
    );
  }
  return PreparedImage(
    bytes: img.encodePng(image, level: 1),
    width: image.width,
    height: image.height,
    animatedSource: info.numFrames > 1,
  );
}

class _ExportRequest {
  const _ExportRequest(this.bytes, this.width, this.height);
  final Uint8List bytes;
  final int width;
  final int height;
}

Uint8List _export(_ExportRequest request) =>
    exportProfileImageSync(request.bytes, request.width, request.height);

/// Redimensiona o recorte para exatamente [width]×[height] (ampliando se for menor), compõe sobre
/// fundo branco se houver transparência e codifica em JPEG sem metadados.
Uint8List exportProfileImageSync(Uint8List cropped, int width, int height) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(cropped);
  } catch (_) {
    throw const ImageProcessingException('Não foi possível preparar a imagem.');
  }
  if (decoded == null) {
    throw const ImageProcessingException('Não foi possível preparar a imagem.');
  }
  final shrinking = decoded.width > width || decoded.height > height;
  final resized = (decoded.width == width && decoded.height == height)
      ? decoded
      : img.copyResize(
          decoded,
          width: width,
          height: height,
          maintainAspect: false,
          interpolation: shrinking
              ? img.Interpolation.average
              : img.Interpolation.cubic,
        );

  // Imagem nova: não herda EXIF nem outros metadados da origem.
  final flat = img.Image(width: width, height: height, numChannels: 3);
  img.fill(flat, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(flat, resized);

  final jpeg = img.encodeJpg(flat, quality: ProfileImageLimits.jpegQuality);
  if (jpeg.length > ProfileImageLimits.maxInputBytes) {
    throw const ImageProcessingException(
      'A imagem ficou grande demais. Tente outra.',
    );
  }
  return jpeg;
}
