class UserProfile {
  final String id;
  final String nickname;
  final String? avatarUrl;
  final String? bio;
  final bool isCoser;
  final String? city;
  final List<String>? styleTags;
  final String role;
  final String cosLevel;
  final DateTime createdAt;
  final DateTime? updatedAt;

  UserProfile({
    required this.id,
    required this.nickname,
    this.avatarUrl,
    this.bio,
    required this.isCoser,
    this.city,
    this.styleTags,
    required this.role,
    required this.cosLevel,
    required this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      nickname: json['nickname'],
      avatarUrl: json['avatar_url'],
      bio: json['bio'],
      isCoser: json['is_coser'] ?? false,
      city: json['city'],
      styleTags: json['style_tags'] != null
          ? List<String>.from(json['style_tags'])
          : null,
      role: json['role'] ?? 'user',
      cosLevel: json['cos_level'] ?? 'none',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
}
