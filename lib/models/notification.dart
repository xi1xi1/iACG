/* 

// lib/models/notification.dart
class NotificationModel {
  final int id;
  final String userId;
  final String type;
  final int? refId;
  final String? refUserId;
  final String title;
  final String? content;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    this.refId,
    this.refUserId,
    required this.title,
    this.content,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    // 🔥 添加详细调试信息
    final createdAtStr = json['created_at'] as String;
    print('🕐 原始数据库时间字符串: $createdAtStr');
    
    DateTime parsedTime = DateTime.parse(createdAtStr);
    print('🕐 解析后的时间: $parsedTime');
    print('🕐 是否UTC: ${parsedTime.isUtc}');
    print('🕐 时区名称: ${parsedTime.timeZoneName}');
    
    // 如果解析出来的是 UTC 时间，转换为本地时间
    if (parsedTime.isUtc) {
      parsedTime = parsedTime.toLocal();
      print('🕐 转换为本地时间后: $parsedTime');
      print('🕐 转换后是否UTC: ${parsedTime.isUtc}');
    }
    
    // 🔥 额外验证：显示当前系统时间
    final now = DateTime.now();
    print('🕐 当前系统时间: $now');
    print('🕐 时间差(小时): ${now.difference(parsedTime).inHours}');
    
    return NotificationModel(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      refId: json['ref_id'] as int?,
      refUserId: json['ref_user_id'] as String?,
      title: json['title'] as String,
      content: json['content'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: parsedTime,
    );
  }

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
        return isFollowBack ? '回关' : '关注';
      case 'message':
        return '私信';
      case 'system':
        return '系统';
      case 'event':
        return '活动';
      case 'new_post':
        return '新帖子';
      case 'share':
        return '转发';
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
        return isFollowBack ? '🎉' : '👤';
      case 'message':
        return '✉️';
      case 'system':
        return '🔔';
      case 'event':
        return '🎉';
      case 'new_post':
        return '📝';
      case 'share':
        return '🔄';
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
      'ref_user_id': refUserId,
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
  final String? refUserId;
  final String title;
  final String? content;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    this.refId,
    this.refUserId,
    required this.title,
    this.content,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    // ✅ 修复：和 Post 模型一样，直接解析，不做任何转换
    final createdAtStr = json['created_at'] as String;
    final createdAt = DateTime.parse(createdAtStr);

    return NotificationModel(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      refId: json['ref_id'] as int?,
      refUserId: json['ref_user_id'] as String?,
      title: json['title'] as String,
      content: json['content'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: createdAt, // ✅ 直接使用，不转换
    );
  }

  /// 判断是否为回关通知
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
        return isFollowBack ? '回关' : '关注';
      case 'message':
        return '私信';
      case 'system':
        return '系统';
      case 'event':
        return '活动';
      case 'new_post':
        return '新帖子';
      case 'share':
        return '转发';
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
        return isFollowBack ? '🎉' : '👤';
      case 'message':
        return '✉️';
      case 'system':
        return '🔔';
      case 'event':
        return '🎉';
      case 'new_post':
        return '📝';
      case 'share':
        return '🔄';
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
      'ref_user_id': refUserId,
      'title': title,
      'content': content,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
