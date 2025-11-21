/* // lib/models/message.dart
import 'user_profile.dart';

class Message {
  final int id;
  final int conversationId;
  final String senderId;
  final String content;
  final String contentType; // text, image
  final DateTime createdAt;
  final UserProfile? sender;
  final bool isRead; // 🔧 新增：是否已读

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.contentType,
    required this.createdAt,
    this.sender,
    this.isRead = false, // 默认未读
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as int,
      conversationId: json['conversation_id'] as int,
      senderId: json['sender_id'] as String,
      content: json['content'] as String,
      contentType: json['content_type'] as String? ?? 'text',
      createdAt: DateTime.parse(json['created_at'] as String),
      sender: json['sender'] is Map
          ? UserProfile.fromJson(json['sender'] as Map<String, dynamic>)
          : null,
      isRead: json['is_read'] as bool? ?? false, // 🔧 新增
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'content_type': contentType,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
    };
  }

  bool get isText => contentType == 'text';
  bool get isImage => contentType == 'image';
  
  // 🔧 新增：创建已读副本
  Message copyWith({
    int? id,
    int? conversationId,
    String? senderId,
    String? content,
    String? contentType,
    DateTime? createdAt,
    UserProfile? sender,
    bool? isRead,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      contentType: contentType ?? this.contentType,
      createdAt: createdAt ?? this.createdAt,
      sender: sender ?? this.sender,
      isRead: isRead ?? this.isRead,
    );
  }
} */

// lib/models/message.dart
import 'user_profile.dart';

class Message {
  final int id;
  final int conversationId;
  final String senderId;
  final String content;
  final String contentType; // text, image
  final DateTime createdAt;
  final UserProfile? sender;
  final bool isRead;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.contentType,
    required this.createdAt,
    this.sender,
    this.isRead = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    // ✅ 修复：处理嵌套的 sender 对象
    UserProfile? senderProfile;
    final senderData = json['sender'];
    
    if (senderData is Map) {
      // ✅ 关键修复：先转换为 Map<String, dynamic>
      senderProfile = UserProfile.fromJson(Map<String, dynamic>.from(senderData));
    }

    return Message(
      id: json['id'] as int,
      conversationId: json['conversation_id'] as int,
      senderId: json['sender_id'] as String,
      content: json['content'] as String,
      contentType: json['content_type'] as String? ?? 'text',
      createdAt: DateTime.parse(json['created_at'] as String),
      sender: senderProfile,
      isRead: json['is_read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'content_type': contentType,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
    };
  }

  bool get isText => contentType == 'text';
  bool get isImage => contentType == 'image';
  
  Message copyWith({
    int? id,
    int? conversationId,
    String? senderId,
    String? content,
    String? contentType,
    DateTime? createdAt,
    UserProfile? sender,
    bool? isRead,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      contentType: contentType ?? this.contentType,
      createdAt: createdAt ?? this.createdAt,
      sender: sender ?? this.sender,
      isRead: isRead ?? this.isRead,
    );
  }
}