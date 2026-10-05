import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:gametracker/core/models/user_summary.dart';
import 'package:gametracker/features/games/data/game_models.dart';
import 'package:gametracker/features/library/data/game_entry.dart';
import 'package:gametracker/features/profiles/application/profile_image_picker.dart';
import 'package:gametracker/features/profiles/data/profile_models.dart';
import 'package:gametracker/features/profiles/data/profiles_repository.dart';
import 'package:gametracker/features/profiles/presentation/profile_image_crop_page.dart';

UserProfile fakeProfile({
  String id = 'u-beto',
  String username = 'beto',
  String? name = 'Beto',
  String? avatarUrl,
  String? bannerUrl,
  String? bio = 'Gosto de RPG',
  int followers = 3,
  int following = 1,
  int entries = 4,
  bool followed = false,
}) => UserProfile(
  id: id,
  username: username,
  name: name,
  avatarUrl: avatarUrl,
  bannerUrl: bannerUrl,
  bio: bio,
  createdAt: DateTime.utc(2026, 1, 1),
  followerCount: followers,
  followingCount: following,
  entryCount: entries,
  isFollowedByMe: followed,
);

PersonResult fakePerson({
  String id = 'u-beto',
  String username = 'beto',
  String? name,
  String? bio,
  bool followed = false,
}) => PersonResult(
  user: UserSummary(id: id, username: username, name: name),
  bio: bio,
  isFollowedByMe: followed,
);

class FakeProfilesRepository implements ProfilesRepository {
  final profiles = <String, UserProfile>{};
  final favoritesByUser = <String, List<Game>>{};
  final collectionByUser = <String, List<GameEntry>>{};
  List<PersonResult> searchResult = const [];

  final searches = <String>[];
  final followCalls = <(String, bool)>[];
  final updates = <ProfileChanges>[];
  final uploads = <(ProfileImageKind, PickedImage)>[];
  int profileCalls = 0;
  int collectionCalls = 0;

  Object? searchError;
  Object? profileError;
  Object? followError;
  Object? updateError;
  Object? uploadError;
  Object? collectionError;
  Completer<void>? followGate;
  Completer<void>? uploadGate;
  String avatarUrlResult = 'http://localhost:3100/uploads/avatars/new.jpg';
  String bannerUrlResult = 'http://localhost:3100/uploads/banners/new.jpg';

  @override
  Future<List<PersonResult>> search(
    String term, {
    CancelToken? cancelToken,
  }) async {
    searches.add(term);
    final error = searchError;
    if (error != null) throw error;
    return searchResult;
  }

  @override
  Future<UserProfile> profile(String userId) async {
    profileCalls++;
    final error = profileError;
    if (error != null) throw error;
    return profiles[userId] ??
        (throw StateError('perfil $userId não existe no fake'));
  }

  @override
  Future<List<Game>> favorites(String userId) async =>
      favoritesByUser[userId] ?? const [];

  @override
  Future<List<GameEntry>> collection(String userId) async {
    collectionCalls++;
    final error = collectionError;
    if (error != null) throw error;
    return collectionByUser[userId] ?? const [];
  }

  @override
  Future<void> setFollow(String userId, {required bool follow}) async {
    followCalls.add((userId, follow));
    await followGate?.future;
    final error = followError;
    if (error != null) throw error;
    // O servidor passa a devolver a relação nas consultas seguintes (perfil e busca).
    final profile = profiles[userId];
    if (profile != null && profile.isFollowedByMe != follow) {
      profiles[userId] = UserProfile(
        id: profile.id,
        username: profile.username,
        name: profile.name,
        avatarUrl: profile.avatarUrl,
        bannerUrl: profile.bannerUrl,
        bio: profile.bio,
        createdAt: profile.createdAt,
        followerCount: profile.followerCount + (follow ? 1 : -1),
        followingCount: profile.followingCount,
        entryCount: profile.entryCount,
        isFollowedByMe: follow,
      );
    }
    searchResult = [
      for (final r in searchResult)
        r.user.id == userId
            ? PersonResult(user: r.user, bio: r.bio, isFollowedByMe: follow)
            : r,
    ];
  }

  @override
  Future<void> updateProfile(ProfileChanges changes) async {
    final error = updateError;
    if (error != null) throw error;
    updates.add(changes);
  }

  @override
  Future<String> uploadImage(
    ProfileImageKind kind,
    PickedImage image, {
    void Function(double fraction)? onProgress,
    CancelToken? cancelToken,
  }) async {
    uploads.add((kind, image));
    onProgress?.call(0.5);
    await uploadGate?.future;
    final error = uploadError;
    if (error != null) throw error;
    onProgress?.call(1);
    return kind == ProfileImageKind.avatar ? avatarUrlResult : bannerUrlResult;
  }
}

/// Seletor de imagem controlável pelo teste.
/// Recortador que não abre o editor: devolve a imagem escolhida (ou [result], ou `null` se
/// [cancel]). Registra o que recebeu.
class FakeImageCropper implements ProfileImageCropper {
  PickedImage? result;
  bool cancel = false;
  final calls = <(PickedImage, ProfileImageKind)>[];

  @override
  Future<PickedImage?> crop(
    BuildContext context,
    PickedImage image,
    ProfileImageKind kind, {
    required String name,
    String? avatarUrl,
  }) async {
    calls.add((image, kind));
    if (cancel) return null;
    return result ?? image;
  }
}

class FakeImagePicker implements ProfileImagePicker {
  PickedImage? next;
  Object? error;
  int calls = 0;

  @override
  Future<PickedImage?> pick() async {
    calls++;
    final e = error;
    if (e != null) throw e;
    return next;
  }
}

/// PNG 1x1 válido, para a pré-visualização decodificar sem erro.
final _tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// Com [size], devolve bytes arbitrários desse tamanho (para o teste do limite de 8 MiB).
PickedImage fakeImage({
  int? size,
  String name = 'foto.png',
  String mime = 'image/png',
}) => PickedImage(
  bytes: size == null ? _tinyPng : List.filled(size, 7),
  fileName: name,
  mimeType: mime,
);
