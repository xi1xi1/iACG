
/* 
// lib/models/notification.dart
class NotificationModel {
  final int id;
  final String userId;
  final String type; // like, comment, follow, message, system, event, new_post
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
      // 🔧 新增：关注的人发新帖
      case 'new_post':
        return '新帖子';
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
      // 🔧 新增：关注的人发新帖
      case 'new_post':
        return '📝';
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
} */

// lib/models/notification.dart
class NotificationModel {
  final int id;
  final String userId;
  final String type;
  final int? refId;
  final String? refUserId;  // ✅ 新增字段
  final String title;
  final String? content;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    this.refId,
    this.refUserId,  // ✅ 新增
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
      refUserId: json['ref_user_id'] as String?,  // ✅ 新增
      title: json['title'] as String,
      content: json['content'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
  

  /// 🔥 新增：判断是否为回关通知
  bool get isFollowBack {
    return type == 'follow' && title.contains('回关');
  }

  String get typeDisplay {
    switch (type) {
      case 'like':
        return '点赞';
      case 'comment':
        return '评论';
      case 'follow':
        // 🔥 修改：区分回关和普通关注
        return isFollowBack ? '回关' : '关注';
      case 'message':
        return '私信';
      case 'system':
        return '系统';
      case 'event':
        return '活动';
      case 'new_post':
        return '新帖子';
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
        // 🔥 修改：回关使用特殊图标
        return isFollowBack ? '🎉' : '👤';
      case 'message':
        return '✉️';
      case 'system':
        return '🔔';
      case 'event':
        return '🎉';
      case 'new_post':
        return '📝';
      default:
        return '📌';
    }
  }

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