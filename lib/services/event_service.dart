import '../core/supabase_client.dart';
import 'post_service.dart';
import 'tag_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventService {
  final _client = AppSupabaseClient().client;
  final _tagService = TagService();
  final _postService = PostService();

  // 获取即将开始的活动 - 包含帖子图片（支持分页）
  Future<List<Map<String, dynamic>>> fetchUpcomingEvents({
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final offset = (page - 1) * pageSize;

      final response = await _client
          .from('events')
          .select('''
            *,
            post:posts!events_post_id_fkey(
              id, 
              title, 
              content, 
              author_id,
              post_media(
                id,
                media_url,
                media_type,
                sort_order
              )
            ),
            event_tag:tags!events_event_tag_id_fkey(id, name)
          ''')
          .gte('start_time', DateTime.now().toIso8601String())
          .order('start_time', ascending: true)
          .range(offset, offset + pageSize - 1);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('获取活动列表失败: $e');
<<<<<<< HEAD
      rethrow;
=======
      throw e;
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
    }
  }

  // 获取所有活动 - 包含帖子图片（支持分页）
  Future<List<Map<String, dynamic>>> fetchAllEvents({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final offset = (page - 1) * pageSize;

      final response = await _client
          .from('events')
          .select('''
            *,
            post:posts!events_post_id_fkey(
              id, 
              title, 
              content, 
              author_id,
              post_media(
                id,
                media_url,
                media_type,
                sort_order
              )
            ),
            event_tag:tags!events_event_tag_id_fkey(id, name)
          ''')
          .order('start_time', ascending: false)
          .range(offset, offset + pageSize - 1);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('获取所有活动失败: $e');
<<<<<<< HEAD
      rethrow;
=======
      throw e;
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
    }
  }

  // 按城市筛选活动 - 包含帖子图片（支持分页）
  Future<List<Map<String, dynamic>>> fetchEventsByCity(
    String city, {
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final offset = (page - 1) * pageSize;

      final response = await _client
          .from('events')
          .select('''
            *,
            post:posts!events_post_id_fkey(
              id, 
              title, 
              content, 
              author_id,
              post_media(
                id,
                media_url,
                media_type,
                sort_order
              )
            ),
            event_tag:tags!events_event_tag_id_fkey(id, name)
          ''')
          .eq('city', city)
          .gte('start_time', DateTime.now().toIso8601String())
          .order('start_time', ascending: true)
          .range(offset, offset + pageSize - 1);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('按城市获取活动失败: $e');
<<<<<<< HEAD
      rethrow;
=======
      throw e;
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
    }
  }

  // 获取热门活动 - 包含帖子图片（支持分页）
  Future<List<Map<String, dynamic>>> fetchFeaturedEvents({
    int limit = 5,
    int page = 1,
  }) async {
    try {
      final offset = (page - 1) * limit;

      final response = await _client
          .from('events')
          .select('''
            *,
            post:posts!events_post_id_fkey(
              id, 
              title, 
              content, 
              author_id,
              post_media(
                id,
                media_url,
                media_type,
                sort_order
              )
            ),
            event_tag:tags!events_event_tag_id_fkey(id, name)
          ''')
          .eq('is_featured', true)
          .gte('start_time', DateTime.now().toIso8601String())
          .order('start_time', ascending: true)
          .range(offset, offset + limit - 1);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('获取热门活动失败: $e');
<<<<<<< HEAD
      rethrow;
=======
      throw e;
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
    }
  }

  // 专门为首页优化的活动查询方法（支持分页）
  Future<List<Map<String, dynamic>>> fetchHomePageEvents({
    int page = 1,
    int pageSize = 5,
  }) async {
    try {
      final offset = (page - 1) * pageSize;

      final response = await _client
          .from('events')
          .select('''
            *,
            post:posts!events_post_id_fkey(
              id,
              title,
              post_media(
                id,
                media_url,
                media_type,
                sort_order
              )
            )
          ''')
          .gte('start_time', DateTime.now().toIso8601String())
          .order('start_time', ascending: true)
          .range(offset, offset + pageSize - 1);

      // 处理返回数据，将帖子图片合并到活动数据中
      List<Map<String, dynamic>> events = [];
      for (var event in response) {
        Map<String, dynamic> eventData = Map<String, dynamic>.from(event);

        // 从关联的帖子中获取图片数据
        if (event['post'] != null) {
          final postData = event['post'];
          if (postData['post_media'] != null &&
              postData['post_media'] is List) {
            eventData['post_media'] = postData['post_media'];
          }
          // 添加帖子标题作为备用
          if (postData['title'] != null) {
            eventData['post_title'] = postData['title'];
          }
        }

        events.add(eventData);
      }

      return events;
    } catch (e) {
      print('获取首页活动数据失败: $e');
<<<<<<< HEAD
      rethrow;
=======
      throw e;
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
    }
  }

  // ✅ 新增：创建活动（集成帖子系统）
  Future<Map<String, dynamic>> createEvent({
    required String name,
    required String title,
    required String content,
    required String authorId,
    required DateTime startTime,
    required DateTime endTime,
    required String location,
    String? city,
    String? ticketUrl,
    String? coverImage,
    String? eventTag,
  }) async {
    int? eventTagId;

    // 1. 处理活动标签
    if (eventTag != null && eventTag.trim().isNotEmpty) {
      // 如果有单独的活动标签，使用它
      final eventTagIds = await _tagService.ensureTagsAndReturnIds(
          [eventTag.trim()],
          type: 'theme' // ✅ 活动标签使用 'theme' 类型
          );
      if (eventTagIds.isNotEmpty) {
        eventTagId = eventTagIds.first;
      }
    } else {
      // 如果没有单独的活动标签，使用活动名称作为标签
      final eventTagIds = await _tagService
          .ensureTagsAndReturnIds([name], type: 'theme' // ✅ 活动标签使用 'theme' 类型
              );
      if (eventTagIds.isNotEmpty) {
        eventTagId = eventTagIds.first;
      }
    }

    // 2. 创建活动详情帖子
    final postId = await _postService.createPost(
      authorId: authorId,
      channel: 'event',
      title: title,
      content: content,
      eventStartTime: startTime,
      eventEndTime: endTime,
      eventLocation: location,
      eventCity: city,
      eventTicketUrl: ticketUrl,
    );

    // 3. 给活动帖子打上专属标签
    if (eventTagId != null) {
      await _postService.attachTags(postId, [eventTagId]);
    }

    // 4. 创建活动记录
    final eventData = {
      'name': name,
      'city': city,
      'location': location,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'ticket_url': ticketUrl,
      'post_id': postId,
      'event_tag_id': eventTagId, // ✅ 存储标签ID
      'organizer_id': authorId,
      'cover_image': coverImage,
      'description': content,
    }..removeWhere((key, value) => value == null);

    final eventResult =
        await _client.from('events').insert(eventData).select('id').single();

    return {
      'eventId': eventResult['id'],
      'postId': postId,
      'tagId': eventTagId,
    };
  }

  // ✅ 新增：获取活动详情（包含完整信息）
  Future<Map<String, dynamic>?> getEventDetail(int eventId) async {
    final event = await _client.from('events').select('''
          *,
          post:posts!events_post_id_fkey(
            id, title, content, author_id, created_at,
            like_count, favorite_count, comment_count, view_count,
            event_start_time, event_end_time, event_location, event_city, event_ticket_url,
            author:profiles!posts_author_id_fkey(id, nickname, avatar_url),
            post_media(
              id,
              media_url,
              media_type,
              sort_order
            )
          ),
          event_tag:tags!events_event_tag_id_fkey(id, name),
          organizer:profiles!events_organizer_id_fkey(id, nickname, avatar_url)
        ''').eq('id', eventId).maybeSingle();

<<<<<<< HEAD
    return event;
=======
    return event as Map<String, dynamic>?;
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
  }
}
