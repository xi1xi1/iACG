/* // lib/services/profile_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

class ProfileService {
  final SupabaseClient _client = Supabase.instance.client;

  /// 获取当前用户资料
  Future<UserProfile?> fetchMyProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      print('⚠️ 用户未登录');
      return null;
    }

    return fetchUserProfile(userId);
  }

  /// 获取指定用户资料
  Future<UserProfile?> fetchUserProfile(String userId) async {
    try {
      print('🔄 正在获取用户资料: $userId');
      
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('获取用户资料超时'),
          );

      print('✅ 用户资料获取成功');
      return UserProfile.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      print('❌ 获取用户资料失败: $e');
      return null;
    }
  }

  /// 更新个人资料
  Future<void> updateProfile({
    required String userId,
    String? nickname,
    String? avatarUrl,
    String? bio,
    String? city,
    List<String>? styleTags,
    bool? isCoser,
  }) async {
    final Map<String, dynamic> updates = {
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (nickname != null) updates['nickname'] = nickname;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (bio != null) updates['bio'] = bio;
    if (city != null) updates['city'] = city;
    if (styleTags != null) updates['style_tags'] = styleTags;
    if (isCoser != null) updates['is_coser'] = isCoser;

    await _client
        .from('profiles')
        .update(updates)
        .eq('id', userId);
  }

  /// 关注用户
  Future<void> followUser(String followingId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('未登录');

    try {
      final isAlreadyFollowing = await isFollowing(followingId);
      if (!isAlreadyFollowing) {
        await _client.from('follows').insert({
          'follower_id': userId,
          'following_id': followingId,
          'created_at': DateTime.now().toIso8601String(),
        });
        print('✅ 关注成功');
      } else {
        print('⚠️ 已经关注过了');
      }
    } catch (e) {
      print('❌ 关注失败: $e');
      rethrow;
    }
  }

  /// 取消关注
  Future<void> unfollowUser(String followingId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('未登录');

    try {
      await _client
          .from('follows')
          .delete()
          .eq('follower_id', userId)
          .eq('following_id', followingId);
      print('✅ 取消关注成功');
    } catch (e) {
      print('❌ 取消关注失败: $e');
      rethrow;
    }
  }

  /// 检查是否已关注
  Future<bool> isFollowing(String targetUserId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _client
          .from('follows')
          .select('id')
          .eq('follower_id', userId)
          .eq('following_id', targetUserId)
          .maybeSingle()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => null,
          );

      return response != null;
    } catch (e) {
      print('❌ 检查关注状态失败: $e');
      return false;
    }
  }

  /// 获取关注者列表（关注我的人）
  Future<List<UserProfile>> fetchFollowers(String userId) async {
    try {
      final response = await _client
          .from('follows')
          .select('follower:profiles!follows_follower_id_fkey(*)')
          .eq('following_id', userId);

      return (response as List)
          .map((item) => UserProfile.fromJson(item['follower'] as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ 获取关注者列表失败: $e');
      return [];
    }
  }

  /// 获取关注列表（我关注的人）
  Future<List<UserProfile>> fetchFollowing(String userId) async {
    try {
      final response = await _client
          .from('follows')
          .select('following:profiles!follows_following_id_fkey(*)')
          .eq('follower_id', userId);

      return (response as List)
          .map((item) => UserProfile.fromJson(item['following'] as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ 获取关注列表失败: $e');
      return [];
    }
  }

  /// 获取用户统计数据（帖子数、关注数、粉丝数）- 优化版
  Future<Map<String, int>> fetchUserStats(String userId) async {
    print('🔄 开始获取统计数据: $userId');
    
    try {
      // 并发查询，设置10秒超时
      final results = await Future.wait(
        [
          _fetchPostsCount(userId),
          _fetchFollowingCount(userId),
          _fetchFollowersCount(userId),
        ],
        eagerError: false, // 即使有错误也继续执行其他查询
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⚠️ 获取统计数据超时，返回默认值');
          return [0, 0, 0];
        },
      );

      final stats = {
        'posts': results[0],
        'following': results[1],
        'followers': results[2],
      };

      print('✅ 统计数据获取成功: $stats');
      return stats;
      
    } catch (e) {
      print('❌ 获取统计数据失败: $e');
      // 返回默认值，不阻塞页面加载
      return {
        'posts': 0,
        'following': 0,
        'followers': 0,
      };
    }
  }

  /// 获取帖子数（内部方法）
  Future<int> _fetchPostsCount(String userId) async {
    try {
      print('  🔄 查询帖子数...');
      final response = await _client
          .from('posts')
          .select('id')
          .eq('author_id', userId)
          .eq('is_deleted', false)
          .timeout(const Duration(seconds: 5));
      
      final count = (response as List).length;
      print('  ✅ 帖子数: $count');
      return count;
    } catch (e) {
      print('  ❌ 查询帖子数失败: $e');
      return 0;
    }
  }

  /// 获取关注数（内部方法）
  Future<int> _fetchFollowingCount(String userId) async {
    try {
      print('  🔄 查询关注数...');
      final response = await _client
          .from('follows')
          .select('id')
          .eq('follower_id', userId)
          .timeout(const Duration(seconds: 5));
      
      final count = (response as List).length;
      print('  ✅ 关注数: $count');
      return count;
    } catch (e) {
      print('  ❌ 查询关注数失败: $e');
      return 0;
    }
  }

  /// 获取粉丝数（内部方法）
  Future<int> _fetchFollowersCount(String userId) async {
    try {
      print('  🔄 查询粉丝数...');
      final response = await _client
          .from('follows')
          .select('id')
          .eq('following_id', userId)
          .timeout(const Duration(seconds: 5));
      
      final count = (response as List).length;
      print('  ✅ 粉丝数: $count');
      return count;
    } catch (e) {
      print('  ❌ 查询粉丝数失败: $e');
      return 0;
    }
  }

  /// 退出登录
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
      print('✅ 退出登录成功');
    } catch (e) {
      print('❌ 退出登录失败: $e');
      rethrow;
    }
  }
} */
// lib/services/profile_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

class ProfileService {
  final SupabaseClient _client = Supabase.instance.client;

  /// 获取当前用户资料
  Future<UserProfile?> fetchMyProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      print('⚠️ 用户未登录');
      return null;
    }

    return fetchUserProfile(userId);
  }

  /// 获取指定用户资料
  Future<UserProfile?> fetchUserProfile(String userId) async {
    try {
      print('🔄 正在获取用户资料: $userId');
      
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('获取用户资料超时'),
          );

      print('✅ 用户资料获取成功');
      return UserProfile.fromJson(Map<String, dynamic>.from(response)); // ✅ 添加类型转换
    } catch (e) {
      print('❌ 获取用户资料失败: $e');
      return null;
    }
  }

  /// 更新个人资料
  Future<void> updateProfile({
    required String userId,
    String? nickname,
    String? avatarUrl,
    String? bio,
    String? city,
    List<String>? styleTags,
    bool? isCoser,
  }) async {
    final Map<String, dynamic> updates = <String, dynamic>{ // ✅ 添加类型声明
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (nickname != null) updates['nickname'] = nickname;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (bio != null) updates['bio'] = bio;
    if (city != null) updates['city'] = city;
    if (styleTags != null) updates['style_tags'] = styleTags;
    if (isCoser != null) updates['is_coser'] = isCoser;

    await _client
        .from('profiles')
        .update(updates)
        .eq('id', userId);
  }

  /// 关注用户
  Future<void> followUser(String followingId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('未登录');

    try {
      final isAlreadyFollowing = await isFollowing(followingId);
      if (!isAlreadyFollowing) {
        await _client.from('follows').insert(<String, dynamic>{ // ✅ 添加类型
          'follower_id': userId,
          'following_id': followingId,
          'created_at': DateTime.now().toIso8601String(),
        });
        print('✅ 关注成功');
      } else {
        print('⚠️ 已经关注过了');
      }
    } catch (e) {
      print('❌ 关注失败: $e');
      rethrow;
    }
  }

  /// 取消关注
  Future<void> unfollowUser(String followingId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('未登录');

    try {
      await _client
          .from('follows')
          .delete()
          .eq('follower_id', userId)
          .eq('following_id', followingId);
      print('✅ 取消关注成功');
    } catch (e) {
      print('❌ 取消关注失败: $e');
      rethrow;
    }
  }

  /// 检查是否已关注
  Future<bool> isFollowing(String targetUserId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _client
          .from('follows')
          .select('id')
          .eq('follower_id', userId)
          .eq('following_id', targetUserId)
          .maybeSingle()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => null,
          );

      return response != null;
    } catch (e) {
      print('❌ 检查关注状态失败: $e');
      return false;
    }
  }

  /// 获取关注者列表（关注我的人）
  Future<List<UserProfile>> fetchFollowers(String userId) async {
    try {
      final response = await _client
          .from('follows')
          .select('follower:profiles!follows_follower_id_fkey(*)')
          .eq('following_id', userId);

      return (response as List)
          .map((item) => UserProfile.fromJson(Map<String, dynamic>.from(item['follower']))) // ✅ 添加类型转换
          .toList();
    } catch (e) {
      print('❌ 获取关注者列表失败: $e');
      return [];
    }
  }

  /// 获取关注列表（我关注的人）
  Future<List<UserProfile>> fetchFollowing(String userId) async {
    try {
      final response = await _client
          .from('follows')
          .select('following:profiles!follows_following_id_fkey(*)')
          .eq('follower_id', userId);

      return (response as List)
          .map((item) => UserProfile.fromJson(Map<String, dynamic>.from(item['following']))) // ✅ 添加类型转换
          .toList();
    } catch (e) {
      print('❌ 获取关注列表失败: $e');
      return [];
    }
  }

  /// 获取用户统计数据（帖子数、关注数、粉丝数）- 优化版
  Future<Map<String, int>> fetchUserStats(String userId) async {
    print('🔄 开始获取统计数据: $userId');
    
    try {
      final results = await Future.wait(
        [
          _fetchPostsCount(userId),
          _fetchFollowingCount(userId),
          _fetchFollowersCount(userId),
        ],
        eagerError: false,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⚠️ 获取统计数据超时，返回默认值');
          return [0, 0, 0];
        },
      );

      final stats = <String, int>{ // ✅ 添加类型声明
        'posts': results[0],
        'following': results[1],
        'followers': results[2],
      };

      print('✅ 统计数据获取成功: $stats');
      return stats;
      
    } catch (e) {
      print('❌ 获取统计数据失败: $e');
      return <String, int>{ // ✅ 添加类型声明
        'posts': 0,
        'following': 0,
        'followers': 0,
      };
    }
  }

  /// 获取帖子数（内部方法）
  Future<int> _fetchPostsCount(String userId) async {
    try {
      print('  🔄 查询帖子数...');
      final response = await _client
          .from('posts')
          .select('id')
          .eq('author_id', userId)
          .eq('is_deleted', false)
          .timeout(const Duration(seconds: 5));
      
      final count = (response as List).length;
      print('  ✅ 帖子数: $count');
      return count;
    } catch (e) {
      print('  ❌ 查询帖子数失败: $e');
      return 0;
    }
  }

  /// 获取关注数（内部方法）
  Future<int> _fetchFollowingCount(String userId) async {
    try {
      print('  🔄 查询关注数...');
      final response = await _client
          .from('follows')
          .select('id')
          .eq('follower_id', userId)
          .timeout(const Duration(seconds: 5));
      
      final count = (response as List).length;
      print('  ✅ 关注数: $count');
      return count;
    } catch (e) {
      print('  ❌ 查询关注数失败: $e');
      return 0;
    }
  }

  /// 获取粉丝数（内部方法）
  Future<int> _fetchFollowersCount(String userId) async {
    try {
      print('  🔄 查询粉丝数...');
      final response = await _client
          .from('follows')
          .select('id')
          .eq('following_id', userId)
          .timeout(const Duration(seconds: 5));
      
      final count = (response as List).length;
      print('  ✅ 粉丝数: $count');
      return count;
    } catch (e) {
      print('  ❌ 查询粉丝数失败: $e');
      return 0;
    }
  }

  /// 退出登录
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
      print('✅ 退出登录成功');
    } catch (e) {
      print('❌ 退出登录失败: $e');
      rethrow;
    }
  }
}