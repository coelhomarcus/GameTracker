/// Usuário da sessão (`GET /auth/me`, login e cadastro).
class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.email,
    this.name,
    this.avatarUrl,
    this.bannerUrl,
    this.bio,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    username: json['username'] as String,
    email: json['email'] as String,
    name: json['name'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
    bannerUrl: json['bannerUrl'] as String?,
    bio: json['bio'] as String?,
  );

  final String id;
  final String username;
  final String email;
  final String? name;
  final String? avatarUrl;
  final String? bannerUrl;
  final String? bio;

  /// O nome é opcional; o username é o fallback (docs/MIGRACAO_FLUTTER.md, regra 11).
  String get displayName =>
      (name == null || name!.trim().isEmpty) ? username : name!;
}
