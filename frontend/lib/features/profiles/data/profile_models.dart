import '../../../core/models/user_summary.dart';

/// Perfil visível a outros usuários autenticados (`GET /users/:id`).
class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.createdAt,
    required this.followerCount,
    required this.followingCount,
    required this.entryCount,
    required this.isFollowedByMe,
    this.name,
    this.avatarUrl,
    this.bannerUrl,
    this.bio,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    username: json['username'] as String,
    name: json['name'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
    bannerUrl: json['bannerUrl'] as String?,
    bio: json['bio'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    followerCount: json['followerCount'] as int? ?? 0,
    followingCount: json['followingCount'] as int? ?? 0,
    // Conta playthroughs, não jogos: quem rejoga conta mais de uma vez.
    entryCount: json['gameEntryCount'] as int? ?? 0,
    isFollowedByMe: json['isFollowedByMe'] as bool? ?? false,
  );

  final String id;
  final String username;
  final String? name;
  final String? avatarUrl;
  final String? bannerUrl;
  final String? bio;
  final DateTime createdAt;
  final int followerCount;
  final int followingCount;
  final int entryCount;
  final bool isFollowedByMe;

  /// O nome é opcional; o username é o fallback. O username pode mudar: identifique por [id].
  String get displayName =>
      (name == null || name!.trim().isEmpty) ? username : name!;

  /// A bio vazia (`''`) é como o servidor guarda "sem bio".
  String? get bioOrNull => (bio == null || bio!.trim().isEmpty) ? null : bio;

  UserSummary toSummary() =>
      UserSummary(id: id, username: username, name: name, avatarUrl: avatarUrl);
}

/// Resultado de `GET /users/search`.
class PersonResult {
  const PersonResult({
    required this.user,
    required this.isFollowedByMe,
    this.bio,
  });

  factory PersonResult.fromJson(Map<String, dynamic> json) => PersonResult(
    user: UserSummary.fromJson(json),
    bio: json['bio'] as String?,
    isFollowedByMe: json['isFollowedByMe'] as bool? ?? false,
  );

  final UserSummary user;
  final String? bio;
  final bool isFollowedByMe;

  String? get bioOrNull => (bio == null || bio!.trim().isEmpty) ? null : bio;
}

/// Alterações do perfil. Campos `null` não são enviados.
class ProfileChanges {
  const ProfileChanges({this.username, this.name, this.bio});

  final String? username;
  final String? name;

  /// `''` limpa a bio.
  final String? bio;

  bool get isEmpty => username == null && name == null && bio == null;

  Map<String, Object?> toJson() => {
    'username': ?username,
    'name': ?name,
    'bio': ?bio,
  };
}

/// Imagem escolhida pelo usuário, ainda não enviada.
class PickedImage {
  const PickedImage({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final List<int> bytes;
  final String fileName;
  final String mimeType;

  /// Teto do upload no backend (8 MiB).
  static const maxBytes = 8 * 1024 * 1024;

  bool get isTooLarge => bytes.length > maxBytes;
}

enum ProfileImageKind {
  avatar('avatar', 'avatar'),
  banner('banner', 'banner');

  const ProfileImageKind(this.field, this.route);

  /// Nome do campo multipart e do final da rota (`/users/me/<route>`).
  final String field;
  final String route;
}
