/// Usuário como aparece dentro de posts, comentários, jogadores e notificações.
class UserSummary {
  const UserSummary({
    required this.id,
    required this.username,
    this.name,
    this.avatarUrl,
  });

  factory UserSummary.fromJson(Map<String, dynamic> json) => UserSummary(
    id: json['id'] as String,
    username: json['username'] as String,
    name: json['name'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
  );

  final String id;
  final String username;
  final String? name;
  final String? avatarUrl;

  /// O nome é opcional; o username é o fallback. O username pode mudar: identifique por [id].
  String get displayName =>
      (name == null || name!.trim().isEmpty) ? username : name!;
}
