import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../core/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:io';
import 'package:path/path.dart' as p;

/// PostService（B 负责）
/// - COS/群岛列表（含筛选、分页）
/// - 帖子详情（作者/媒体/标签）
/// - 关注流
class PostService {
  final _client = AppSupabaseClient().client;

  // 数据库英文值 <-> 界面中文显示
  static const Map<String, String> _categoryMapping = {
    'anime': '动漫',
    'game': '游戏',
    'comic': '漫画',
    'novel': '小说',
    'other': '其他'
  };

  String getCategoryDisplayName(String? dbCategory) {
    if (dbCategory == null) return '其他';
    return _categoryMapping[dbCategory] ?? '其他';
  }

  String? getCategoryDbValue(String displayName) {
    if (displayName == '全部') return null;
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

  // 在 PostService 类中添加以下方法

  /// 软删除帖子（仅作者和管理员可操作）
  Future<void> softDeletePost(int postId) async {
    try {
      // 检查当前用户是否有权限删除
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('请先登录');
      }

      // 获取帖子信息
      final post = await _client
          .from('posts')
          .select('author_id, is_deleted')
          .eq('id', postId)
          .single();

      // 检查是否是作者
      if (post['author_id'] != currentUser.id) {
        throw Exception('只有作者可以删除帖子');
      }

      // 检查是否已经删除
      if (post['is_deleted'] == true) {
        throw Exception('帖子已被删除');
      }

      // 执行软删除
      await _client.from('posts').update({
        'is_deleted': true,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', postId);
    } catch (e) {
      print('软删除帖子失败: $e');
      rethrow;
    }
  }

  /// 恢复软删除的帖子
  Future<void> restorePost(int postId) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('请先登录');
      }

      final post = await _client
          .from('posts')
          .select('author_id, is_deleted')
          .eq('id', postId)
          .single();

      if (post['author_id'] != currentUser.id) {
        throw Exception('只有作者可以恢复帖子');
      }

      if (post['is_deleted'] == false) {
        throw Exception('帖子未被删除');
      }

      await _client.from('posts').update({
        'is_deleted': false,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', postId);
    } catch (e) {
      print('恢复帖子失败: $e');
      rethrow;
    }
  }

  /// 检查当前用户是否是帖子作者
  Future<bool> isPostAuthor(int postId) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) return false;

      final post = await _client
          .from('posts')
          .select('author_id')
          .eq('id', postId)
          .single();

      return post['author_id'] == currentUser.id;
    } catch (e) {
      print('检查作者权限失败: $e');
      return false;
    }
  }

  // ==================== 关注相关方法 ====================

  /// 获取关注用户的帖子（包括cos和群岛帖）
  // 在 PostService 类中修改 fetchFollowingPosts 方法
  /// 获取关注用户的帖子（包括cos和群岛帖）
  Future<List<Map<String, dynamic>>> fetchFollowingPosts() async {
    try {
      // 检查用户是否登录
      if (_client.auth.currentUser == null) {
        throw Exception('用户未登录');
      }

      final userId = _client.auth.currentUser!.id;

      // 先获取关注的用户ID列表
      final followsResponse = await _client
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId);

      if (followsResponse.isEmpty) {
        return [];
      }

      final followingIds = (followsResponse as List)
          .map((f) => f['following_id'] as String)
          .toList();

      // 使用获取到的ID列表查询帖子 - 包括所有类型的帖子（cos, island, event等）
      final response = await _client
          .from('posts')
          .select('''
          *,
          author:profiles!posts_author_id_fkey(id, nickname, avatar_url),
          post_media(*),
          post_tags(tag:tags(*))
        ''')
          .inFilter('author_id', followingIds)
          .eq('is_deleted', false)
          .eq('status', 'normal')
          .eq('visibility', 'public')
          .order('created_at', ascending: false)
          .limit(100); // 增加限制数量

      // 调试：打印获取到的帖子类型分布
      final posts = (response as List).cast<Map<String, dynamic>>();
      final cosCount = posts.where((p) => p['channel'] == 'cos').length;
      final islandCount = posts.where((p) => p['channel'] == 'island').length;
      final eventCount = posts.where((p) => p['channel'] == 'event').length;
      final otherCount = posts.length - cosCount - islandCount - eventCount;
      
      print('=== fetchFollowingPosts 统计 ===');
      print('总帖子数: ${posts.length}');
      print('COS帖子: $cosCount');
      print('群岛帖子: $islandCount');
      print('活动帖子: $eventCount');
      print('其他类型: $otherCount');
      
      // 打印所有COS帖子的详细信息
      final cosPosts = posts.where((p) => p['channel'] == 'cos').toList();
      print('=== COS帖子详细信息 ===');
      for (int i = 0; i < cosPosts.length; i++) {
        final post = cosPosts[i];
        print('COS帖子 $i: id=${post['id']}, title=${post['title']}');
        print('媒体数量: ${(post['post_media'] as List?)?.length ?? 0}');
        print('作者: ${post['author']?['nickname']}');
        print('内容: ${post['content']?.toString().substring(0, min(50, (post['content']?.toString().length ?? 0)))}...');
        print('---');
      }
      print('=============================');

      return posts;
    } catch (e) {
      print('获取关注帖子失败: $e');
      throw Exception('获取关注内容失败');
    }
  }

  /// 获取当前用户关注的用户ID子查询
  // String _getFollowingUserIdsSubquery() {
  //   final userId = _client.auth.currentUser?.id;
  //   if (userId == null) {
  //     return "('')"; // 返回空集合
  //   }
  //   return '''
  //     (SELECT following_id 
  //      FROM follows 
  //      WHERE follower_id = '$userId')
  //   ''';
  // }
  
  /// 检查用户是否关注了某个用户
  Future<bool> isFollowing(String targetUserId) async {
    try {
      if (_client.auth.currentUser == null) return false;

      final response = await _client
          .from('follows')
          .select()
          .eq('follower_id', _client.auth.currentUser!.id)
          .eq('following_id', targetUserId)
          .maybeSingle()
          .onError((error, stackTrace) => null);

      return response != null;
    } catch (e) {
      print('检查关注状态失败: $e');
      return false;
    }
  }

  /// 关注用户
  Future<void> followUser(String targetUserId) async {
    if (_client.auth.currentUser == null) {
      throw Exception('用户未登录');
    }

    await _client.from('follows').insert({
      'follower_id': _client.auth.currentUser!.id,
      'following_id': targetUserId,
    });
  }

  /// 取消关注
  Future<void> unfollowUser(String targetUserId) async {
    if (_client.auth.currentUser == null) {
      throw Exception('用户未登录');
    }

    await _client
        .from('follows')
        .delete()
        .eq('follower_id', _client.auth.currentUser!.id)
        .eq('following_id', targetUserId);
  }
  /// 获取热门帖子（带时间衰减的热度算法） - 支持筛选的版本
Future<List<Map<String, dynamic>>> fetchHotPostsWithTimeDecayFiltered({
  int limit = 20,
  int offset = 0,
  String? category,  // 新增：分类筛选
  String? ipTag,     // 新增：IP标签筛选
  String postType = 'cos', // 新增：帖子类型，默认cos
}) async {
  try {
    print('🔥 开始获取热门帖子（筛选版），category=$category, ipTag=$ipTag, limit=$limit, offset=$offset');
    
    // ✅ 获取更多数据用于缓冲
    final fetchLimit = offset + limit + 50;
    
    // ✅ 修复：先查询有指定IP标签的帖子ID
    Set<int> ipFilteredPostIds = {};
    if (ipTag != null && ipTag.isNotEmpty && ipTag != '全部') {
      print('🔍 开始查询IP标签: $ipTag');
      
      try {
        // 1. 先查询标签ID
        final tagResult = await _client
            .from('tags')
            .select('id')
            .eq('name', ipTag)
            .eq('type', 'ip')
            .maybeSingle();
            
        if (tagResult != null) {
          final tagId = tagResult['id'] as int;
          print('✅ 找到IP标签ID: $tagId');
          
          // 2. 查询有该标签的帖子ID
          final taggedPostsResult = await _client
              .from('post_tags')
              .select('post_id')
              .eq('tag_id', tagId);
              
          if ((taggedPostsResult as List).isNotEmpty) {
            ipFilteredPostIds = (taggedPostsResult as List)
                .map((r) => r['post_id'] as int)
                .toSet();
            print('✅ 找到 ${ipFilteredPostIds.length} 个有该标签的帖子');
            
            if (ipFilteredPostIds.isEmpty) {
              print('⚠️ 没有帖子有这个IP标签');
              return []; // 直接返回空列表
            }
          } else {
            print('⚠️ 没有帖子有这个IP标签');
            return []; // 直接返回空列表
          }
        } else {
          print('⚠️ IP标签不存在: $ipTag');
          return []; // 直接返回空列表
        }
      } catch (e) {
        print('❌ IP标签查询失败: $e');
        // 如果查询失败，返回空列表避免错误数据
        return [];
      }
    }
    
    // ✅ 基础查询
    var query = _client
        .from('posts')
        .select('''
          id, channel, title, content, main_category, created_at,
          like_count, favorite_count, comment_count, view_count,
          author_id,
          author:profiles!posts_author_id_fkey(id, nickname, avatar_url, is_coser),
          post_media(media_url, media_type, sort_order),
          post_tags(tag:tags(id, name, type))
        ''')
        .eq('channel', postType) // 使用传入的postType
        .eq('is_deleted', false)
        .eq('status', 'normal')
        .eq('visibility', 'public');
    
    // ✅ 添加分类筛选
    if (category != null && category.isNotEmpty && category != '全部') {
      final dbCategory = getCategoryDbValue(category);
      if (dbCategory != null) {
        query = query.eq('main_category', dbCategory);
        print('🔍 应用分类筛选: $category -> $dbCategory');
      }
    }
    
    // ✅ 应用IP标签筛选（如果有）
    if (ipFilteredPostIds.isNotEmpty) {
      print('🔍 应用IP标签筛选，帖子ID列表: ${ipFilteredPostIds.take(10).toList()}...');
      query = query.inFilter('id', ipFilteredPostIds.toList());
    }
    
    // ✅ 执行查询
    final allPosts = await query
        .order('created_at', ascending: false)
        .limit(fetchLimit)
        .then((resp) => (resp as List).cast<Map<String, dynamic>>());

    print('📊 从数据库获取到 ${allPosts.length} 条帖子（筛选后）');

    if (allPosts.isEmpty) {
      print('📭 没有符合条件的帖子');
      return [];
    }

    // ✅ 热度计算算法（与原有方法相同）
    final now = DateTime.now();
    final List<Map<String, dynamic>> scoredPosts = allPosts.map((post) {
      try {
        final createdAtStr = post['created_at']?.toString() ?? '';
        if (createdAtStr.isEmpty) {
          print('⚠️ 帖子 ${post['id']} 缺少创建时间');
          return {
            'post': post,
            'hotScore': 0.0,
            'createdAt': null,
          };
        }
        
        final createdAt = DateTime.parse(createdAtStr);
        final hoursAgo = now.difference(createdAt).inHours.toDouble();
        
        // 基础分数
        final likeCount = (post['like_count'] as int? ?? 0);
        final favCount = (post['favorite_count'] as int? ?? 0);
        final commentCount = (post['comment_count'] as int? ?? 0);
        final viewCount = (post['view_count'] as int? ?? 0);
        
        final baseScore = 
          likeCount * 5.0 +
          favCount * 4.0 +
          commentCount * 3.0 +
          viewCount * 0.01;
        
        // 时间衰减函数 - 强化时间因素
        double timeFactor;

        if (hoursAgo < 1) {
          // 1小时内：增加优势到80%
          timeFactor = 0.55; // 1/1.8 = 0.55，相当于加成80%
        } else if (hoursAgo < 6) {
          // 1-6小时：较快的衰减
          timeFactor = 1.0 / (1.0 + (hoursAgo - 1) * 0.15);
        } else if (hoursAgo < 24) {
          // 6-24小时：继续衰减
          timeFactor = 1.0 / (1.0 + 5 * 0.15 + (hoursAgo - 6) * 0.1);
        } else if (hoursAgo < 168) { // 7天
          // 1-3天：加快衰减
          timeFactor = 1.0 / (1.0 + 5 * 0.15 + 18 * 0.1 + (hoursAgo - 24) * 0.15);
        } else if (hoursAgo < 720) { // 30天
          // 3-7天：更快的衰减
          timeFactor = 1.0 / (1.0 + 5 * 0.15 + 18 * 0.1 + 48 * 0.15 + (hoursAgo - 72) * 0.2);
        } else {
          // 7天以上：非常缓慢地衰减，但基本上失去权重
          timeFactor = 1.0 / (1.0 + 5 * 0.15 + 18 * 0.1 + 48 * 0.15 + 96 * 0.2 + (hoursAgo - 168) * 0.3);
        }
        
        final hotScore = baseScore * timeFactor;
        
        // 调试信息
        if (kDebugMode && post['id'] == allPosts.first['id']) {
          print('📊 热度计算示例 - 帖子ID: ${post['id']}');
          print('  发布时间: ${hoursAgo.toStringAsFixed(1)}小时前');
          print('  互动数据: 👍$likeCount ❤️$favCount 💬$commentCount 👁️$viewCount');
          print('  基础分: ${baseScore.toStringAsFixed(2)}, 时间因子: ${timeFactor.toStringAsFixed(4)}');
          print('  最终热度: ${hotScore.toStringAsFixed(2)}');
        }
        
        return {
          'post': post,
          'hotScore': hotScore,
          'createdAt': createdAt,
        };
      } catch (e) {
        print('❌ 计算帖子热度失败 ${post['id']}: $e');
        return {
          'post': post,
          'hotScore': 0.0,
          'createdAt': null,
        };
      }
    }).toList();

    // ✅ 按热度分排序
    scoredPosts.sort((a, b) {
      final scoreA = a['hotScore'] as double? ?? 0.0;
      final scoreB = b['hotScore'] as double? ?? 0.0;
      return scoreB.compareTo(scoreA); // 降序排序
    });
    
    // ✅ 调试输出
    if (kDebugMode && scoredPosts.isNotEmpty) {
      print('🏆 热度排名前5（筛选版）:');
      for (int i = 0; i < min(5, scoredPosts.length); i++) {
        final item = scoredPosts[i];
        final hotScore = item['hotScore'] as double? ?? 0.0;
        final post = item['post'] as Map<String, dynamic>;
        print('  ${i + 1}. 帖子ID: ${post['id']} '
              '热度: ${hotScore.toStringAsFixed(2)} '
              '👍${post['like_count']} '
              '❤️${post['favorite_count']} '
              '💬${post['comment_count']}');
      }
    }

    // ✅ 分页处理
    final startIndex = offset;
    final endIndex = min(offset + limit, scoredPosts.length);
    
    if (startIndex >= scoredPosts.length) {
      print('📭 分页超出范围: offset=$offset, 总数=${scoredPosts.length}');
      return [];
    }
    
    final result = scoredPosts
        .sublist(startIndex, endIndex)
        .map((item) => item['post'] as Map<String, dynamic>)
        .toList();

    print('✅ 返回 ${result.length} 条帖子 (筛选版, offset=$offset, limit=$limit)');
    
    // ✅ 验证结果（调试用）
    if (ipTag != null && ipTag.isNotEmpty && ipTag != '全部' && result.isNotEmpty) {
      final firstPostTags = (result.first['post_tags'] as List?)
          ?.map((t) => (t['tag']?['name'] as String?) ?? '')
          .where((name) => name.isNotEmpty)
          .toList() ?? [];
      
      print('🔍 验证IP筛选结果 - 第一条帖子的标签: $firstPostTags');
      print('🔍 是否包含筛选的IP标签 "$ipTag": ${firstPostTags.contains(ipTag)}');
    }
    
    return result;
    
  } catch (e, stackTrace) {
    print('❌ 获取热门帖子（筛选版）失败: $e');
    print('堆栈: $stackTrace');
    
    // ✅ 降级方案：使用原始的 fetchCosPosts 方法
    print('🔄 尝试降级到原始COS查询...');
    try {
      final dbCategory = category == '全部' ? null : category;
      final dbIpTag = ipTag == '全部' ? null : ipTag;
      
      return await fetchCosPosts(
        category: dbCategory,
        ipTag: dbIpTag,
        limit: limit,
        offset: offset,
      );
    } catch (fallbackError) {
      print('❌ 降级方案也失败: $fallbackError');
      return [];
    }
  }
}
// /// 获取热门帖子（带时间衰减的热度算法） - 支持筛选的版本
// Future<List<Map<String, dynamic>>> fetchHotPostsWithTimeDecayFiltered({
//   int limit = 20,
//   int offset = 0,
//   String? category,  // 新增：分类筛选
//   String? ipTag,     // 新增：IP标签筛选
//   String postType = 'cos', // 新增：帖子类型，默认cos
// }) async {
//   try {
//     print('🔥 开始获取热门帖子（筛选版），category=$category, ipTag=$ipTag, limit=$limit, offset=$offset');
    
//     // ✅ 获取更多数据用于缓冲
//     final fetchLimit = offset + limit + 50;
    
//     // ✅ 基础查询
//     var query = _client
//         .from('posts')
//         .select('''
//           id, channel, title, content, main_category, created_at,
//           like_count, favorite_count, comment_count, view_count,
//           author_id,
//           author:profiles!posts_author_id_fkey(id, nickname, avatar_url, is_coser),
//           post_media(media_url, media_type, sort_order),
//           post_tags(tag:tags(id, name, type))
//         ''')
//         .eq('channel', postType) // 使用传入的postType
//         .eq('is_deleted', false)
//         .eq('status', 'normal')
//         .eq('visibility', 'public');
    
//     // ✅ 添加分类筛选
//     if (category != null && category.isNotEmpty && category != '全部') {
//       final dbCategory = getCategoryDbValue(category);
//       if (dbCategory != null) {
//         query = query.eq('main_category', dbCategory);
//         print('🔍 应用分类筛选: $category -> $dbCategory');
//       }
//     }
    
//     // ✅ 添加IP标签筛选
//     if (ipTag != null && ipTag.isNotEmpty && ipTag != '全部') {
//       // 使用inner join确保只获取有该标签的帖子
//       query = query.eq('post_tags.tag.name', ipTag);
//       print('🔍 应用IP标签筛选: $ipTag');
//     }
    
//     final allPosts = await query
//         .order('created_at', ascending: false)
//         .limit(fetchLimit)
//         .then((resp) => (resp as List).cast<Map<String, dynamic>>());

//     print('📊 从数据库获取到 ${allPosts.length} 条帖子（筛选后）');

//     if (allPosts.isEmpty) {
//       print('📭 没有符合条件的帖子');
//       return [];
//     }

//     // ✅ 热度计算算法（与原有方法相同）
//     final now = DateTime.now();
//     final List<Map<String, dynamic>> scoredPosts = allPosts.map((post) {
//       try {
//         final createdAtStr = post['created_at']?.toString() ?? '';
//         if (createdAtStr.isEmpty) {
//           return {
//             'post': post,
//             'hotScore': 0.0,
//             'createdAt': null,
//           };
//         }
        
//         final createdAt = DateTime.parse(createdAtStr);
//         final hoursAgo = now.difference(createdAt).inHours.toDouble();
        
//         // 基础分数
//         final likeCount = (post['like_count'] as int? ?? 0);
//         final favCount = (post['favorite_count'] as int? ?? 0);
//         final commentCount = (post['comment_count'] as int? ?? 0);
//         final viewCount = (post['view_count'] as int? ?? 0);
        
//         final baseScore = 
//           likeCount * 5.0 +
//           favCount * 4.0 +
//           commentCount * 3.0 +
//           viewCount * 0.01;
        
//         // 时间衰减函数 - 强化时间因素
// double timeFactor;

// if (hoursAgo < 1) {
//   // 1小时内：增加优势到80%
//   timeFactor = 0.55; // 1/1.8 = 0.55，相当于加成80%
// } else if (hoursAgo < 6) {
//   // 1-6小时：较快的衰减
//   timeFactor = 1.0 / (1.0 + (hoursAgo - 1) * 0.15);
// } else if (hoursAgo < 24) {
//   // 6-24小时：继续衰减
//   timeFactor = 1.0 / (1.0 + 5 * 0.15 + (hoursAgo - 6) * 0.1);
// } else if (hoursAgo < 168) { // 7天
//   // 1-3天：加快衰减
//   timeFactor = 1.0 / (1.0 + 5 * 0.15 + 18 * 0.1 + (hoursAgo - 24) * 0.15);
// } else if (hoursAgo < 720) { // 30天
//   // 3-7天：更快的衰减
//   timeFactor = 1.0 / (1.0 + 5 * 0.15 + 18 * 0.1 + 48 * 0.15 + (hoursAgo - 72) * 0.2);
// } else {
//   // 7天以上：非常缓慢地衰减，但基本上失去权重
//   timeFactor = 1.0 / (1.0 + 5 * 0.15 + 18 * 0.1 + 48 * 0.15 + 96 * 0.2 + (hoursAgo - 168) * 0.3);
// }
        
//         final hotScore = baseScore * timeFactor;
        
//         return {
//           'post': post,
//           'hotScore': hotScore,
//           'createdAt': createdAt,
//         };
//       } catch (e) {
//         print('❌ 计算帖子热度失败 ${post['id']}: $e');
//         return {
//           'post': post,
//           'hotScore': 0.0,
//           'createdAt': null,
//         };
//       }
//     }).toList();

//     // ✅ 按热度分排序
//     scoredPosts.sort((a, b) {
//       final scoreA = a['hotScore'] as double? ?? 0.0;
//       final scoreB = b['hotScore'] as double? ?? 0.0;
//       return scoreB.compareTo(scoreA);
//     });
    
//     // ✅ 调试输出
//     if (kDebugMode && scoredPosts.isNotEmpty) {
//       print('🏆 热度排名前5（筛选版）:');
//       for (int i = 0; i < min(5, scoredPosts.length); i++) {
//         final item = scoredPosts[i];
//         final hotScore = item['hotScore'] as double? ?? 0.0;
//         final post = item['post'] as Map<String, dynamic>;
//         print('  ${i + 1}. 帖子ID: ${post['id']} '
//               '热度: ${hotScore.toStringAsFixed(2)} '
//               '👍${post['like_count']}');
//       }
//     }

//     // ✅ 分页处理
//     final startIndex = offset;
//     final endIndex = min(offset + limit, scoredPosts.length);
    
//     if (startIndex >= scoredPosts.length) {
//       print('📭 分页超出范围: offset=$offset, 总数=${scoredPosts.length}');
//       return [];
//     }
    
//     final result = scoredPosts
//         .sublist(startIndex, endIndex)
//         .map((item) => item['post'] as Map<String, dynamic>)
//         .toList();

//     print('✅ 返回 ${result.length} 条帖子 (筛选版, offset=$offset, limit=$limit)');
//     return result;
    
//   } catch (e, stackTrace) {
//     print('❌ 获取热门帖子（筛选版）失败: $e');
//     print('堆栈: $stackTrace');
    
//     // ✅ 降级方案：使用原始的 fetchCosPosts 方法
//     print('🔄 尝试降级到原始COS查询...');
//     try {
//       final dbCategory = category == '全部' ? null : category;
//       final dbIpTag = ipTag == '全部' ? null : ipTag;
      
//       return await fetchCosPosts(
//         category: dbCategory,
//         ipTag: dbIpTag,
//         limit: limit,
//         offset: offset,
//       );
//     } catch (fallbackError) {
//       print('❌ 降级方案也失败: $fallbackError');
//       return [];
//     }
//   }
// }
  // ==================== 原有的帖子相关方法 ====================
/// 获取热门帖子（带时间衰减的热度算法） - 修正版
Future<List<Map<String, dynamic>>> fetchHotPostsWithTimeDecay({
  int limit = 20,
  int offset = 0,
}) async {
  try {
    print('🔥 开始获取热门帖子，limit=$limit, offset=$offset');
    
    // ✅ 修复1：增加获取数量（覆盖分页范围 + 缓冲）
    final fetchLimit = offset + limit + 50; // 多取50条作为缓冲
    
    // ✅ 修复2：优化查询，避免获取过多不必要的数据
    final allPosts = await _client
        .from('posts')
        .select('''
          id, channel, title, content, main_category, created_at,
          like_count, favorite_count, comment_count, view_count,
          author_id,
          author:profiles!posts_author_id_fkey(id, nickname, avatar_url, is_coser),
          post_media(media_url, media_type, sort_order)
        ''')
        .eq('channel', 'cos')
        .eq('is_deleted', false)
        .eq('status', 'normal')
        .eq('visibility', 'public')
        .order('created_at', ascending: false)
        .limit(fetchLimit) // ✅ 动态限制
        .then((resp) => (resp as List).cast<Map<String, dynamic>>());

    print('📊 从数据库获取到 ${allPosts.length} 条帖子');

    if (allPosts.isEmpty) {
      print('📭 没有符合条件的帖子');
      return [];
    }

    // ✅ 修复3：改进的热度计算算法
    final now = DateTime.now();
    final List<Map<String, dynamic>> scoredPosts = allPosts.map((post) {
      try {
        final createdAtStr = post['created_at']?.toString() ?? '';
        if (createdAtStr.isEmpty) {
          print('⚠️ 帖子 ${post['id']} 缺少创建时间');
          return {
            'post': post,
            'hotScore': 0.0,
            'createdAt': null,
          };
        }
        
        final createdAt = DateTime.parse(createdAtStr);
        final hoursAgo = now.difference(createdAt).inHours.toDouble();
        
        // ✅ 基础分数（优化权重）
        final likeCount = (post['like_count'] as int? ?? 0);
        final favCount = (post['favorite_count'] as int? ?? 0);
        final commentCount = (post['comment_count'] as int? ?? 0);
        final viewCount = (post['view_count'] as int? ?? 0);
        
        // 权重：点赞 > 收藏 > 评论 > 浏览
        final baseScore = 
          likeCount * 5.0 +      // 点赞权重 5
          favCount * 6.0 +       // 收藏权重 6
          commentCount * 3.0 +   // 评论权重 3
          viewCount * 0.1;      // 浏览权重很低（防刷）
        
        // ✅ 改进的时间衰减函数（更平滑）
        // 公式：热度 = 基础分 / (时间衰减因子)
        // 新帖子有初始热度加成，随时间自然衰减
        double timeFactor;
        
        if (hoursAgo < 1) {
          // 1小时内：热度加成 50%
          timeFactor = 0.67; // 1/1.5 = 0.67，相当于加成50%
        } else if (hoursAgo < 24) {
          // 24小时内：线性衰减
          timeFactor = 1.0 / (1.0 + (hoursAgo - 1) * 0.05);
        } else if (hoursAgo < 168) { // 7天
          // 1-7天：衰减加快
          timeFactor = 1.0 / (1.0 + 24 * 0.05 + (hoursAgo - 24) * 0.1);
        } else {
          // 7天以上：缓慢衰减，但不会归零
          timeFactor = 1.0 / (1.0 + 24 * 0.05 + 144 * 0.1 + (hoursAgo - 168) * 0.02);
        }
        
        final hotScore = baseScore * timeFactor;
        
        if (kDebugMode && post['id'] == allPosts.first['id']) {
          print('📈 热度计算示例：');
          print('  帖子ID: ${post['id']}');
          print('  发布时间: $createdAt (${hoursAgo.toStringAsFixed(1)}小时前)');
          print('  互动数据: 👍${likeCount} ❤️${favCount} 💬${commentCount} 👁️${viewCount}');
          print('  基础分: ${baseScore.toStringAsFixed(2)}');
          print('  时间因子: ${timeFactor.toStringAsFixed(4)}');
          print('  最终热度: ${hotScore.toStringAsFixed(2)}');
        }
        
        return {
          'post': post,
          'hotScore': hotScore,
          'createdAt': createdAt,
        };
      } catch (e) {
        print('❌ 计算帖子热度失败 ${post['id']}: $e');
        return {
          'post': post,
          'hotScore': 0.0,
          'createdAt': null,
        };
      }
    }).toList();

    // ✅ 修复4：按热度分排序（添加空值检查）
    scoredPosts.sort((a, b) {
      final scoreA = a['hotScore'] as double? ?? 0.0;
      final scoreB = b['hotScore'] as double? ?? 0.0;
      return scoreB.compareTo(scoreA); // 降序排序
    });
    
    // ✅ 调试：打印前10的热度分布
    if (kDebugMode && scoredPosts.isNotEmpty) {
      print('🏆 热度排名前10:');
      for (int i = 0; i < min(10, scoredPosts.length); i++) {
        final item = scoredPosts[i];
        final hotScore = item['hotScore'] as double? ?? 0.0;
        final post = item['post'] as Map<String, dynamic>;
        print('  ${i + 1}. 帖子ID: ${post['id']} '
              '热度: ${hotScore.toStringAsFixed(2)} '
              '👍${post['like_count']}');
      }
    }

    // ✅ 修复5：正确处理分页边界
    final startIndex = offset;
    final endIndex = min(offset + limit, scoredPosts.length);
    
    if (startIndex >= scoredPosts.length) {
      print('📭 分页超出范围: offset=$offset, 总数=${scoredPosts.length}');
      return [];
    }
    
    final result = scoredPosts
        .sublist(startIndex, endIndex)
        .map((item) => item['post'] as Map<String, dynamic>)
        .toList();

    print('✅ 返回 ${result.length} 条帖子 (offset=$offset, limit=$limit)');
    return result;
    
  } catch (e, stackTrace) {
    print('❌ 获取热门帖子失败: $e');
    print('堆栈: $stackTrace');
    
    // ✅ 降级方案：如果算法失败，返回简单排序的帖子
    print('🔄 尝试降级方案...');
    try {
      return await _client
          .from('posts')
          .select('''
            id, channel, title, content, main_category, created_at,
            like_count, favorite_count, comment_count, view_count,
            author_id, post_media(media_url, media_type, sort_order),
            author:profiles!posts_author_id_fkey(id, nickname, avatar_url, is_coser)
          ''')
          .eq('channel', 'cos')
          .eq('is_deleted', false)
          .eq('status', 'normal')
          .eq('visibility', 'public')
          .order('like_count', ascending: false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1)
          .then((resp) => (resp as List).cast<Map<String, dynamic>>());
    } catch (fallbackError) {
      print('❌ 降级方案也失败: $fallbackError');
      return [];
    }
  }
}
  /// 推荐流（COS）——按时间降序；支持分页；每条只带首图封面
  Future<List<Map<String, dynamic>>> fetchRecommendPosts({
    int limit = 20,
    int offset = 0,
  }) async {
    final resp = await _client
        .from('posts')
        .select('''
          id, channel, title, content, main_category, created_at,
          like_count, favorite_count, comment_count, view_count, author_id,
          author:profiles!posts_author_id_fkey(id, nickname, avatar_url, is_coser),
          post_media(media_url, media_type, sort_order),
          post_tags(tag:tags(id, name, type))
        ''')
        .eq('channel', 'cos')
        .eq('is_deleted', false)
        .eq('status', 'normal')
        // 只取每个帖子的第一张图：对子表 post_media 做排序和限制
        .order('sort_order', ascending: true, referencedTable: 'post_media')
        .limit(1, referencedTable: 'post_media')
        // 主列表分页与排序
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (resp as List).cast<Map<String, dynamic>>();
  }

  /// COS 列表（类型/IP 筛选，支持分页）
  /// - category: 界面中文（动漫/游戏/漫画/小说/其他/全部）
  /// - ipTag: 标签名（当做精准匹配）
  Future<List<Map<String, dynamic>>> fetchCosPosts({
    String? category,
    String? ipTag,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('=== 开始获取COS帖子 ===');
        debugPrint(
            '请求分类: $category, IP标签: $ipTag, limit=$limit, offset=$offset');
      }

      final needIpFilter = ipTag != null && ipTag.isNotEmpty && ipTag != '全部';

      // 根据是否需要按 IP 过滤，选择 inner / left 连接
      final select = '''
        id, channel, title, content, main_category, created_at,
        like_count, favorite_count, comment_count, view_count, author_id,
        author:profiles!posts_author_id_fkey(id, nickname, avatar_url, is_coser),
        post_media(media_url, media_type, sort_order),
        ${needIpFilter ? "post_tags!inner(tag:tags!inner(id, name, type))" : "post_tags(tag:tags(id, name, type))"}
      ''';

      var query = _client
          .from('posts')
          .select(select)
          .eq('channel', 'cos')
          .eq('is_deleted', false)
          .eq('status', 'normal');

      // 类型筛选（中文 -> 英文枚举）
      if (category != null && category.isNotEmpty && category != '全部') {
        final dbCategory = getCategoryDbValue(category);
        if (dbCategory != null) {
          query = query.eq('main_category', dbCategory);
        }
      }

      // IP 标签筛选（只有 needIpFilter 时才对嵌套列做 eq）
      if (needIpFilter) {
        query = query.eq('post_tags.tag.name', ipTag);
      }

      final resp = await query
          // 子表首图
          .order('sort_order', ascending: true, referencedTable: 'post_media')
          .limit(1, referencedTable: 'post_media')
          // 主列表
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1)
          .timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        debugPrint('✅ COS查询成功，获取到 ${(resp as List).length} 条帖子');
      }
      return (resp as List).cast<Map<String, dynamic>>();
    } on TimeoutException {
      if (kDebugMode) debugPrint('❌ COS查询超时');
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ 获取COS帖子时出错: $e');
      rethrow;
    }
  }

  /// 关注流（关注的人发布的 COS 帖子）
  Future<List<Map<String, dynamic>>> fetchFollowPosts(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final follows = await _client
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId);

      if (follows.isEmpty) return [];

      final followingIds =
          (follows as List).map((f) => f['following_id'] as String).toList();

      final resp = await _client
          .from('posts')
          .select('''
            id, channel, title, content, main_category, created_at,
            like_count, favorite_count, comment_count, view_count, author_id,
            author:profiles!posts_author_id_fkey(id, nickname, avatar_url, is_coser),
            post_media(media_url, media_type, sort_order),
            post_tags(tag:tags(id, name, type))
          ''')
          .eq('channel', 'cos')
          .eq('is_deleted', false)
          .eq('status', 'normal')
          .inFilter('author_id', followingIds)
          // 子表首图
          .order('sort_order', ascending: true, referencedTable: 'post_media')
          .limit(1, referencedTable: 'post_media')
          // 主列表
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (resp as List).cast<Map<String, dynamic>>();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ 获取关注流失败: $e');
      return [];
    }
  }
/// 群岛列表（可按类型筛选，带可选封面），支持分页
Future<List<Map<String, dynamic>>> fetchIslandPosts({
  String? islandType, // '求助' / '分享' / ... / '全部'
  int limit = 20,
  int offset = 0,
}) async {
  try {
    if (kDebugMode) {
      debugPrint('=== 开始获取群岛帖子 ===');
      debugPrint('请求类型: $islandType, limit=$limit, offset=$offset');
    }

    var query = _client
        .from('posts')
        .select('''
          id, channel, title, content, island_type, created_at,
          comment_count, view_count, like_count, favorite_count, author_id,
          author:profiles!posts_author_id_fkey(id, nickname, avatar_url),
          post_media(media_url, media_type, sort_order)
        ''')
        .eq('channel', 'island')
        .eq('is_deleted', false)
        .eq('status', 'normal');

    if (islandType != null && islandType.isNotEmpty && islandType != '全部') {
      query = query.eq('island_type', islandType);
    }

    final resp = await query
        // 子表首图（可选）
        .order('sort_order', ascending: true, referencedTable: 'post_media')
        .limit(1, referencedTable: 'post_media')
        // 主列表
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1)
        .timeout(const Duration(seconds: 15));

    if (kDebugMode) {
      debugPrint('✅ 群岛查询成功，获取到 ${(resp as List).length} 条帖子');
    }

    return (resp as List).cast<Map<String, dynamic>>();
  } on TimeoutException {
    if (kDebugMode) debugPrint('❌ 群岛查询超时');
    throw Exception('请求超时，请稍后重试');
  } catch (e) {
    if (kDebugMode) debugPrint('❌ 获取群岛帖子时出错: $e');
    throw Exception('加载失败: ${e.toString()}');
  }
}
  // /// 群岛列表（可按类型筛选，带可选封面），支持分页
  // Future<List<Map<String, dynamic>>> fetchIslandPosts({
  //   String? islandType, // '求助' / '分享' / ... / '全部'
  //   int limit = 20,
  //   int offset = 0,
  // }) async {
  //   try {
  //     if (kDebugMode) {
  //       debugPrint('=== 开始获取群岛帖子 ===');
  //       debugPrint('请求类型: $islandType, limit=$limit, offset=$offset');
  //     }

  //     var query = _client
  //         .from('posts')
  //         .select('''
  //           id, channel, title, content, island_type, created_at,
  //           comment_count, view_count, author_id,
  //           author:profiles!posts_author_id_fkey(id, nickname, avatar_url),
  //           post_media(media_url, media_type, sort_order)
  //         ''')
  //         .eq('channel', 'island')
  //         .eq('is_deleted', false)
  //         .eq('status', 'normal');

  //     if (islandType != null && islandType.isNotEmpty && islandType != '全部') {
  //       query = query.eq('island_type', islandType);
  //     }

  //     final resp = await query
  //         // 子表首图（可选）
  //         .order('sort_order', ascending: true, referencedTable: 'post_media')
  //         .limit(1, referencedTable: 'post_media')
  //         // 主列表
  //         .order('created_at', ascending: false)
  //         .range(offset, offset + limit - 1)
  //         .timeout(const Duration(seconds: 15));

  //     if (kDebugMode) {
  //       debugPrint('✅ 群岛查询成功，获取到 ${(resp as List).length} 条帖子');
  //     }

  //     return (resp as List).cast<Map<String, dynamic>>();
  //   } on TimeoutException {
  //     if (kDebugMode) debugPrint('❌ 群岛查询超时');
  //     throw Exception('请求超时，请稍后重试');
  //   } catch (e) {
  //     if (kDebugMode) debugPrint('❌ 获取群岛帖子时出错: $e');
  //     throw Exception('加载失败: ${e.toString()}');
  //   }
  // }

  /// 按标签名聚合帖子（COS + 群岛），支持分页 & 排序（latest/hot）
  Future<List<Map<String, dynamic>>> fetchPostsByTag(
    String tagName, {
    int limit = 30,
    int offset = 0,
    String orderBy = 'latest', // 'latest' | 'hot'
  }) async {
    // 说明：
    // - latest：按 created_at desc
    // - hot  ：简单用 like_count desc, comment_count desc, view_count desc, created_at desc 作"热度"排序
    //   若你数据库里有 hot_score 列/视图，可把下面的多列排序替换成 order('hot_score', ascending: false)

    final base = _client
        .from('posts')
        .select('''
          id, channel, title, content, main_category, island_type, created_at,
          like_count, favorite_count, comment_count, view_count, author_id,
          author:profiles!posts_author_id_fkey(id, nickname, avatar_url, is_coser),
          post_media(media_url, media_type, sort_order),
          post_tags!inner(tag:tags!inner(id, name, type))
        ''')
        .eq('is_deleted', false)
        .eq('status', 'normal')
        .eq('post_tags.tag.name', tagName);

    // 排序策略
    if (orderBy == 'hot') {
      // 多关键字热度排序（无 hot_score 时的兼容版）
      // 按点赞、评论、浏览次数、发帖时间降序
      final resp = await base
          .order('like_count', ascending: false)
          .order('comment_count', ascending: false)
          .order('view_count', ascending: false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      // 把媒体按 sort_order 排好（避免在 select 里对子表再排序）
      for (final p in (resp as List)) {
        final media = (p['post_media'] as List? ?? [])
          ..sort(
              (a, b) => (a['sort_order'] ?? 0).compareTo(b['sort_order'] ?? 0));
        p['post_media'] = media;
      }
      return (resp as List).cast<Map<String, dynamic>>();
    } else {
      // latest：时间倒序
      final resp = await base
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      for (final p in (resp as List)) {
        final media = (p['post_media'] as List? ?? [])
          ..sort(
              (a, b) => (a['sort_order'] ?? 0).compareTo(b['sort_order'] ?? 0));
        p['post_media'] = media;
      }
      return (resp as List).cast<Map<String, dynamic>>();
    }
  }

  /// 帖子详情（作者 + 媒体 + 标签 + 协作者 + 原帖信息 + 活动信息），不区分 COS/群岛
  Future<Map<String, dynamic>?> getPostDetail(int postId) async {
    final res = await _client
        .from('posts')
        .select('''
          id, channel, title, content, main_category, island_type,
          like_count, favorite_count, comment_count, view_count, repost_count,
          created_at, author_id, original_post_id,
          event_start_time, event_end_time, event_location, event_city, event_ticket_url, 
          author:profiles!posts_author_id_fkey(id, nickname, avatar_url, is_coser),
          post_media(id, media_url, media_type, sort_order),
          post_tags(tag:tags(id, name, type)),
          collaborators:post_collaborators(
            id, role, display_name, user_id,
            user:profiles(id, nickname, avatar_url)
          ),
          original_post:original_post_id(
            id, title, content, author_id,
            author:profiles!posts_author_id_fkey(id, nickname, avatar_url)
          )
        ''')
        .eq('id', postId)
        .eq('is_deleted', false)
        .eq('status', 'normal')
        // 媒体按 sort_order 正序
        .order('sort_order', ascending: true, referencedTable: 'post_media')
        // 协作者按 id 正序
        .order('id', ascending: true, referencedTable: 'post_collaborators')
        .maybeSingle();

    if (res == null) return null;
    return res;
  }

  // —— 互动动作：点赞/收藏/评论 —— //

  Future<void> likePost(int postId, String userId) async {
    // 唯一约束 (post_id, user_id) 已在表上，重复会被忽略/报错；这里用 upsert 更稳妥
    await _client.from('post_likes').upsert(
      <String, dynamic>{'post_id': postId, 'user_id': userId},
      onConflict: 'post_id,user_id',
      ignoreDuplicates: true,
    );
  }

  Future<void> unlikePost(int postId, String userId) async {
    await _client
        .from('post_likes')
        .delete()
        .match({'post_id': postId, 'user_id': userId});
  }

  Future<void> favoritePost(int postId, String userId) async {
    await _client.from('post_favorites').upsert(
      <String, dynamic>{'post_id': postId, 'user_id': userId},
      onConflict: 'post_id,user_id',
      ignoreDuplicates: true,
    );
  }

  Future<void> unfavoritePost(int postId, String userId) async {
    await _client
        .from('post_favorites')
        .delete()
        .match({'post_id': postId, 'user_id': userId});
  }

  Future<List<Map<String, dynamic>>> listComments(
    int postId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final rows = await _client
        .from('post_comments')
        .select('''
          id, content, like_count, created_at,
          user:profiles!post_comments_user_id_fkey(id, nickname, avatar_url)
        ''')
        .eq('post_id', postId)
        .order('created_at', ascending: true)
        .range(offset, offset + limit - 1);

    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> addComment({
    required int postId,
    required String userId,
    required String text,
    int? parentId,
  }) async {
    await _client.from('post_comments').insert(<String, dynamic>{
      'post_id': postId,
      'user_id': userId,
      'content': text,
      if (parentId != null) 'parent_id': parentId,
    });
  }

  /// 获取活动相关帖子（基于活动专属的theme标签，按热度排序）
  Future<List<Map<String, dynamic>>> getRelatedPostsByEventTag({
    required int currentPostId,
    required String eventTag,
    int limit = 6,
  }) async {
    try {
      print('=== 开始查询相关帖子 ===');
      print('当前帖子ID: $currentPostId');
      print('活动标签: $eventTag');

      // 先通过标签表找到对应的标签ID
      final tagResult = await _client
          .from('tags')
          .select('id')
          .eq('name', eventTag)
          .eq('type', 'theme')
          .maybeSingle();

      if (tagResult == null) {
        print('未找到活动标签: $eventTag');
        return [];
      }

      final tagId = tagResult['id'] as int;
      print('标签ID: $tagId');

      // 通过标签ID获取相关帖子
      final results = await _client.from('post_tags').select('''
            post_id,
            post:posts!inner(
              id, title, content, channel, 
              event_start_time, event_end_time, event_location, event_city,
              like_count, favorite_count, comment_count, view_count, created_at,
              is_deleted, status,
              post_media(media_url, media_type, sort_order)
            )
          ''').eq('tag_id', tagId).neq('post_id', currentPostId);

      print('查询结果数量: ${results.length}');

      // 提取帖子数据并去重
      final seenIds = <int>{};
      final posts = <Map<String, dynamic>>[];

      for (final result in results as List) {
        final post = result['post'] as Map<String, dynamic>?;
        if (post != null) {
          final postId = post['id'] as int;
          final isDeleted = post['is_deleted'] == true;
          final status = post['status'];

          print('帖子ID: $postId, 删除状态: $isDeleted, 状态: $status');

          if (!isDeleted && status == 'normal' && seenIds.add(postId)) {
            posts.add(post);
            print('添加帖子: ${post['title']}');
          }
        }
      }

      print('有效帖子数量: ${posts.length}');

      // 手动按热度排序
      posts.sort((a, b) {
        // 点赞数比较
        final likeCountA = (a['like_count'] ?? 0) as int;
        final likeCountB = (b['like_count'] ?? 0) as int;
        if (likeCountA != likeCountB) {
          return likeCountB.compareTo(likeCountA);
        }

        // 收藏数比较
        final favCountA = (a['favorite_count'] ?? 0) as int;
        final favCountB = (b['favorite_count'] ?? 0) as int;
        if (favCountA != favCountB) {
          return favCountB.compareTo(favCountA);
        }

        // 评论数比较
        final commentCountA = (a['comment_count'] ?? 0) as int;
        final commentCountB = (b['comment_count'] ?? 0) as int;
        if (commentCountA != commentCountB) {
          return commentCountB.compareTo(commentCountA);
        }

        // 浏览量比较
        final viewCountA = (a['view_count'] ?? 0) as int;
        final viewCountB = (b['view_count'] ?? 0) as int;
        if (viewCountA != viewCountB) {
          return viewCountB.compareTo(viewCountA);
        }

        // 发布时间比较
        final createdAtA = a['created_at'];
        final createdAtB = b['created_at'];
        final timeA =
            createdAtA is String ? DateTime.tryParse(createdAtA) : null;
        final timeB =
            createdAtB is String ? DateTime.tryParse(createdAtB) : null;

        if (timeA != null && timeB != null) {
          return timeB.compareTo(timeA);
        }

        return 0;
      });

      final finalPosts = posts.take(limit).toList();
      print('最终返回帖子数量: ${finalPosts.length}');
      return finalPosts;
    } catch (e) {
      print('获取活动相关帖子失败: $e');
      return [];
    }
  }

  // ✅ 新增：检查用户是否是organizer
  Future<bool> isUserOrganizer(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();

      return response['role'] == 'organizer';
    } catch (e) {
      print('检查用户角色失败: $e');
      return false;
    }
  }

  /// 发布帖子（COS/群岛/活动通用）
  Future<int> createPost({
    required String authorId,
    required String channel, // 'cos' | 'island' | 'event'
    required String title,
    String? content,
    String? mainCategory,
    int? mainIpTagId,
    String? islandType,
    String visibility = 'public',

    // 活动字段
    int? eventId,
    DateTime? eventStartTime,
    DateTime? eventEndTime,
    String? eventLocation,
    String? eventCity,
    String? eventTicketUrl,
    int? eventParticipantCount,
  }) async {
    // ✅ 新增：权限检查
    if (channel == 'event') {
      final isOrganizer = await isUserOrganizer(authorId);
      if (!isOrganizer) {
        throw Exception('只有活动组织者才能发布活动帖子');
      }
    }

    final data = <String, dynamic>{
      'author_id': authorId,
      'channel': channel,
      'title': title,
      'content': content,
      if (channel == 'cos' && mainCategory != null)
        'main_category': mainCategory,
      if (mainIpTagId != null) 'main_ip_tag_id': mainIpTagId,
      if (channel == 'island' && islandType != null) 'island_type': islandType,
      'visibility': visibility,

      // 活动字段
      'event_id': eventId,
      'event_start_time': eventStartTime?.toIso8601String(),
      'event_end_time': eventEndTime?.toIso8601String(),
      'event_location': eventLocation,
      'event_city': eventCity,
      'event_ticket_url': eventTicketUrl,
      'event_participant_count': eventParticipantCount,
    }..removeWhere((key, value) => value == null);

    final inserted =
        await _client.from('posts').insert(data).select('id').single();

    return inserted['id'] as int;
  }

  /// 绑定媒体（传入：[{media_url, media_type, sort_order}, ...]）
  Future<void> attachMedia(int postId, List<Map<String, String>> medias) async {
    if (medias.isEmpty) return;
    await _client.from('post_media').insert(medias.map((m) {
          return <String, dynamic>{
            'post_id': postId,
            'media_url': m['media_url'],
            'media_type': m['media_type'] ?? 'image',
            'sort_order': int.tryParse(m['sort_order'] ?? '0') ?? 0,
          };
        }).toList());
  }

  /// 绑定标签（去重由表的 UNIQUE(post_id, tag_id) 保障）
  Future<void> attachTags(int postId, List<int> tagIds) async {
    if (tagIds.isEmpty) return;
    await _client.from('post_tags').upsert(
          tagIds
              .map((id) => <String, dynamic>{'post_id': postId, 'tag_id': id})
              .toList(),
          onConflict: 'post_id,tag_id',
          ignoreDuplicates: true,
        );
  }

  // 只对"已登录用户"增加浏览量（推荐：走 RPC，绕过 RLS 的作者限制）
  Future<void> incrementViewCountIfAuthed(int postId) async {
    final user = _client.auth.currentUser;
    if (user == null) return; // 游客不计数

    try {
      // 需要数据库里先建同名函数（见下方 SQL）
      await _client.rpc('increment_post_view', params: {'p_post_id': postId});
    } catch (e) {
      if (kDebugMode) {
        debugPrint('incrementViewCountIfAuthed error: $e');
      }
    }
  }

  // 是否已点赞
  Future<bool> hasLiked(int postId, String userId) async {
    final rows = await _client
        .from('post_likes')
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', userId)
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  // 是否已收藏
  Future<bool> hasFavorited(int postId, String userId) async {
    final rows = await _client
        .from('post_favorites')
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', userId)
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  // 点赞切换：返回 "现在是否已点赞"
  Future<bool> toggleLike(int postId, String userId) async {
    if (await hasLiked(postId, userId)) {
      await _client.from('post_likes').delete().match({
        'post_id': postId,
        'user_id': userId,
      });
      return false;
    } else {
      // 唯一约束已存在，重复插入会报错；正常情况下不会触发
      await _client.from('post_likes').insert(<String, dynamic>{
        'post_id': postId,
        'user_id': userId,
      });
      return true;
    }
  }

  // 收藏切换：返回 "现在是否已收藏"
  Future<bool> toggleFavorite(int postId, String userId) async {
    if (await hasFavorited(postId, userId)) {
      await _client.from('post_favorites').delete().match({
        'post_id': postId,
        'user_id': userId,
      });
      return false;
    } else {
      await _client.from('post_favorites').insert(<String, dynamic>{
        'post_id': postId,
        'user_id': userId,
      });
      return true;
    }
  }

  /// 点/取消赞 评论（返回是否已点赞）
  Future<bool> toggleCommentLike(int commentId, String userId) async {
    // 先查是否点过
    final existed = await _client
        .from('comment_likes')
        .select('id')
        .eq('comment_id', commentId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existed != null) {
      // 取消点赞
      await _client
          .from('comment_likes')
          .delete()
          .eq('comment_id', commentId)
          .eq('user_id', userId);
      return false;
    } else {
      // 新增点赞
      await _client.from('comment_likes').insert(<String, dynamic>{
        'comment_id': commentId,
        'user_id': userId,
      });
      return true;
    }
  }

  /// 批量查询我点过赞的评论ID集合（用于首屏标记红心）
  Future<Set<int>> myLikedCommentIds(
      List<int> commentIds, String userId) async {
    if (commentIds.isEmpty) return <int>{};
    final rows = await _client
        .from('comment_likes')
        .select('comment_id')
        .eq('user_id', userId)
        .inFilter('comment_id', commentIds);
    return rows.map<int>((r) => r['comment_id'] as int).toSet();
  }

  // ✅ 顶层评论（parent_id IS NULL）
  Future<List<Map<String, dynamic>>> listTopComments(
    int postId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final q = _client
        .from('post_comments')
        .select('''
          id, content, created_at, like_count, user_id, parent_id,
          user:profiles!post_comments_user_id_fkey(id, nickname, avatar_url)
        ''')
        .eq('post_id', postId)
        .isFilter('parent_id', null)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    final data = await q;
    return (data as List).cast<Map<String, dynamic>>();
  }

  // ✅ 拉某一楼的"楼中楼"两层：L1=直接回一楼；L2=回 L1
  // 返回 {root, l1, l2} 三段，前端做 "A 回复 B" 的拼接
  Future<Map<String, dynamic>> fetchThread2Levels(int rootId) async {
    // 取一楼
    final root = await _client.from('post_comments').select('''
          id, content, created_at, like_count, user_id, parent_id,
          user:profiles!post_comments_user_id_fkey(id, nickname, avatar_url)
        ''').eq('id', rootId).maybeSingle();

    if (root == null) {
      return {
        'root': null,
        'l1': const <Map<String, dynamic>>[],
        'l2': const <Map<String, dynamic>>[]
      };
    }

    // 取 L1：parent_id = rootId
    final l1 = await _client.from('post_comments').select('''
          id, content, created_at, like_count, user_id, parent_id,
          user:profiles!post_comments_user_id_fkey(id, nickname, avatar_url)
        ''').eq('parent_id', rootId).order('created_at', ascending: true);

    final l1List = (l1 as List).cast<Map<String, dynamic>>();
    final l1Ids = l1List.map((e) => e['id'] as int).toList();

    // 取 L2：parent_id in l1Ids
    List<Map<String, dynamic>> l2List = const [];
    if (l1Ids.isNotEmpty) {
      final l2 = await _client
          .from('post_comments')
          .select('''
            id, content, created_at, like_count, user_id, parent_id,
            user:profiles!post_comments_user_id_fkey(id, nickname, avatar_url)
          ''')
          .inFilter('parent_id', l1Ids)
          .order('created_at', ascending: true);
      l2List = (l2 as List).cast<Map<String, dynamic>>();
    }

    return {'root': root, 'l1': l1List, 'l2': l2List};
  }

  /// 楼内直接回复列表（B站风格的"楼中楼"第二层）
  /// parentId = 顶层评论ID（或者任意一条评论的 id，按你的业务只拉 parent=这条的直接子回复）
  Future<List<Map<String, dynamic>>> listChildComments(
    int parentId, {
    int limit = 10,
    int offset = 0,
  }) async {
    final rows = await _client
        .from('post_comments')
        .select('''
          id, content, like_count, created_at, user_id, parent_id,
          user:profiles!post_comments_user_id_fkey(id, nickname, avatar_url)
        ''')
        .eq('parent_id', parentId)
        .order('created_at', ascending: true)
        .range(offset, offset + limit - 1);

    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// （可选兜底）单独提供 like / unlike 评论，供 toggleCommentLike 出错时回退调用
  Future<void> likeComment(int commentId, String userId) async {
    await _client.from('comment_likes').upsert(
      <String, dynamic>{'comment_id': commentId, 'user_id': userId},
      onConflict: 'comment_id,user_id',
      ignoreDuplicates: true,
    );
  }

  Future<void> unlikeComment(int commentId, String userId) async {
    await _client
        .from('comment_likes')
        .delete()
        .match({'comment_id': commentId, 'user_id': userId});
  }

  /// 拉某一楼的"整楼"扁平列表（主楼 + 全部子孙）
  /// 返回：Map { root: Map?, replies: List<Map> }
  Future<Map<String, dynamic>> fetchThreadFlat(int rootId) async {
    final rows =
        await _client.rpc('get_comment_thread', params: {'p_root_id': rootId});

    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) {
      return {'root': null, 'replies': <Map<String, dynamic>>[]};
    }
    // 第一条一定是 level=0 的主楼
    final root = list.firstWhere((e) => (e['level'] as int) == 0,
        orElse: () => list.first);
    final replies =
        list.where((e) => (e['level'] as int) >= 1).toList(growable: false);
    return {'root': root, 'replies': replies};
  }

  /// 批量查：我在这"整楼"里点过赞的评论 id 集合
  Future<Set<int>> myLikedInThread(List<int> commentIds, String userId) async {
    if (commentIds.isEmpty) return <int>{};
    final rows = await _client
        .from('comment_likes')
        .select('comment_id')
        .eq('user_id', userId)
        .inFilter('comment_id', commentIds);
    return rows.map<int>((r) => r['comment_id'] as int).toSet();
  }

  /// 获取活动帖子列表
  Future<List<Map<String, dynamic>>> fetchEventPosts({
    int limit = 20,
    int offset = 0,
  }) async {
    final resp = await _client
        .from('posts')
        .select('''
          id, channel, title, content, created_at,
          like_count, favorite_count, comment_count, view_count, author_id,
          event_start_time, event_end_time, event_location, event_city, event_ticket_url,
          author:profiles!posts_author_id_fkey(id, nickname, avatar_url, is_coser),
          post_media(media_url, media_type, sort_order),
          post_tags(tag:tags(id, name, type))
        ''')
        .eq('channel', 'event')
        .eq('is_deleted', false)
        .eq('status', 'normal')
        .order('event_start_time', ascending: true)
        .range(offset, offset + limit - 1);

    return (resp as List).cast<Map<String, dynamic>>();
  }

  // ==================== 转发功能相关方法 ====================

  /// 创建转发帖子
  Future<int> createRepost({
    required String authorId,
    required int originalPostId,
    String? comment, // 转发时的评论内容
    bool postCommentToOriginal = false, // 新增：是否在原帖下发评论
  }) async {
    try {
      // 1. 先获取原帖信息
      final originalPost = await getPostDetail(originalPostId);
      if (originalPost == null) {
        throw Exception('原帖不存在');
      }

      // 2. 构建转发内容
      String content = '';

      // 如果有评论，添加到转发内容中
      if (comment != null && comment.trim().isNotEmpty) {
        content = comment.trim(); // 只有评论内容
      }

      // 检查原帖是否是转发帖
      final originalPostIsRepost = originalPost['original_post_id'] != null;

      // 构建内容
      if (originalPostIsRepost) {
        // 如果原帖已经是转发帖，获取完整的转发链（不包含原帖帖主）
        final repostChain = await _getFullRepostChain(originalPost);
        if (content.isNotEmpty) {
          content += ' '; // 评论和转发链之间用空格分隔
        }
        content += repostChain;
      }
      // 如果是原帖（无论有无评论），都不添加原帖帖主信息

      // 3. 创建转发帖子
      final data = <String, dynamic>{
        'author_id': authorId,
        'channel': 'island', // 转发固定为群岛
        'title': '转发', // 转发标题固定
        'content': content.trim(),
        'island_type': '分享', // 转发类型固定为分享
        'original_post_id': originalPostId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response =
          await _client.from('posts').insert(data).select('id').single();

      final repostId = (response['id'] as num).toInt();

      // 4. 根据参数决定是否在原帖下发布评论
      if (postCommentToOriginal &&
          comment != null &&
          comment.trim().isNotEmpty) {
        await addComment(
          postId: originalPostId,
          userId: authorId,
          text: comment.trim(),
        );
      }

      // 5. 复制原帖的标签
      final originalTags = (originalPost['post_tags'] as List? ?? []);
      if (originalTags.isNotEmpty) {
        final tagNames = originalTags
            .map((t) => (t['tag']?['name'] as String?) ?? '')
            .where((name) => name.isNotEmpty)
            .toList();

        if (tagNames.isNotEmpty) {
          final tagIds = await _ensureTagsAndReturnIds(tagNames);
          await attachTags(repostId, tagIds);
        }
      }

      // 6. 更新原帖的转发计数
      await incrementRepostCount(originalPostId);

      return repostId;
    } catch (e) {
      if (kDebugMode) debugPrint('创建转发失败: $e');
      rethrow;
    }
  }

  /// 获取完整的转发链（不包含原帖帖主）
  Future<String> _getFullRepostChain(Map<String, dynamic> post) async {
    final chains = <String>[];

    // 从当前帖子开始递归获取转发链
    var currentPost = post;
    while (true) {
      final author = currentPost['author'] ?? {};
      final authorName = author['nickname'] ?? '佚名';
      final authorId = author['id'] as String? ?? 'unknown';
      final postContent = currentPost['content'] ?? '';

      // 关键修复：只提取当前用户的评论，不包含转发链内容
      final pureContent = _extractCurrentUserComment(postContent);

      // 添加当前层级的转发信息（只包含当前用户的评论）
      chains.add('//@[$authorId]$authorName：$pureContent');

      // 检查是否有原帖，继续向上追溯
      final originalPostId = currentPost['original_post_id'];
      if (originalPostId != null) {
        final originalPost = await getPostDetail(originalPostId as int);
        if (originalPost != null) {
          currentPost = originalPost;

          // 如果原帖不是转发帖（即原帖帖主），就停止追溯
          if (originalPost['original_post_id'] == null) {
            break;
          }
        } else {
          break; // 原帖不存在，停止追溯
        }
      } else {
        break; // 没有原帖，停止追溯
      }
    }

    // 用空格连接所有转发链（保持时间顺序：最新的在前面）
    return chains.join(' ');
  }

  /// 从内容中提取当前用户的评论（移除转发链部分）
  String _extractCurrentUserComment(String content) {
    // 找到第一个 "//@" 的位置
    final repostIndex = content.indexOf('//@');

    if (repostIndex == -1) {
      // 没有转发链，直接返回整个内容
      return content.trim();
    } else {
      // 只返回 "//@" 之前的部分（当前用户的评论）
      return content.substring(0, repostIndex).trim();
    }
  }

  /// 快速转发（不在原帖发评论）
  Future<int> createQuickRepost({
    required String authorId,
    required int originalPostId,
    String? comment, // 转发时的评论内容
  }) async {
    return await createRepost(
      authorId: authorId,
      originalPostId: originalPostId,
      comment: comment,
      postCommentToOriginal: false, // 不在原帖发评论
    );
  }

  /// 增加转发计数
  Future<void> incrementRepostCount(int postId) async {
    try {
      print('=== 开始增加转发计数 ===');
      print('帖子ID: $postId');

      // 先检查当前转发数
      final current = await _client
          .from('posts')
          .select('repost_count')
          .eq('id', postId)
          .single();
      print('当前转发数: ${current['repost_count']}');

      // 调用 RPC 函数
      await _client.rpc('increment_repost_count', params: {'post_id': postId});
      print('RPC 调用成功');

      // 再次检查转发数
      final updated = await _client
          .from('posts')
          .select('repost_count')
          .eq('id', postId)
          .single();
      print('更新后转发数: ${updated['repost_count']}');
    } catch (e) {
      print('增加转发计数失败: $e');
      print('错误详情: ${e.toString()}');
      // 如果RPC失败，使用备用方法
      await _incrementRepostCountFallback(postId);
    }
  }

  /// 增加转发计数的备用方法
  Future<void> _incrementRepostCountFallback(int postId) async {
    try {
      // 先获取当前转发数
      final current = await _client
          .from('posts')
          .select('repost_count')
          .eq('id', postId)
          .single();

      final currentCount = (current['repost_count'] as num?)?.toInt() ?? 0;
      final newCount = currentCount + 1;

      await _client
          .from('posts')
          .update({'repost_count': newCount}).eq('id', postId);
    } catch (e) {
      if (kDebugMode) debugPrint('备用增加转发计数方法也失败: $e');
      rethrow;
    }
  }

  /// 获取转发列表
  Future<List<Map<String, dynamic>>> getReposts(int postId) async {
    try {
      final response = await _client
          .from('posts')
          .select('''
            *,
            author:profiles!posts_author_id_fkey(id, nickname, avatar_url),
            post_media(media_url, media_type, sort_order),
            post_tags(tag:tags(id, name, type))
          ''')
          .eq('original_post_id', postId)
          .eq('is_deleted', false)
          .eq('status', 'normal')
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      if (kDebugMode) debugPrint('获取转发列表失败: $e');
      rethrow;
    }
  }

  /// 检查是否是转发帖子
  Future<bool> isRepost(int postId) async {
    try {
      final response = await _client
          .from('posts')
          .select('original_post_id')
          .eq('id', postId)
          .single();

      final originalPostId = response['original_post_id'];
      return originalPostId != null;
    } catch (e) {
      if (kDebugMode) debugPrint('检查转发帖子失败: $e');
      rethrow;
    }
  }

  /// 获取原帖信息
  Future<Map<String, dynamic>?> getOriginalPost(int repostId) async {
    try {
      final response = await _client.from('posts').select('''
            original_post:original_post_id(
              *,
              author:profiles!posts_author_id_fkey(id, nickname, avatar_url),
              post_media(media_url, media_type, sort_order),
              post_tags(tag:tags(id, name, type))
            )
          ''').eq('id', repostId).single();

      return response['original_post'] as Map<String, dynamic>?;
    } catch (e) {
      if (kDebugMode) debugPrint('获取原帖信息失败: $e');
      rethrow;
    }
  }

  /// 获取用户的转发历史
  Future<List<Map<String, dynamic>>> getUserReposts(String userId,
      {int limit = 20, int offset = 0}) async {
    try {
      final response = await _client
          .from('posts')
          .select('''
            *,
            original_post:original_post_id(
              *,
              author:profiles!posts_author_id_fkey(id, nickname, avatar_url),
              post_media(media_url, media_type, sort_order),
              post_tags(tag:tags(id, name, type))
            )
          ''')
          .eq('author_id', userId)
          .not('original_post_id', 'is', null) // 只获取转发帖子
          .eq('is_deleted', false)
          .eq('status', 'normal')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      if (kDebugMode) debugPrint('获取用户转发历史失败: $e');
      rethrow;
    }
  }

  /// 删除转发（同时减少原帖转发计数）
  Future<void> deleteRepost(int repostId) async {
    try {
      // 先获取原帖ID
      final response = await _client
          .from('posts')
          .select('original_post_id')
          .eq('id', repostId)
          .single();

      final originalPostId = response['original_post_id'] as int?;

      // 删除转发帖子（软删除）
      await _client
          .from('posts')
          .update({'is_deleted': true}).eq('id', repostId);

      // 减少原帖转发计数
      if (originalPostId != null) {
        await _decrementRepostCount(originalPostId);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('删除转发失败: $e');
      rethrow;
    }
  }

  /// 减少转发计数
  Future<void> _decrementRepostCount(int postId) async {
    try {
      // 先获取当前转发数
      final current = await _client
          .from('posts')
          .select('repost_count')
          .eq('id', postId)
          .single();

      final currentCount = (current['repost_count'] as num?)?.toInt() ?? 0;
      final newCount = (currentCount - 1).clamp(0, 1 << 30);

      await _client
          .from('posts')
          .update({'repost_count': newCount}).eq('id', postId);
    } catch (e) {
      if (kDebugMode) debugPrint('减少转发计数失败: $e');
      rethrow;
    }
  }

  /// 获取帖子转发统计
  Future<Map<String, dynamic>> getRepostStats(int postId) async {
    try {
      // 获取转发总数 - 使用 count() 方法
      final countResponse = await _client
          .from('posts')
          .select('id')
          .eq('original_post_id', postId)
          .eq('is_deleted', false)
          .eq('status', 'normal');

      // 获取最近转发的用户
      final recentResponse = await _client
          .from('posts')
          .select('''
            author:profiles!posts_author_id_fkey(id, nickname, avatar_url)
          ''')
          .eq('original_post_id', postId)
          .eq('is_deleted', false)
          .eq('status', 'normal')
          .order('created_at', ascending: false)
          .limit(5);

      return {
        'total_reposts': (countResponse as List).length,
        'recent_reposters':
            (recentResponse as List).cast<Map<String, dynamic>>(),
      };
    } catch (e) {
      if (kDebugMode) debugPrint('获取转发统计失败: $e');
      rethrow;
    }
  }

  /// 内部方法：确保标签存在并返回ID列表
  Future<List<int>> _ensureTagsAndReturnIds(List<String> tagNames) async {
    if (tagNames.isEmpty) return [];

    try {
      // 先查询已存在的标签
      final existingTags = await _client
          .from('tags')
          .select('id, name')
          .inFilter('name', tagNames);

      final existingMap = <String, int>{};
      for (final tag in (existingTags as List)) {
        existingMap[tag['name'] as String] = tag['id'] as int;
      }

      // 找出需要新增的标签
      final newTags =
          tagNames.where((name) => !existingMap.containsKey(name)).toList();
      final List<int> allTagIds = [...existingMap.values];

      // 插入新标签
      if (newTags.isNotEmpty) {
        final newTagData = newTags
            .map((name) => {
                  'name': name,
                  'type': 'general',
                  'created_at': DateTime.now().toIso8601String(),
                })
            .toList();

        final newTagResponse =
            await _client.from('tags').insert(newTagData).select('id');

        final newTagIds = (newTagResponse as List)
            .map<int>((tag) => tag['id'] as int)
            .toList();
        allTagIds.addAll(newTagIds);
      }

      return allTagIds;
    } catch (e) {
      if (kDebugMode) debugPrint('确保标签存在失败: $e');
      rethrow;
    }
  }
}

extension PostMediaUpload on PostService {
  /// 把本地文件上传到 Supabase Storage 的 post-images 桶，并返回可访问的 URL
  Future<String> uploadMediaFile({
    required int postId,
    required XFile xFile, // 改为使用 XFile
  }) async {
    const bucket = 'post-images';

    // 获取文件字节数据
    final bytes = await xFile.readAsBytes();

    // 处理文件名和扩展名
    final originalName = xFile.name;
    final ext = p.extension(originalName).toLowerCase();
    // 如果没有扩展名，默认使用 .jpg
    final finalExt = ext.isEmpty ? '.jpg' : ext;
    final filename = '${DateTime.now().millisecondsSinceEpoch}$finalExt';
    final path = 'posts/$postId/$filename';

    print('准备上传文件: $originalName, 大小: ${bytes.length} bytes, 路径: $path');

    // 上传文件字节数据
    final uploadResponse =
        await _client.storage.from(bucket).uploadBinary(path, bytes);

    print('上传响应: $uploadResponse');

    // 获取公共 URL
    final publicUrl = _client.storage.from(bucket).getPublicUrl(path);
    print('获取到的公共URL: $publicUrl');

    return publicUrl;
  }
}
