/* class UserProfile {
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
 */

class UserProfile {
  final String id;
  final String nickname;
  final String? avatarUrl;
  final String? bio;
  final bool isCoser;
  final String? city;
  final List<String>? styleTags;
  final String role; // user, coser, creator_support, organizer
  final String cosLevel; // none, newbie, hobby, semi_pro, pro
  final DateTime createdAt;
  final DateTime? updatedAt;

  UserProfile({
    required this.id,
    required this.nickname,
    this.avatarUrl,
    this.bio,
    this.isCoser = false,
    this.city,
    this.styleTags,
    this.role = 'user',
    this.cosLevel = 'none',
    required this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      nickname: json['nickname'] as String,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      isCoser: json['is_coser'] as bool? ?? false,
      city: json['city'] as String?,
      styleTags: (json['style_tags'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      role: json['role'] as String? ?? 'user',
      cosLevel: json['cos_level'] as String? ?? 'none',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'avatar_url': avatarUrl,
      'bio': bio,
      'is_coser': isCoser,
      'city': city,
      'style_tags': styleTags,
      'role': role,
      'cos_level': cosLevel,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  String get displayRole {
    switch (role) {
      case 'coser':
        return 'Coser';
      case 'creator_support':
        return '创作支持';
      case 'organizer':
        return '活动组织者';
      default:
        return '用户';
    }
  }

  String get displayCosLevel {
    switch (cosLevel) {
      case 'newbie':
        return '新手';
      case 'hobby':
        return '爱好者';
      case 'semi_pro':
        return '半职业';
      case 'pro':
        return '职业';
      default:
        return '';
    }
  }
}