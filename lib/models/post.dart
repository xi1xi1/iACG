/* class Post {
  final String id;
  final String title;
  final String? content;
  final String channel;
  final String authorId;
  final Map<String, dynamic>? author;
  final List<dynamic>? postMedia;
  final List<dynamic>? tags;
  final int likeCount;
  final int favoriteCount;
  final int commentCount;
  final DateTime createdAt;

  Post({
    required this.id,
    required this.title,
    this.content,
    required this.channel,
    required this.authorId,
    this.author,
    this.postMedia,
    this.tags,
    required this.likeCount,
    required this.favoriteCount,
    required this.commentCount,
    required this.createdAt,
  });

  factory Post.fromJson(Map/*  */<String, dynamic> json) {
    return Post(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      content: json['content'],
      channel: json['channel'],
      authorId: json['author_id'],
      author: json['author'],
      postMedia: json['post_media'],
      tags: json['tags'],
      likeCount: json['like_count'] ?? 0,
      favoriteCount: json['favorite_count'] ?? 0,
      commentCount: json['comment_count'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
//  */

// class Post {
//   final String id;
//   final String title;
//   final String? content;
//   final String channel;
//   final String authorId;
//   final Map<String, dynamic>? author;
//   final List<Map<String, dynamic>>? postMedia;  // ✅ 明确类型
//   final List<Map<String, dynamic>>? tags;       // ✅ 明确类型
//   final int likeCount;
//   final int favoriteCount;
//   final int commentCount;
//   final DateTime createdAt;

//   Post({
//     required this.id,
//     required this.title,
//     this.content,
//     required this.channel,
//     required this.authorId,
//     this.author,
//     this.postMedia,
//     this.tags,
//     required this.likeCount,
//     required this.favoriteCount,
//     required this.commentCount,
//     required this.createdAt,
//   });

//   factory Post.fromJson(Map<String, dynamic> json) {
//     // ✅ 修复：安全处理 author 对象
//     Map<String, dynamic>? authorMap;
//     final authorData = json['author'];
//     if (authorData is Map) {
//       authorMap = Map<String, dynamic>.from(authorData);
//     }

//     // ✅ 修复：安全处理 post_media 列表
//     List<Map<String, dynamic>>? mediaList;
//     final mediaData = json['post_media'];
//     if (mediaData is List) {
//       mediaList = mediaData
//           .map((item) => Map<String, dynamic>.from(item as Map))
//           .toList();
//     }

//     // ✅ 修复：安全处理 tags 列表
//     List<Map<String, dynamic>>? tagsList;
//     final tagsData = json['tags'];
//     if (tagsData is List) {
//       tagsList = tagsData
//           .map((item) => Map<String, dynamic>.from(item as Map))
//           .toList();
//     }

//     return Post(
//       id: json['id'].toString(),
//       title: json['title'] as String? ?? '',
//       content: json['content'] as String?,
//       channel: json['channel'] as String,
//       authorId: json['author_id'] as String,
//       author: authorMap,
//       postMedia: mediaList,
//       tags: tagsList,
//       likeCount: json['like_count'] as int? ?? 0,
//       favoriteCount: json['favorite_count'] as int? ?? 0,
//       commentCount: json['comment_count'] as int? ?? 0,
//       createdAt: DateTime.parse(json['created_at'] as String),
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'id': id,
//       'title': title,
//       'content': content,
//       'channel': channel,
//       'author_id': authorId,
//       'author': author,
//       'post_media': postMedia,
//       'tags': tags,
//       'like_count': likeCount,
//       'favorite_count': favoriteCount,
//       'comment_count': commentCount,
//       'created_at': createdAt.toIso8601String(),
//     };
//   }
// }

class Post {
  final String id;
  final String title;
  final String? content;
  final String channel;
  final String authorId;
  final Map<String, dynamic>? author;
  final List<Map<String, dynamic>>? postMedia;
  final List<Map<String, dynamic>>? tags;
  final int likeCount;
  final int favoriteCount;
  final int commentCount;
  final DateTime createdAt;
  
  // ✅ 新增：活动相关字段
  final int? eventId;
  final DateTime? eventStartTime;
  final DateTime? eventEndTime;
  final String? eventLocation;
  final String? eventCity;
  final String? eventTicketUrl;
  final int? eventParticipantCount;

  Post({
    required this.id,
    required this.title,
    this.content,
    required this.channel,
    required this.authorId,
    this.author,
    this.postMedia,
    this.tags,
    required this.likeCount,
    required this.favoriteCount,
    required this.commentCount,
    required this.createdAt,
    
    // ✅ 新增：活动字段
    this.eventId,
    this.eventStartTime,
    this.eventEndTime,
    this.eventLocation,
    this.eventCity,
    this.eventTicketUrl,
    this.eventParticipantCount,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    // ✅ 原有处理逻辑保持不变...
    Map<String, dynamic>? authorMap;
    final authorData = json['author'];
    if (authorData is Map) {
      authorMap = Map<String, dynamic>.from(authorData);
    }

    List<Map<String, dynamic>>? mediaList;
    final mediaData = json['post_media'];
    if (mediaData is List) {
      mediaList = mediaData
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    List<Map<String, dynamic>>? tagsList;
    final tagsData = json['tags'];
    if (tagsData is List) {
      tagsList = tagsData
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    // ✅ 新增：活动字段处理
    DateTime? parseEventTime(String? timeString) {
      if (timeString == null) return null;
      try {
        return DateTime.parse(timeString);
      } catch (e) {
        return null;
      }
    }

    return Post(
      id: json['id'].toString(),
      title: json['title'] as String? ?? '',
      content: json['content'] as String?,
      channel: json['channel'] as String,
      authorId: json['author_id'] as String,
      author: authorMap,
      postMedia: mediaList,
      tags: tagsList,
      likeCount: json['like_count'] as int? ?? 0,
      favoriteCount: json['favorite_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      
      // ✅ 新增：活动字段
      eventId: json['event_id'] as int?,
      eventStartTime: parseEventTime(json['event_start_time'] as String?),
      eventEndTime: parseEventTime(json['event_end_time'] as String?),
      eventLocation: json['event_location'] as String?,
      eventCity: json['event_city'] as String?,
      eventTicketUrl: json['event_ticket_url'] as String?,
      eventParticipantCount: json['event_participant_count'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'channel': channel,
      'author_id': authorId,
      'author': author,
      'post_media': postMedia,
      'tags': tags,
      'like_count': likeCount,
      'favorite_count': favoriteCount,
      'comment_count': commentCount,
      'created_at': createdAt.toIso8601String(),
      
      // ✅ 新增：活动字段
      'event_id': eventId,
      'event_start_time': eventStartTime?.toIso8601String(),
      'event_end_time': eventEndTime?.toIso8601String(),
      'event_location': eventLocation,
      'event_city': eventCity,
      'event_ticket_url': eventTicketUrl,
      'event_participant_count': eventParticipantCount,
    };
  }

  // ✅ 新增：便捷方法判断是否为活动帖子
  bool get isEventPost => channel == 'event';
  
  // ✅ 新增：便捷方法获取活动状态
  String get eventStatus {
    if (!isEventPost) return 'not_event';
    final now = DateTime.now();
    if (eventStartTime == null || eventEndTime == null) return 'unknown';
    if (now.isBefore(eventStartTime!)) return 'upcoming';
    if (now.isAfter(eventEndTime!)) return 'ended';
    return 'ongoing';
  }
}