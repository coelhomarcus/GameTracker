import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/profile_models.dart';

/// Falha ao escolher a imagem (permissão negada, arquivo ilegível), com mensagem para o usuário.
class ImagePickException implements Exception {
  const ImagePickException(this.message);
  final String message;
}

/// Escolhe uma imagem da galeria. Abstraído para os testes não dependerem do plugin.
abstract interface class ProfileImagePicker {
  /// `null` quando o usuário cancela.
  Future<PickedImage?> pick();
}

String mimeTypeForFileName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.heic')) return 'image/heic';
  if (lower.endsWith('.heif')) return 'image/heif';
  return 'image/jpeg';
}

class GalleryImagePicker implements ProfileImagePicker {
  GalleryImagePicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  @override
  Future<PickedImage?> pick() async {
    try {
      // Sem `imageQuality`: o editor de recorte limita o tamanho e é o único passo com perda.
      // O web nem sempre aplica esses parâmetros, por isso o processador valida de novo.
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      return PickedImage(
        bytes: bytes,
        fileName: file.name,
        mimeType: file.mimeType ?? mimeTypeForFileName(file.name),
      );
    } on PlatformException catch (e) {
      if (e.code == 'photo_access_denied' || e.code == 'camera_access_denied') {
        throw const ImagePickException(
          'Sem permissão para acessar as fotos. Libere o acesso nas configurações do aparelho.',
        );
      }
      throw const ImagePickException('Não foi possível abrir a galeria.');
    }
  }
}

final profileImagePickerProvider = Provider<ProfileImagePicker>(
  (ref) => GalleryImagePicker(),
);
