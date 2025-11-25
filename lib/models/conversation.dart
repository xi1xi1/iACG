// lib/models/conversation.dart
import 'user_profile.dart';

class Conversation {
  final int id;
  final String type; // single
  final String userAId;
  final String userBId;
  final String initiatorId;
  final String status; // pending, active, blocked
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final UserProfile? userA;
  final UserProfile? userB;
  final String? lastMessageContent; // 新增字段：最后一条消息内容

  Conversation({
    required this.id,
    required this.type,
    required this.userAId,
    required this.userBId,
    required this.initiatorId,
    required this.status,
    this.lastMessageAt,
    required this.createdAt,
    this.userA,
    this.userB,
    this.lastMessageContent, // 新增
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    // ✅ 修复：正确处理 user_a 和 user_b 字段
    final userA = json['user_a'];
    final userB = json['user_b'];

    String userAId;
    String userBId;
    UserProfile? userAProfile;
    UserProfile? userBProfile;

    // 判断 user_a 是字符串ID还是用户对象
    if (userA is Map) {
      // ✅ 关键修复：先转换为 Map<String, dynamic>
      final userAMap = Map<String, dynamic>.from(userA);
      userAId = userAMap['id'] as String;
      userAProfile = UserProfile.fromJson(userAMap);
    } else {
      userAId = userA as String;
    }

    // 判断 user_b 是字符串ID还是用户对象
    if (userB is Map) {
      // ✅ 关键修复：先转换为 Map<String, dynamic>
      final userBMap = Map<String, dynamic>.from(userB);
      userBId = userBMap['id'] as String;
      userBProfile = UserProfile.fromJson(userBMap);
    } else {
      userBId = userB as String;
    }

    // 处理最后一条消息内容
    String? lastMessageContent;
    final lastMessage = json['last_message'];
    if (lastMessage is List && lastMessage.isNotEmpty) {
      lastMessageContent = lastMessage[0]['content'] as String?;
    } else if (lastMessage is Map) {
      lastMessageContent = lastMessage['content'] as String?;
    } else if (lastMessage is String) {
      lastMessageContent = lastMessage;
    }

    return Conversation(
      id: json['id'] as int,
      type: json['type'] as String,
      userAId: userAId,
      userBId: userBId,
      initiatorId: json['initiator_id'] as String,
      status: json['status'] as String,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      userA: userAProfile,
      userB: userBProfile,
      lastMessageContent: lastMessageContent, // 新增
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'user_a': userAId,
      'user_b': userBId,
      'initiator_id': initiatorId,
      'status': status,
      'last_message_at': lastMessageAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'user_a_profile': userA?.toJson(),
      'user_b_profile': userB?.toJson(),
      'last_message_content': lastMessageContent, // 新增
    };
  }

  /// 获取对方用户信息
  UserProfile? getOtherUser(String currentUserId) {
    if (userAId == currentUserId) return userB;
    if (userBId == currentUserId) return userA;
    return null;
  }

  bool get isPending => status == 'pending';
  bool get isActive => status == 'active';
  bool get isBlocked => status == 'blocked';

  /// 添加 copyWith 方法用于更新会话状态
  Conversation copyWith({
    int? id,
    String? type,
    String? userAId,
    String? userBId,
    String? initiatorId,
    String? status,
    DateTime? lastMessageAt,
    DateTime? createdAt,
    UserProfile? userA,
    UserProfile? userB,
    String? lastMessageContent, // 新增
  }) {
    return Conversation(
      id: id ?? this.id,
      type: type ?? this.type,
      userAId: userAId ?? this.userAId,
      userBId: userBId ?? this.userBId,
      initiatorId: initiatorId ?? this.initiatorId,
      status: status ?? this.status,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      createdAt: createdAt ?? this.createdAt,
      userA: userA ?? this.userA,
      userB: userB ?? this.userB,
      lastMessageContent: lastMessageContent ?? this.lastMessageContent, // 新增
    );
  }
}