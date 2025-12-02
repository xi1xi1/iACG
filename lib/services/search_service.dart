// // lib/services/search_service.dart
// import 'package:iacg/core/supabase_client.dart';

// class SearchService {
//   final _client = AppSupabaseClient().client;

//   /// 搜索用户
//   Future<List<Map<String, dynamic>>> searchUsers(String query) async {
//     if (query.isEmpty) return [];
    
//     final result = await _client
//         .from('profiles')
//         .select('id, nickname, avatar_url')
//         .ilike('nickname', '%$query%')
//         .limit(10);
        
//     return (result as List).cast<Map<String, dynamic>>();
//   }

// // 搜索帖子（支持频道过滤 & 分页）
// Future<List<Map<String, dynamic>>> searchPosts({
//   required String query,
//   String? channel, // 'cos' | 'island' | null
//   int limit = 20,
//   int offset = 0,
// }) async {
//   if (query.trim().isEmpty) return [];
//   final q = query.trim();

//   final List result;

//   if (channel == null) {
//     // 不过滤频道的整条链
//     result = await _client
//         .from('posts')
//         .select('''
//           id, author_id, channel, title, content, main_category, main_ip_tag_id,
//           like_count, favorite_count, comment_count, view_count, created_at
//         ''')
//         .or('title.ilike.%$q%,content.ilike.%$q%')
//         .order('created_at', ascending: false)
//         .range(offset, offset + limit - 1);
//   } else {
//     // 过滤频道的整条链
//     result = await _client
//         .from('posts')
//         .select('''
//           id, author_id, channel, title, content, main_category, main_ip_tag_id,
//           like_count, favorite_count, comment_count, view_count, created_at
//         ''')
//         .eq('channel', channel) 
//         .or('title.ilike.%$q%,content.ilike.%$q%')
//         .order('created_at', ascending: false)
//         .range(offset, offset + limit - 1);
//   }

//   return (result).cast<Map<String, dynamic>>();
// }


//   // === 追加：搜索标签（分页）===
//   Future<List<Map<String, dynamic>>> searchTags({
//     required String query,
//     int limit = 20,
//     int offset = 0,
//   }) async {
//     if (query.trim().isEmpty) return [];

//     final result = await _client
//         .from('tags')
//         .select('id, name, type, is_active, created_at')
//         .ilike('name', '%${query.trim()}%')
//         .order('created_at', ascending: false)
//         .range(offset, offset + limit - 1);

//     return (result as List).cast<Map<String, dynamic>>();
//   }

//   // === 追加：搜索用户（分页版，不影响你现有的简版）===
//   Future<List<Map<String, dynamic>>> searchUsersPaged({
//     required String query,
//     int limit = 20,
//     int offset = 0,
//   }) async {
//     if (query.trim().isEmpty) return [];

//     final result = await _client
//         .from('profiles')
//         .select('id, nickname, avatar_url')
//         .ilike('nickname', '%${query.trim()}%')
//         .order('nickname', ascending: true)
//         .range(offset, offset + limit - 1);

//     return (result as List).cast<Map<String, dynamic>>();
//   }

//   // === 追加：聚合搜索（一次拿到 posts / tags / users 三类的前N条）===
//   Future<Map<String, List<Map<String, dynamic>>>> searchAll({
//     required String query,
//     int limitPerBucket = 10,
//   }) async {
//     if (query.trim().isEmpty) {
//       return {
//         'posts': <Map<String, dynamic>>[],
//         'tags': <Map<String, dynamic>>[],
//         'users': <Map<String, dynamic>>[],
//       };
//     }

//     // 并发拉取三类数据
//     final results = await Future.wait([
//       searchPosts(query: query, limit: limitPerBucket),
//       searchTags(query: query, limit: limitPerBucket),
//       searchUsersPaged(query: query, limit: limitPerBucket),
//     ]);

//     return {
//       'posts': results[0],
//       'tags': results[1],
//       'users': results[2],
//     };
//   }

//   // === 追加：频道专用便捷方法（可选）===
//   Future<List<Map<String, dynamic>>> searchCosPosts({
//     required String query,
//     int limit = 20,
//     int offset = 0,
//   }) =>
//       searchPosts(query: query, channel: 'cos', limit: limit, offset: offset);

//   Future<List<Map<String, dynamic>>> searchIslandPosts({
//     required String query,
//     int limit = 20,
//     int offset = 0,
//   }) =>
//       searchPosts(query: query, channel: 'island', limit: limit, offset: offset);

    
// }

// lib/services/search_service.dart
import 'package:iacg/core/supabase_client.dart';

class SearchService {
  final _client = AppSupabaseClient().client;

  // ---------- 用户：简版 ----------
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final rows = await _client
        .from('profiles')
        .select('id, nickname, avatar_url')
        .ilike('nickname', '%$q%')
        .limit(10);

    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  // ---------- 帖子搜索（ALL / COS / 群岛；分页；默认按“最热”） ----------
  // 热度排序：like_count desc → comment_count desc → view_count desc → created_at desc

  Future<List<Map<String, dynamic>>> searchPosts({
    required String query,
    String? channel, // 'cos' | 'island' | null=ALL
    int limit = 20,
    int offset = 0,
    String orderBy = 'hot', // 'hot' | 'latest'
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    // 添加author关联查询
    var filter = _client
        .from('posts')
        .select('''
          id, author_id, channel, title, content, main_category, main_ip_tag_id,
          like_count, favorite_count, comment_count, view_count, created_at,
          author:profiles!posts_author_id_fkey(id, nickname, avatar_url, is_coser),
          post_media(media_url, media_type, sort_order)
        ''')
        .eq('is_deleted', false)
        .eq('status', 'normal')
        .or('title.ilike.%$q%,content.ilike.%$q%');

    if (channel != null) {
      filter = filter.eq('channel', channel);
    }

    // 排序逻辑保持不变
    final ordered = (orderBy == 'latest')
        ? filter.order('created_at', ascending: false)
        : filter
            .order('like_count', ascending: false)
            .order('comment_count', ascending: false)
            .order('view_count', ascending: false)
            .order('created_at', ascending: false);

    final rows = await ordered.range(offset, offset + limit - 1);

    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  // ---------- 标签（分页） ----------
  Future<List<Map<String, dynamic>>> searchTags({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final rows = await _client
        .from('tags')
        .select('id, name, type, is_active, created_at')
        .ilike('name', '%$q%')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  // ---------- 用户（分页版） ----------
  Future<List<Map<String, dynamic>>> searchUsersPaged({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    // 获取当前用户ID用于检查关注状态
    final currentUserId = _client.auth.currentUser?.id;

    // 第一步：获取基本用户信息
    final rows = await _client
        .from('profiles')
        .select('id, nickname, avatar_url')
        .ilike('nickname', '%$q%')
        .order('nickname', ascending: true)
        .range(offset, offset + limit - 1);

    // 转换结果
    final List<Map<String, dynamic>> users = (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);

    // 第二步：为每个用户获取粉丝数、作品数和关注状态
    if (currentUserId != null) {
      for (final user in users) {
        final userId = user['id']?.toString();
        if (userId != null) {
          // 并发获取粉丝数、作品数和关注状态
          final results = await Future.wait([
            _getFollowerCount(userId),
            _getPostCount(userId),
            _checkIfFollowing(currentUserId, userId),
          ]);
          
          user['follower_count'] = results[0];
          user['post_count'] = results[1];
          user['is_following'] = results[2];
        }
      }
    } else {
      // 用户未登录，只获取粉丝数和作品数
      for (final user in users) {
        final userId = user['id']?.toString();
        if (userId != null) {
          final results = await Future.wait([
            _getFollowerCount(userId),
            _getPostCount(userId),
          ]);
          
          user['follower_count'] = results[0];
          user['post_count'] = results[1];
          user['is_following'] = false; // 未登录用户默认未关注
        }
      }
    }

    return users;
  }

  // 获取粉丝数
  Future<int> _getFollowerCount(String userId) async {
    try {
      final result = await _client
          .from('follows')
          .select('id')
          .eq('following_id', userId);
      
      return (result as List).length;
    } catch (e) {
      print('❌ 获取粉丝数失败: $e');
      return 0;
    }
  }

  // 获取作品数
  Future<int> _getPostCount(String userId) async {
    try {
      final result = await _client
          .from('posts')
          .select('id')
          .eq('author_id', userId)
          .eq('is_deleted', false)
          .eq('status', 'normal');
      
      return (result as List).length;
    } catch (e) {
      print('❌ 获取作品数失败: $e');
      return 0;
    }
  }

  // 检查是否已关注某个用户
  Future<bool> _checkIfFollowing(String followerId, String followingId) async {
    try {
      final result = await _client
          .from('follows')
          .select('id')
          .eq('follower_id', followerId)
          .eq('following_id', followingId)
          .maybeSingle();
      
      return result != null;
    } catch (e) {
      print('❌ 检查关注状态失败: $e');
      return false;
    }
  }

  // ---------- 聚合搜索：posts / tags / users 各取 N 条 ----------
  Future<Map<String, List<Map<String, dynamic>>>> searchAll({
    required String query,
    int limitPerBucket = 10,
  }) async {
    final q = query.trim();
    if (q.isEmpty) {
      return {
        'posts': <Map<String, dynamic>>[],
        'tags' : <Map<String, dynamic>>[],
        'users': <Map<String, dynamic>>[],
      };
    }

    final results = await Future.wait<List<Map<String, dynamic>>>([
      searchPosts(query: q, limit: limitPerBucket),              // 默认“最热”
      searchTags(query: q,  limit: limitPerBucket),
      searchUsersPaged(query: q, limit: limitPerBucket),
    ]);

    return {
      'posts': results[0],
      'tags' : results[1],
      'users': results[2],
    };
  }

  // ---------- 便捷方法 ----------
  Future<List<Map<String, dynamic>>> searchCosPosts({
    required String query,
    int limit = 20,
    int offset = 0,
    String orderBy = 'hot',
  }) =>
      searchPosts(
        query: query, 
        channel: 'cos', 
        limit: limit, 
        offset: offset, 
        orderBy: orderBy
      );

  Future<List<Map<String, dynamic>>> searchIslandPosts({
    required String query,
    int limit = 20,
    int offset = 0,
    String orderBy = 'hot',
  }) =>
      searchPosts(
        query: query, 
        channel: 'island', 
        limit: limit, 
        offset: offset, 
        orderBy: orderBy
      );


      // ---------- 活动搜索（分页） ----------
Future<List<Map<String, dynamic>>> searchEvents({
  required String query,
  int limit = 20,
  int offset = 0,
  String orderBy = 'hot', // 'hot' | 'latest'
}) async {
  final q = query.trim();
  if (q.isEmpty) return [];

  // 添加author关联查询
  var filter = _client
      .from('posts')
      .select('''
        id, author_id, channel, title, content, 
        event_start_time, event_end_time, event_location, event_city, event_ticket_url,
        like_count, favorite_count, comment_count, view_count, created_at,
        author:profiles!posts_author_id_fkey(id, nickname, avatar_url, is_coser),
        post_media(media_url, media_type, sort_order)
      ''')
      .eq('channel', 'event') // 只搜索活动帖子
      .eq('is_deleted', false)
      .eq('status', 'normal')
      .or('title.ilike.%$q%,content.ilike.%$q%,event_location.ilike.%$q%,event_city.ilike.%$q%');

  // 排序逻辑
  final ordered = (orderBy == 'latest')
      ? filter.order('created_at', ascending: false)
      : filter
          .order('like_count', ascending: false)
          .order('comment_count', ascending: false)
          .order('view_count', ascending: false)
          .order('created_at', ascending: false);

  final rows = await ordered.range(offset, offset + limit - 1);

  return (rows as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList(growable: false);
}
}
