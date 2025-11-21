// lib/models/notification.dart
class NotificationModel {
  final int id;
  final String userId;
  final String type; // like, comment, follow, message, system, event
  final int? refId;
  final String title;
  final String? content;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    this.refId,
    required this.title,
    this.content,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      refId: json['ref_id'] as int?,
      title: json['title'] as String,
      content: json['content'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get typeDisplay {
    switch (type) {
      case 'like':
        return '点赞';
      case 'comment':
        return '评论';
      case 'follow':
        return '关注';
      case 'message':
        return '私信';
      case 'system':
        return '系统';
      case 'event':
        return '活动';
      default:
        return '通知';
    }
  }

  String get iconEmoji {
    switch (type) {
      case 'like':
        return '❤️';
      case 'comment':
        return '💬';
      case 'follow':
        return '👤';
      case 'message':
        return '✉️';
      case 'system':
        return '🔔';
      case 'event':
        return '🎉';
      default:
        return '📌';
    }
  }

  // 添加 toJson 方法用于调试
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'ref_id': refId,
      'title': title,
      'content': content,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }
}