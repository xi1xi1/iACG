import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';
import 'post_service.dart'; // 仅为了复用 getCategoryDbValue；也可复制那段映射进来

class TagService {
  final _client = AppSupabaseClient().client;
  final _postService = PostService(); // 只用它的映射方法；不做“查帖子”的活
  Future<List<Map<String, dynamic>>> fetchHotCosIpTags({int topN = 12}) {
    return fetchHotIpTags(topN: topN);
  }

  /// 热门 IP（近 30 天出现次数最高的标签）
  Future<List<Map<String, dynamic>>> fetchHotIpTags({int topN = 12}) async {
    final since =
        DateTime.now().subtract(const Duration(days: 30)).toIso8601String();

    final rows = await _client
        .from('post_tags')
        .select(
            'tag:tags(id, name, type), post:posts!inner(id, channel, is_deleted, status, created_at)')
        .gte('post.created_at', since)
        .eq('post.channel', 'cos')
        .eq('post.is_deleted', false)
        .eq('post.status', 'normal');

    final Map<int, Map<String, dynamic>> agg = {};
    for (final r in (rows as List)) {
      final tag = r['tag'];
      if (tag == null || tag['type'] != 'ip') continue;
      final id = tag['id'] as int;
      agg[id] ??= {'id': id, 'name': tag['name'], 'count': 0};
      agg[id]!['count'] = (agg[id]!['count'] as int) + 1;
    }
    final list = agg.values.toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return list.take(topN).toList();
  }

  /// 按“COS 类型”（动漫/游戏/漫画/小说/其他/全部）筛 IP（方案A：基于已用过的帖子动态推断）
  Future<List<Map<String, dynamic>>> fetchIpTagsByCategory({
    required String categoryZh,
    int limit = 50,
  }) async {
    final dbCategory = _postService.getCategoryDbValue(categoryZh);
    if (dbCategory == null) {
      // “全部”→ 用热门 IP 兜底
      return fetchHotIpTags(topN: limit);
    }

    final rows = await _client
        .from('tags')
        .select('''
          id, name, type,
          post_tags:post_tags!inner(
            post:posts!inner(id, channel, main_category, is_deleted, status)
          )
        ''')
        .eq('type', 'ip')
        .eq('post_tags.post.channel', 'cos')
        .eq('post_tags.post.is_deleted', false)
        .eq('post_tags.post.status', 'normal')
        .eq('post_tags.post.main_category', dbCategory)
        .limit(limit);

    // 去重
    final seen = <int>{};
    final out = <Map<String, dynamic>>[];
    for (final r in (rows as List)) {
      final id = r['id'] as int;
      if (seen.add(id)) out.add({'id': id, 'name': r['name']});
    }
    return out;
  }

  /// 关键词搜标签（给“搜索页 / 标签Tab”用）
  Future<List<Map<String, dynamic>>> searchTags(String keyword,
      {int limit = 50}) async {
    if (keyword.trim().isEmpty) return [];
    final rows = await _client
        .from('tags')
        .select('id, name, type')
        .ilike('name', '%$keyword%')
        .eq('is_active', true)
        .limit(limit);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// 创建自定义标签（遵守你们的 RLS：created_by 必须等于 auth.uid()）
  /* Future<int> createCustomTag({
    required String name,
    required String type, // 'ip' | 'style' | 'theme' | 'user' | 'system'
  }) async {
    final inserted = await _client
        .from('tags')
        .insert({
          'name': name,
          'type': type,
          // created_by 由 RLS 检查为 auth.uid()，这里无需显式传
        })
        .select('id')
        .single();
    return inserted['id'] as int;
  } */

  Future<int> createCustomTag({
    required String name,
    required String type,
  }) async {
    final inserted = await _client
        .from('tags')
        .insert(<String, dynamic>{
          // ✅ 添加类型
          'name': name,
          'type': type,
        })
        .select('id')
        .single();
    return inserted['id'] as int;
  }

  /// 确保标签存在并返回标签ID列表
  /* Future<List<int>> ensureTagsAndReturnIds(List<String> tagNames) async {
    if (tagNames.isEmpty) return [];

    final List<int> tagIds = [];

    for (final name in tagNames) {
      try {
        // 1. 先检查标签是否已存在
        final existingTag = await _client
            .from('tags')
            .select('id')
            .eq('name', name)
            .maybeSingle();

        if (existingTag != null) {
          // 标签已存在，使用现有ID
          tagIds.add(existingTag['id'] as int);
        } else {
          // 2. 标签不存在，创建新标签（类型设为 'user'）
          final newTag = await _client
              .from('tags')
              .insert({
                'name': name,
                'type': 'user', // 用户自定义标签
              })
              .select('id')
              .single();

          tagIds.add(newTag['id'] as int);
          print('创建新标签: $name (ID: ${newTag['id']})');
        }
      } catch (e) {
        print('处理标签 "$name" 时出错: $e');
        // 继续处理其他标签，不中断整个流程
      }
    }

    return tagIds;
  } */

Future<List<int>> ensureTagsAndReturnIds(
  List<String> tagNames, 
  {String type = 'user'}
) async {
  if (tagNames.isEmpty) return [];

  final List<int> tagIds = [];

  for (final name in tagNames) {
    try {
      // 1. 先检查标签是否已存在
      final existingTag = await _client
          .from('tags')
          .select('id, type')
          .eq('name', name.trim())
          .maybeSingle();

      if (existingTag != null) {
        final existingId = existingTag['id'] as int;
        final existingType = existingTag['type'] as String?;
        
        print('📊 标签存在检查: "$name" - ID: $existingId, 当前类型: ${existingType ?? "null"}');
        
        // ✅ 关键修改：只有原类型是 'user'，且新类型不是 'user'，才更新
        if (type != 'user' && existingType == 'user') {
          print('🔧 符合条件：原类型是user，新类型是$type，执行更新');
          try {
            // ✅ 重要：只更新 type 字段，不要包含不存在的字段
            await _client
                .from('tags')
                .update({'type': type}) // ✅ 只更新type字段
                .eq('id', existingId)
                .eq('type', 'user');
            
            print('✅ 标签类型更新已提交: "$name" (user → $type)');
            
            // 重新查询确认更新结果
            final verifyResult = await _client
                .from('tags')
                .select('type')
                .eq('id', existingId)
                .single();
            
            final verifiedType = verifyResult['type'] as String?;
            print('🔍 验证更新结果: 类型 = $verifiedType');
          } catch (e) {
            print('❌ 标签类型更新失败: $e');
            print('错误详情: ${e.toString()}');
          }
        } else if (type != 'user' && existingType != 'user') {
          print('📝 标签类型不是user，保持原类型: $existingType');
        } else if (type == 'user') {
          print('📝 目标类型是user，不更新现有标签');
        }
        
        tagIds.add(existingId);
        print('✅ 标签最终: "$name" (ID: $existingId)');
      } else {
        // 标签不存在，创建新标签
        final newTag = await _client
            .from('tags')
            .insert(<String, dynamic>{
              'name': name.trim(),
              'type': type,
              'created_at': DateTime.now().toIso8601String(),
              'is_active': true,
            })
            .select('id, type')
            .single();

        final newId = newTag['id'] as int;
        final newTagType = newTag['type'] as String?;
        tagIds.add(newId);
        print('✅ 创建新标签: $name (ID: $newId, 类型: ${newTagType ?? type})');
      }
    } catch (e) {
      print('❌ 处理标签 "$name" 时出错: $e');
      print('错误详情: ${e.toString()}');
    }
  }

  return tagIds;
}

  /// 批量获取标签信息
  Future<List<Map<String, dynamic>>> getTagsByIds(List<int> tagIds) async {
    if (tagIds.isEmpty) return [];

    final result = await _client
        .from('tags')
        .select('id, name, type')
        .inFilter('id', tagIds);

    return (result as List).cast<Map<String, dynamic>>();
  }

  /// 根据帖子ID获取标签
  Future<List<Map<String, dynamic>>> getTagsByPostId(int postId) async {
    final result = await _client.from('post_tags').select('''
          tag:tags(id, name, type)
        ''').eq('post_id', postId);

    return (result as List).cast<Map<String, dynamic>>();
  }

  // 1) 标签详情（基础信息）
  Future<Map<String, dynamic>?> fetchTagDetail(int tagId) async {
    final row = await _client
        .from('tags')
        .select('id, name, type, is_active, created_at')
        .eq('id', tagId)
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  // 2) 标签下的帖子（支持频道过滤 & 分页 & 可见性条件）
  // 注意：避免把 select(...) 存变量后再 eq(...)，用 if/else 两条完整链
  Future<List<Map<String, dynamic>>> fetchTagPosts({
    required int tagId,
    String? channel, // 'cos' | 'island' | null=全部
    int limit = 20,
    int offset = 0,
  }) async {
    const selColumns = '''
      posts!inner(
        id, author_id, channel, title, content, main_category, main_ip_tag_id,
        like_count, favorite_count, comment_count, view_count, created_at,
        is_deleted, status
      )
    ''';

    List rows;

    if (channel == null) {
      rows = await _client
          .from('post_tags')
          .select(selColumns)
          .eq('tag_id', tagId)
          .eq('posts.is_deleted', false)
          .eq('posts.status', 'normal')
          .order('posts.created_at', ascending: false)
          .range(offset, offset + limit - 1);
    } else {
      rows = await _client
          .from('post_tags')
          .select(selColumns)
          .eq('tag_id', tagId)
          .eq('posts.channel', channel)
          .eq('posts.is_deleted', false)
          .eq('posts.status', 'normal')
          .order('posts.created_at', ascending: false)
          .range(offset, offset + limit - 1);
    }

    // postgrest 返回的是 post_tags 行，里面嵌了 posts
    return rows
        .map((r) =>
            Map<String, dynamic>.from(r['posts'] as Map<String, dynamic>))
        .toList()
        // 保险再过滤一次（万一后端数据里混入了删除/非 normal）
        .where((p) => p['is_deleted'] == false && p['status'] == 'normal')
        .toList();
  }

  // 3) 相关标签（共现：与目标标签出现在同一批帖子里的其他标签，按共现次数排）
  Future<List<Map<String, dynamic>>> fetchRelatedTags(int tagId,
      {int limit = 12}) async {
    // 先取该标签对应的 post_id 列表
    final List pt =
        await _client.from('post_tags').select('post_id').eq('tag_id', tagId);

    final postIds = pt.map((e) => e['post_id'] as int).toList();
    if (postIds.isEmpty) return [];

    // 再取这些帖子上的所有其他标签
    final List all = await _client
        .from('post_tags')
        .select('tag:tags(id, name, type), post_id')
        .inFilter('post_id', postIds);

    // 统计除自身外的标签出现次数
    final Map<int, Map<String, dynamic>> agg = {};
    for (final r in all) {
      final tag = r['tag'] as Map<String, dynamic>?;
      if (tag == null) continue;
      final id = tag['id'] as int;
      if (id == tagId) continue;
      final name = tag['name'];
      final type = tag['type'];
      final bucket =
          (agg[id] ?? {'id': id, 'name': name, 'type': type, 'count': 0});
      bucket['count'] = (bucket['count'] as int) + 1;
      agg[id] = bucket;
    }

    final list = agg.values.toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return list.take(limit).toList();
  }

  // 用 RPC 计数的最终版
  Future<int> countTagPosts({required int tagId, String? channel}) async {
    // 直接调用你在 DB 里创建的函数 public.count_posts_by_tag(int, text)
    final res = await _client.rpc('count_posts_by_tag', params: {
      'p_tag_id': tagId, // 必填
      'p_channel': channel, // 传 null 表示“全部频道”
    });

    // 兼容不同 SDK 的返回类型（int / num / String）
    if (res == null) return 0;
    if (res is int) return res;
    if (res is num) return res.toInt();
    return int.tryParse(res.toString()) ?? 0;
  }
}
