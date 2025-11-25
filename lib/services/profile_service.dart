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

/* 
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
    String? role,  // 🔧 新增：用户角色
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
    if (role != null) updates['role'] = role;  // 🔧 新增：更新角色

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
} */

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
    String? role,  // 🔧 新增:用户角色
    String? cosLevel,  // 🔧 新增:Coser 等级
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
    if (role != null) updates['role'] = role;  // 🔧 新增:更新角色
    if (cosLevel != null) updates['cos_level'] = cosLevel;  // 🔧 新增:更新等级

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

  /// 获取关注者列表(关注我的人)
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

  /// 获取关注列表(我关注的人)
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

  /// 获取用户统计数据(帖子数、关注数、粉丝数)- 优化版
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
          print('⚠️ 获取统计数据超时,返回默认值');
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

  /// 获取帖子数(内部方法)
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

  /// 获取关注数(内部方法)
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

  /// 获取粉丝数(内部方法)
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
      return UserProfile.fromJson(Map<String, dynamic>.from(response));
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
    String? role,
    String? cosLevel,
  }) async {
    final Map<String, dynamic> updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (nickname != null) updates['nickname'] = nickname;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (bio != null) updates['bio'] = bio;
    if (city != null) updates['city'] = city;
    if (styleTags != null) updates['style_tags'] = styleTags;
    if (isCoser != null) updates['is_coser'] = isCoser;
    if (role != null) updates['role'] = role;
    if (cosLevel != null) updates['cos_level'] = cosLevel;

    await _client.from('profiles').update(updates).eq('id', userId);
  }

  /// 🔥 修改：关注用户（新增回关通知功能）
  Future<void> followUser(String followingId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('未登录');

    try {
      final isAlreadyFollowing = await isFollowing(followingId);
      if (!isAlreadyFollowing) {
        // 🔥 新增：检查对方是否已经关注了我（判断是否为回关）
        final isFollowBack = await _checkIfFollowBack(followingId, userId);
        
        // 插入关注记录
        await _client.from('follows').insert(<String, dynamic>{
          'follower_id': userId,
          'following_id': followingId,
          'created_at': DateTime.now().toIso8601String(),
        });
        print('✅ 关注成功');

        // 🔥 新增：发送关注通知给被关注的人
        await _sendFollowNotification(userId, followingId, isFollowBack);
        
      } else {
        print('⚠️ 已经关注过了');
      }
    } catch (e) {
      print('❌ 关注失败: $e');
      rethrow;
    }
  }

  /// 🔥 新增：检查是否为回关（对方是否已关注我）
  Future<bool> _checkIfFollowBack(String targetUserId, String myUserId) async {
    try {
      final response = await _client
          .from('follows')
          .select('id')
          .eq('follower_id', targetUserId)
          .eq('following_id', myUserId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      print('❌ 检查回关状态失败: $e');
      return false;
    }
  }

  /// 🔥 新增：发送关注通知
  Future<void> _sendFollowNotification(String followerId, String followingId, bool isFollowBack) async {
    try {
      // 获取关注者的用户信息
      final followerProfile = await fetchUserProfile(followerId);
      final followerName = followerProfile?.nickname ?? '有人';

      // 根据是否回关，设置不同的通知内容
      String title;
      String content;
      
      if (isFollowBack) {
        // 回关通知
        title = '🎉 $followerName 回关了你';
        content = '你们已互相关注，快去打个招呼吧！';
      } else {
        // 普通关注通知
        title = '$followerName 关注了你';
        content = '你有了新粉丝，去看看Ta的主页吧！';
      }

      // 插入通知记录
      await _client.from('notifications').insert(<String, dynamic>{
        'user_id': followingId,  // 通知发送给被关注的人
        'type': 'follow',
        'title': title,
        'content': content,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      print('✅ 关注通知发送成功: isFollowBack=$isFollowBack');
    } catch (e) {
      print('❌ 发送关注通知失败: $e');
      // 通知发送失败不影响关注操作
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
          .timeout(const Duration(seconds: 5), onTimeout: () => null);

      return response != null;
    } catch (e) {
      print('❌ 检查关注状态失败: $e');
      return false;
    }
  }

  /// 🔥 新增：检查是否互相关注
  Future<bool> isMutualFollow(String targetUserId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      // 我关注了对方
      final iFollow = await isFollowing(targetUserId);
      // 对方关注了我
      final theyFollow = await _checkIfFollowBack(targetUserId, userId);

      return iFollow && theyFollow;
    } catch (e) {
      print('❌ 检查互关状态失败: $e');
      return false;
    }
  }

  /// 获取关注者列表(关注我的人)
  Future<List<UserProfile>> fetchFollowers(String userId) async {
    try {
      final response = await _client
          .from('follows')
          .select('follower:profiles!follows_follower_id_fkey(*)')
          .eq('following_id', userId);

      return (response as List)
          .map((item) => UserProfile.fromJson(Map<String, dynamic>.from(item['follower'])))
          .toList();
    } catch (e) {
      print('❌ 获取关注者列表失败: $e');
      return [];
    }
  }

  /// 获取关注列表(我关注的人)
  Future<List<UserProfile>> fetchFollowing(String userId) async {
    try {
      final response = await _client
          .from('follows')
          .select('following:profiles!follows_following_id_fkey(*)')
          .eq('follower_id', userId);

      return (response as List)
          .map((item) => UserProfile.fromJson(Map<String, dynamic>.from(item['following'])))
          .toList();
    } catch (e) {
      print('❌ 获取关注列表失败: $e');
      return [];
    }
  }

  /// 获取用户统计数据(帖子数、关注数、粉丝数)
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
          print('⚠️ 获取统计数据超时,返回默认值');
          return [0, 0, 0];
        },
      );

      final stats = <String, int>{
        'posts': results[0],
        'following': results[1],
        'followers': results[2],
      };

      print('✅ 统计数据获取成功: $stats');
      return stats;
      
    } catch (e) {
      print('❌ 获取统计数据失败: $e');
      return <String, int>{
        'posts': 0,
        'following': 0,
        'followers': 0,
      };
    }
  }

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