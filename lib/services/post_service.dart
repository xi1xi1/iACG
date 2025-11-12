import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/supabase_client.dart';

class PostService {
  final _client = AppSupabaseClient().client;

  // 分类映射：数据库英文值 -> 界面中文显示
  static const Map<String, String> _categoryMapping = {
    'anime': '动漫',
    'game': '游戏',
    'comic': '漫画',
    'novel': '小说',
    'other': '其他'
  };

  // 获取分类的中文显示名称
  String getCategoryDisplayName(String? dbCategory) {
    if (dbCategory == null) return '其他';
    return _categoryMapping[dbCategory] ?? '其他';
  }

  // 获取中文分类对应的数据库值
  String? getCategoryDbValue(String displayName) {
    if (displayName == '全部') return null;

    // 直接映射中文到英文
    switch (displayName) {
      case '动漫':
        return 'anime';
      case '游戏':
        return 'game';
      case '漫画':
        return 'comic';
      case '小说':
        return 'novel';
      case '其他':
        return 'other';
      default:
        return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchRecommendPosts() async {
    final response = await _client
        .from('posts')
        .select('''
          *,
          author:profiles!posts_author_id_fkey(nickname, avatar_url, is_coser),
          post_media(media_url, media_type, sort_order),
          tags:post_tags(tag:tags(id, name, type))
        ''')
        .eq('channel', 'cos')
        .eq('is_deleted', false)
        .eq('status', 'normal')
        .order('created_at', ascending: false)
        .limit(20);

    return (response as List).cast<Map<String, dynamic>>();
  }

  // 修复的 COS 帖子查询方法
  // 在 PostService 类中修改 fetchCosPosts 方法，添加 IP 筛选
  Future<List<Map<String, dynamic>>> fetchCosPosts({
    String? category,
    String? ipTag,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('=== 开始获取COS帖子 ===');
        debugPrint('请求分类: $category, IP标签: $ipTag');
      }

      var query = _client
          .from('posts')
          .select('''
          *,
          author:profiles!posts_author_id_fkey(nickname, avatar_url, is_coser),
          post_media(media_url, media_type, sort_order),
          tags:post_tags(tag:tags(id, name, type))
        ''')
          .eq('channel', 'cos')
          .eq('is_deleted', false)
          .eq('status', 'normal');

      // 按分类筛选
      if (category != null && category.isNotEmpty && category != '全部') {
        final dbCategory = getCategoryDbValue(category);
        if (dbCategory != null) {
          if (kDebugMode) {
            debugPrint('应用分类筛选: $category -> $dbCategory');
          }
          query = query.eq('main_category', dbCategory);
        }
      }

      // 按 IP 标签筛选
      if (ipTag != null && ipTag.isNotEmpty && ipTag != '全部') {
        if (kDebugMode) {
          debugPrint('应用IP标签筛选: $ipTag');
        }
        // 通过 post_tags 关联表筛选
        query = query.filter('tags.tag.name', 'eq', ipTag);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(20)
          .timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        debugPrint('✅ COS查询成功，获取到 ${response.length} 条帖子');
      }

      return (response as List).cast<Map<String, dynamic>>();
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('❌ COS查询超时');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 获取COS帖子时出错: $e');
      }
      rethrow;
    }
  }

// 获取热门 IP 标签（用于 COS 筛选）
  Future<List<Map<String, dynamic>>> fetchHotCosIpTags() async {
    try {
      final response = await _client
          .from('tags')
          .select('id, name, type')
          .eq('type', 'ip')
          .eq('is_active', true)
          .limit(12) // COS 页面可以显示更多 IP 标签
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 获取热门IP标签时出错: $e');
      }
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchFollowPosts(String userId) async {
    try {
      // 先获取关注列表
      final followsResponse = await _client
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId);

      if (followsResponse.isEmpty) {
        return [];
      }

      final followingIds =
          followsResponse.map((f) => f['following_id'] as String).toList();

      final response = await _client
          .from('posts')
          .select('''
            *,
            author:profiles!posts_author_id_fkey(nickname, avatar_url, is_coser),
            post_media(media_url, media_type, sort_order),
            tags:post_tags(tag:tags(id, name, type))
          ''')
          .eq('channel', 'cos')
          .eq('is_deleted', false)
          .eq('status', 'normal')
          .inFilter('author_id', followingIds)
          .order('created_at', ascending: false)
          .limit(20);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  // 获取群岛帖子
  // 在 PostService 类中修复群岛帖子查询方法
  Future<List<Map<String, dynamic>>> fetchIslandPosts(
      {String? islandType}) async {
    try {
      if (kDebugMode) {
        debugPrint('=== 开始获取群岛帖子 ===');
        debugPrint('请求类型: $islandType');
      }

      var query = _client
          .from('posts')
          .select('''
          id, title, content, island_type, created_at, comment_count, view_count,
          author:profiles!posts_author_id_fkey(nickname, avatar_url)
        ''')
          .eq('channel', 'island')
          .eq('is_deleted', false)
          .eq('status', 'normal');

      // 按类型筛选 - 只有当类型不为空且不是"全部"时才添加筛选条件
      if (islandType != null && islandType.isNotEmpty && islandType != '全部') {
        if (kDebugMode) {
          debugPrint('应用类型筛选: $islandType');
        }
        query = query.eq('island_type', islandType);
      }

      // 增加超时时间到15秒，避免快速点击导致的卡顿
      final response = await query
          .order('created_at', ascending: false)
          .limit(20)
          .timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        debugPrint('✅ 群岛查询成功，获取到 ${response.length} 条帖子');

        // 调试信息：显示查询到的帖子类型
        for (var post in response) {
          debugPrint('帖子: ${post['title']}, 类型: ${post['island_type']}');
        }
      }

      return (response as List).cast<Map<String, dynamic>>();
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('❌ 群岛查询超时');
      }
      throw Exception('请求超时，请稍后重试');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 获取群岛帖子时出错: $e');
      }
      throw Exception('加载失败: ${e.toString()}');
    }
  }
}
