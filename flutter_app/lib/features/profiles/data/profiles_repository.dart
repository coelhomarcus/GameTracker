import 'package:dio/dio.dart';

import '../../../core/network/app_exception.dart';
import '../../games/data/game_models.dart';
import '../../library/data/game_entry.dart';
import 'profile_models.dart';

abstract interface class ProfilesRepository {
  Future<List<PersonResult>> search(String term, {CancelToken? cancelToken});
  Future<UserProfile> profile(String userId);
  Future<List<Game>> favorites(String userId);

  /// Coleção pública (somente leitura). O backend devolve também notas e demais campos.
  Future<List<GameEntry>> collection(String userId);
  Future<void> setFollow(String userId, {required bool follow});
  Future<void> updateProfile(ProfileChanges changes);

  /// Envia e devolve a nova URL. O backend salva a imagem na hora (não há "cancelar").
  Future<String> uploadImage(
    ProfileImageKind kind,
    PickedImage image, {
    void Function(double fraction)? onProgress,
    CancelToken? cancelToken,
  });
}

class RemoteProfilesRepository implements ProfilesRepository {
  RemoteProfilesRepository(this._dio);
  final Dio _dio;

  @override
  Future<List<PersonResult>> search(String term, {CancelToken? cancelToken}) =>
      guardApi(() async {
        final r = await _dio.get<List<dynamic>>(
          '/users/search',
          queryParameters: {'q': term},
          cancelToken: cancelToken,
        );
        return r.data!
            .cast<Map<String, dynamic>>()
            .map(PersonResult.fromJson)
            .toList();
      });

  @override
  Future<UserProfile> profile(String userId) => guardApi(() async {
    final r = await _dio.get<Map<String, dynamic>>('/users/$userId');
    return UserProfile.fromJson(r.data!);
  });

  @override
  Future<List<Game>> favorites(String userId) => guardApi(() async {
    final r = await _dio.get<List<dynamic>>('/users/$userId/favorites');
    return r.data!.cast<Map<String, dynamic>>().map(Game.fromJson).toList();
  });

  @override
  Future<List<GameEntry>> collection(String userId) => guardApi(() async {
    final r = await _dio.get<List<dynamic>>('/users/$userId/game-entries');
    return r.data!
        .cast<Map<String, dynamic>>()
        .map(GameEntry.fromJson)
        .toList();
  });

  /// Seguir e deixar de seguir são idempotentes no backend (204 nos dois casos).
  @override
  Future<void> setFollow(String userId, {required bool follow}) =>
      guardApi(() async {
        if (follow) {
          await _dio.post<void>('/users/$userId/follow');
        } else {
          await _dio.delete<void>('/users/$userId/follow');
        }
      });

  @override
  Future<void> updateProfile(ProfileChanges changes) async {
    if (changes.isEmpty) return;
    await guardApi(() => _dio.patch<void>('/users/me', data: changes.toJson()));
  }

  @override
  Future<String> uploadImage(
    ProfileImageKind kind,
    PickedImage image, {
    void Function(double fraction)? onProgress,
    CancelToken? cancelToken,
  }) => guardApi(() async {
    // Sem Content-Type manual: o Dio gera o boundary do multipart.
    final form = FormData.fromMap({
      kind.field: MultipartFile.fromBytes(
        image.bytes,
        filename: image.fileName,
        contentType: DioMediaType.parse(image.mimeType),
      ),
    });
    final r = await _dio.post<Map<String, dynamic>>(
      '/users/me/${kind.route}',
      data: form,
      cancelToken: cancelToken,
      onSendProgress: (sent, total) {
        if (total > 0) onProgress?.call(sent / total);
      },
    );
    return r.data![kind == ProfileImageKind.avatar ? 'avatarUrl' : 'bannerUrl']
        as String;
  });
}
