/* 
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../core/supabase_client.dart';

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
        debugPrint('请求分类: $category, IP标签: $ipTag, limit=$limit, offset=$offset');
      }

      final needIpFilter = ipTag != null && ipTag.isNotEmpty && ipTag != '全部';

      // 根据是否需要按 IP 过滤，选择 inner / left 连接
      final select = '''
        id, channel, title, content, main_category, created_at,
        like_count, favorite_count, comment_count, view_count, author_id,
        author:profiles!posts_author_id_fkey(id, nickname, avatar_url, is_coser),
        post_media(media_url, media_type, sort_order),
        ${needIpFilter
            ? "post_tags!inner(tag:tags!inner(id, name, type))"
            : "post_tags(tag:tags(id, name, type))"}
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
            comment_count, view_count, author_id,
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

  /// 按标签名聚合帖子（COS + 群岛），支持分页 & 排序（latest/hot）
  Future<List<Map<String, dynamic>>> fetchPostsByTag(
    String tagName, {
    int limit = 30,
    int offset = 0,
    String orderBy = 'latest', // 'latest' | 'hot'
  }) async {
    // 说明：
    // - latest：按 created_at desc
    // - hot  ：简单用 like_count desc, comment_count desc, view_count desc, created_at desc 作“热度”排序
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
          ..sort((a, b) => (a['sort_order'] ?? 0).compareTo(b['sort_order'] ?? 0));
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
          ..sort((a, b) => (a['sort_order'] ?? 0).compareTo(b['sort_order'] ?? 0));
        p['post_media'] = media;
      }
      return (resp as List).cast<Map<String, dynamic>>();
    }
  }

  // /// 帖子详情（作者 + 媒体 + 标签），不区分 COS/群岛
  // Future<Map<String, dynamic>?> getPostDetail(int postId) async {
  //   final res = await _client
  //       .from('posts')
  //       .select('''
  //         id, channel, title, content, main_category, island_type,
  //         like_count, favorite_count, comment_count, view_count,
  //         created_at, author_id,
  //         author:profiles!posts_author_id_fkey(id, nickname, avatar_url, is_coser),
  //         post_media(id, media_url, media_type, sort_order),
  //         post_tags(tag:tags(id, name, type))
  //       ''')
  //       .eq('id', postId)
  //       .eq('is_deleted', false)
  //       .eq('status', 'normal')
  //       // 让媒体按 sort_order 正序
  //       .order('sort_order', ascending: true, referencedTable: 'post_media')
  //       .maybeSingle();

  //   if (res == null) return null;
  //   return res as Map<String, dynamic>;
  // }
  /// 帖子详情（作者 + 媒体 + 标签 + 协作者），不区分 COS/群岛
  Future<Map<String, dynamic>?> getPostDetail(int postId) async {
    final res = await _client
        .from('posts')
        .select('''
          id, channel, title, content, main_category, island_type,
          like_count, favorite_count, comment_count, view_count,
          created_at, author_id,
          author:profiles!posts_author_id_fkey(id, nickname, avatar_url, is_coser),
          post_media(id, media_url, media_type, sort_order),
          post_tags(tag:tags(id, name, type)),
          collaborators:post_collaborators(
            id, role, display_name, user_id,
            user:profiles(id, nickname, avatar_url)
          )
        ''')
        .eq('id', postId)
        .eq('is_deleted', false)
        .eq('status', 'normal')
        // 媒体按 sort_order 正序
        .order('sort_order', ascending: true, referencedTable: 'post_media')
        // 协作者按 id 正序（也可 .order('role', referencedTable: 'post_collaborators')）
        .order('id', ascending: true, referencedTable: 'post_collaborators')
        .maybeSingle();

    if (res == null) return null;
    return res as Map<String, dynamic>;
  }


  // —— 互动动作：点赞/收藏/评论 —— //

  Future<void> likePost(int postId, String userId) async {
    // 唯一约束 (post_id, user_id) 已在表上，重复会被忽略/报错；这里用 upsert 更稳妥
    await _client.from('post_likes').upsert(
      {'post_id': postId, 'user_id': userId},
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
      {'post_id': postId, 'user_id': userId},
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
    await _client.from('post_comments').insert({
      'post_id': postId,
      'user_id': userId,
      'content': text,
      if (parentId != null) 'parent_id': parentId,
    });
  }

  /// 发布帖子（COS/群岛通用）
  Future<int> createPost({
    required String authorId,
    required String channel, // 'cos' | 'island'
    required String title,
    String? content,
    String? mainCategory, // cos 用
    int? mainIpTagId, // 主IP，可空
    String? islandType, // island 用
    String visibility = 'public',
  }) async {
    final inserted = await _client
        .from('posts')
        .insert({
          'author_id': authorId,
          'channel': channel,
          'title': title,
          'content': content,
          if (channel == 'cos' && mainCategory != null)
            'main_category': mainCategory,
          if (mainIpTagId != null) 'main_ip_tag_id': mainIpTagId,
          if (channel == 'island' && islandType != null)
            'island_type': islandType,
          'visibility': visibility,
        })
        .select('id')
        .single();

    return inserted['id'] as int;
  }

  /// 绑定媒体（传入：[{media_url, media_type, sort_order}, ...]）
  Future<void> attachMedia(int postId, List<Map<String, String>> medias) async {
    if (medias.isEmpty) return;
    await _client.from('post_media').insert(medias.map((m) {
      return {
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
      tagIds.map((id) => {'post_id': postId, 'tag_id': id}).toList(),
      onConflict: 'post_id,tag_id',
      ignoreDuplicates: true,
    );
  }

  // 只对“已登录用户”增加浏览量（推荐：走 RPC，绕过 RLS 的作者限制）
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
  
  // /// 按标签名聚合帖子（COS + 群岛），支持分页
  // Future<List<Map<String, dynamic>>> fetchPostsByTag(
  //   String tagName, {
  //   int limit = 30,
  //   int offset = 0,
  // }) async {
  //   final res = await _client
  //       .from('posts')
  //       .select('''
  //         id, channel, title, content, main_category, island_type, created_at,
  //         like_count, favorite_count, comment_count, view_count, author_id,
  //         author:profiles!posts_author_id_fkey(id, nickname, avatar_url, is_coser),
  //         post_media(media_url, media_type, sort_order),
  //         post_tags!inner(tag:tags!inner(id, name, type))
  //       ''')
  //       .eq('is_deleted', false)
  //       .eq('status', 'normal')
  //       .eq('post_tags.tag.name', tagName)     // 只返回带这个标签的帖子
  //       .order('created_at', ascending: false)
  //       .range(offset, offset + limit - 1);

  //   // 把媒体按 sort_order 排好（避免在 select 里用复杂的嵌套 order 语法）
  //   for (final p in (res as List)) {
  //     final media = (p['post_media'] as List? ?? [])
  //       ..sort((a, b) => (a['sort_order'] ?? 0).compareTo(b['sort_order'] ?? 0));
  //     p['post_media'] = media;
  //   }
  //   return (res as List).cast<Map<String, dynamic>>();
  // }

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

  // 点赞切换：返回 “现在是否已点赞”
  Future<bool> toggleLike(int postId, String userId) async {
    if (await hasLiked(postId, userId)) {
      await _client.from('post_likes').delete().match({
        'post_id': postId,
        'user_id': userId,
      });
      return false;
    } else {
      // 唯一约束已存在，重复插入会报错；正常情况下不会触发
      await _client.from('post_likes').insert({
        'post_id': postId,
        'user_id': userId,
      });
      return true;
    }
  }

  // 收藏切换：返回 “现在是否已收藏”
  Future<bool> toggleFavorite(int postId, String userId) async {
    if (await hasFavorited(postId, userId)) {
      await _client.from('post_favorites').delete().match({
        'post_id': postId,
        'user_id': userId,
      });
      return false;
    } else {
      await _client.from('post_favorites').insert({
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
      await _client.from('comment_likes').insert({
        'comment_id': commentId,
        'user_id': userId,
      });
      return true;
    }
  }

  /// 批量查询我点过赞的评论ID集合（用于首屏标记红心）
  Future<Set<int>> myLikedCommentIds(List<int> commentIds, String userId) async {
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

  // ✅ 拉某一楼的“楼中楼”两层：L1=直接回一楼；L2=回 L1
  // 返回 {root, l1, l2} 三段，前端做 "A 回复 B" 的拼接
  Future<Map<String, dynamic>> fetchThread2Levels(int rootId) async {
    // 取一楼
    final root = await _client
        .from('post_comments')
        .select('''
          id, content, created_at, like_count, user_id, parent_id,
          user:profiles!post_comments_user_id_fkey(id, nickname, avatar_url)
        ''')
        .eq('id', rootId)
        .maybeSingle();

    if (root == null) {
      return {'root': null, 'l1': const <Map<String, dynamic>>[], 'l2': const <Map<String, dynamic>>[]};
    }

    // 取 L1：parent_id = rootId
    final l1 = await _client
        .from('post_comments')
        .select('''
          id, content, created_at, like_count, user_id, parent_id,
          user:profiles!post_comments_user_id_fkey(id, nickname, avatar_url)
        ''')
        .eq('parent_id', rootId)
        .order('created_at', ascending: true);

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

  /// 楼内直接回复列表（B站风格的“楼中楼”第二层）
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
      {'comment_id': commentId, 'user_id': userId},
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

  /// 拉某一楼的“整楼”扁平列表（主楼 + 全部子孙）
  /// 返回：Map { root: Map?, replies: List<Map> }
  Future<Map<String, dynamic>> fetchThreadFlat(int rootId) async {
    final rows = await _client
        .rpc('get_comment_thread', params: {'p_root_id': rootId});

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

  /// 批量查：我在这“整楼”里点过赞的评论 id 集合
  Future<Set<int>> myLikedInThread(List<int> commentIds, String userId) async {
    if (commentIds.isEmpty) return <int>{};
    final rows = await _client
        .from('comment_likes')
        .select('comment_id')
        .eq('user_id', userId)
        .inFilter('comment_id', commentIds);
    return rows.map<int>((r) => r['comment_id'] as int).toSet();
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
    final uploadResponse = await _client.storage
        .from(bucket)
        .uploadBinary(path, bytes);

    print('上传响应: $uploadResponse');

    // 获取公共 URL
    final publicUrl = _client.storage.from(bucket).getPublicUrl(path);
    print('获取到的公共URL: $publicUrl');

    return publicUrl;
  }

  Future<int> createPost({
    required String authorId,
    required String channel,
    required String title,
    String? content,
    String? mainCategory,
    int? mainIpTagId, // 新增：主IP标签ID
    String? islandType,
    String visibility = 'public',
  }) async {
    final inserted = await _client
        .from('posts')
        .insert({
          'author_id': authorId,
          'channel': channel,
          'title': title,
          'content': content,
          if (channel == 'cos' && mainCategory != null)
            'main_category': mainCategory,
          if (mainIpTagId != null) 'main_ip_tag_id': mainIpTagId, // 新增
          if (channel == 'island' && islandType != null)
            'island_type': islandType,
          'visibility': visibility,
        })
        .select('id')
        .single();

    return inserted['id'] as int;
  }
}

 */


import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../core/supabase_client.dart';

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
        debugPrint('请求分类: $category, IP标签: $ipTag, limit=$limit, offset=$offset');
      }

      final needIpFilter = ipTag != null && ipTag.isNotEmpty && ipTag != '全部';

      // 根据是否需要按 IP 过滤，选择 inner / left 连接
      final select = '''
        id, channel, title, content, main_category, created_at,
        like_count, favorite_count, comment_count, view_count, author_id,
        author:profiles!posts_author_id_fkey(id, nickname, avatar_url, is_coser),
        post_media(media_url, media_type, sort_order),
        ${needIpFilter
            ? "post_tags!inner(tag:tags!inner(id, name, type))"
            : "post_tags(tag:tags(id, name, type))"}
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
            comment_count, view_count, author_id,
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

  /// 按标签名聚合帖子（COS + 群岛），支持分页 & 排序（latest/hot）
  Future<List<Map<String, dynamic>>> fetchPostsByTag(
    String tagName, {
    int limit = 30,
    int offset = 0,
    String orderBy = 'latest', // 'latest' | 'hot'
  }) async {
    // 说明：
    // - latest：按 created_at desc
    // - hot  ：简单用 like_count desc, comment_count desc, view_count desc, created_at desc 作“热度”排序
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
          ..sort((a, b) => (a['sort_order'] ?? 0).compareTo(b['sort_order'] ?? 0));
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
          ..sort((a, b) => (a['sort_order'] ?? 0).compareTo(b['sort_order'] ?? 0));
        p['post_media'] = media;
      }
      return (resp as List).cast<Map<String, dynamic>>();
    }
  }

  /// 帖子详情（作者 + 媒体 + 标签 + 协作者），不区分 COS/群岛
  Future<Map<String, dynamic>?> getPostDetail(int postId) async {
    final res = await _client
        .from('posts')
        .select('''
          id, channel, title, content, main_category, island_type,
          like_count, favorite_count, comment_count, view_count,
          created_at, author_id,
          author:profiles!posts_author_id_fkey(id, nickname, avatar_url, is_coser),
          post_media(id, media_url, media_type, sort_order),
          post_tags(tag:tags(id, name, type)),
          collaborators:post_collaborators(
            id, role, display_name, user_id,
            user:profiles(id, nickname, avatar_url)
          )
        ''')
        .eq('id', postId)
        .eq('is_deleted', false)
        .eq('status', 'normal')
        // 媒体按 sort_order 正序
        .order('sort_order', ascending: true, referencedTable: 'post_media')
        // 协作者按 id 正序（也可 .order('role', referencedTable: 'post_collaborators')）
        .order('id', ascending: true, referencedTable: 'post_collaborators')
        .maybeSingle();

    if (res == null) return null;
    return res as Map<String, dynamic>;
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

  /// 发布帖子（COS/群岛通用）
  Future<int> createPost({
    required String authorId,
    required String channel, // 'cos' | 'island'
    required String title,
    String? content,
    String? mainCategory, // cos 用
    int? mainIpTagId, // 主IP，可空
    String? islandType, // island 用
    String visibility = 'public',
  }) async {
    final inserted = await _client
        .from('posts')
        .insert(<String, dynamic>{
          'author_id': authorId,
          'channel': channel,
          'title': title,
          'content': content,
          if (channel == 'cos' && mainCategory != null)
            'main_category': mainCategory,
          if (mainIpTagId != null) 'main_ip_tag_id': mainIpTagId,
          if (channel == 'island' && islandType != null)
            'island_type': islandType,
          'visibility': visibility,
        })
        .select('id')
        .single();

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
      tagIds.map((id) => <String, dynamic>{'post_id': postId, 'tag_id': id}).toList(),
      onConflict: 'post_id,tag_id',
      ignoreDuplicates: true,
    );
  }

  // 只对“已登录用户”增加浏览量（推荐：走 RPC，绕过 RLS 的作者限制）
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

  // 点赞切换：返回 “现在是否已点赞”
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

  // 收藏切换：返回 “现在是否已收藏”
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
  Future<Set<int>> myLikedCommentIds(List<int> commentIds, String userId) async {
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

  // ✅ 拉某一楼的“楼中楼”两层：L1=直接回一楼；L2=回 L1
  // 返回 {root, l1, l2} 三段，前端做 "A 回复 B" 的拼接
  Future<Map<String, dynamic>> fetchThread2Levels(int rootId) async {
    // 取一楼
    final root = await _client
        .from('post_comments')
        .select('''
          id, content, created_at, like_count, user_id, parent_id,
          user:profiles!post_comments_user_id_fkey(id, nickname, avatar_url)
        ''')
        .eq('id', rootId)
        .maybeSingle();

    if (root == null) {
      return {'root': null, 'l1': const <Map<String, dynamic>>[], 'l2': const <Map<String, dynamic>>[]};
    }

    // 取 L1：parent_id = rootId
    final l1 = await _client
        .from('post_comments')
        .select('''
          id, content, created_at, like_count, user_id, parent_id,
          user:profiles!post_comments_user_id_fkey(id, nickname, avatar_url)
        ''')
        .eq('parent_id', rootId)
        .order('created_at', ascending: true);

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

  /// 楼内直接回复列表（B站风格的“楼中楼”第二层）
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

  /// 拉某一楼的“整楼”扁平列表（主楼 + 全部子孙）
  /// 返回：Map { root: Map?, replies: List<Map> }
  Future<Map<String, dynamic>> fetchThreadFlat(int rootId) async {
    final rows = await _client
        .rpc('get_comment_thread', params: {'p_root_id': rootId});

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

  /// 批量查：我在这“整楼”里点过赞的评论 id 集合
  Future<Set<int>> myLikedInThread(List<int> commentIds, String userId) async {
    if (commentIds.isEmpty) return <int>{};
    final rows = await _client
        .from('comment_likes')
        .select('comment_id')
        .eq('user_id', userId)
        .inFilter('comment_id', commentIds);
    return rows.map<int>((r) => r['comment_id'] as int).toSet();
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
    final uploadResponse = await _client.storage
        .from(bucket)
        .uploadBinary(path, bytes);

    print('上传响应: $uploadResponse');

    // 获取公共 URL
    final publicUrl = _client.storage.from(bucket).getPublicUrl(path);
    print('获取到的公共URL: $publicUrl');

    return publicUrl;
  }

  Future<int> createPost({
    required String authorId,
    required String channel,
    required String title,
    String? content,
    String? mainCategory,
    int? mainIpTagId, // 新增：主IP标签ID
    String? islandType,
    String visibility = 'public',
  }) async {
    final inserted = await _client
        .from('posts')
        .insert(<String, dynamic>{
          'author_id': authorId,
          'channel': channel,
          'title': title,
          'content': content,
          if (channel == 'cos' && mainCategory != null)
            'main_category': mainCategory,
          if (mainIpTagId != null) 'main_ip_tag_id': mainIpTagId, // 新增
          if (channel == 'island' && islandType != null)
            'island_type': islandType,
          'visibility': visibility,
        })
        .select('id')
        .single();

    return inserted['id'] as int;
  }
}