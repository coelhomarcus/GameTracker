import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/models/user_summary.dart';
import '../../feed/application/post_store.dart';
import '../data/profile_models.dart';
import 'profile_providers.dart';

/// Salva alterações do próprio perfil e propaga a identidade nova para onde ela já está na tela.
/// Os textos e cada imagem são operações separadas no backend: o upload salva na hora.
class ProfileEditor {
  ProfileEditor(this._ref);
  final Ref _ref;

  Future<void> save(ProfileChanges changes) async {
    await _ref.read(profilesRepositoryProvider).updateProfile(changes);
    await _propagate();
  }

  Future<String> uploadImage(
    ProfileImageKind kind,
    PickedImage image, {
    void Function(double fraction)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final url = await _ref
        .read(profilesRepositoryProvider)
        .uploadImage(
          kind,
          image,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );
    await _propagate();
    return url;
  }

  /// Depois de salvar: a sessão, os posts já carregados e o perfil mostram os dados novos. Se a
  /// releitura da conta falhar, a alteração continua salva; só o dado em tela fica para depois.
  Future<void> _propagate() async {
    final user = await _ref
        .read(sessionControllerProvider.notifier)
        .refreshUser();
    if (user == null) return;
    _ref
        .read(postStoreProvider.notifier)
        .replaceAuthor(
          UserSummary(
            id: user.id,
            username: user.username,
            name: user.name,
            avatarUrl: user.avatarUrl,
          ),
        );
    _ref.invalidate(profileProvider(user.id));
  }
}

final profileEditorProvider = Provider<ProfileEditor>(ProfileEditor.new);
