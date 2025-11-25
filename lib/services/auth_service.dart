/* /* import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';

class AuthService {
  final _client = AppSupabaseClient().client;

  // 获取当前用户ID
  String? get currentUserId => _client.auth.currentUser?.id;

  // 获取当前用户
  User? get currentUser => _client.auth.currentUser;

  // 邮箱登录
  Future<void> signInWithEmail(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user == null) {
      throw Exception('登录失败');
    }
  }

  // 邮箱注册
  Future<void> signUpWithEmail(
      String email, String password, String nickname) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    if (response.user != null) {
      // 创建用户资料
      await _client.from('profiles').insert({
        'id': response.user!.id,
        'nickname': nickname,
        'is_coser': false,
        'role': 'user',
        'cos_level': 'none',
      });
    }
  }

  // 登出
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // 检查登录状态
  bool get isLoggedIn => _client.auth.currentUser != null;
}
 */

import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';

class AuthService {
  final _client = AppSupabaseClient().client;

  // 获取当前用户ID
  String? get currentUserId => _client.auth.currentUser?.id;

  // 获取当前用户
  User? get currentUser => _client.auth.currentUser;

  // 邮箱登录
  Future<void> signInWithEmail(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user == null) {
      throw Exception('登录失败');
    }
  }

  // 邮箱注册
  Future<void> signUpWithEmail(
      String email, String password, String nickname) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    if (response.user != null) {
      // ✅ 修复: 明确指定类型为 Map<String, dynamic>
      await _client.from('profiles').insert(<String, dynamic>{
        'id': response.user!.id,
        'nickname': nickname,
        'is_coser': false,
        'role': 'user',
        'cos_level': 'none',
      });
    }
  }

  // 登出
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // 检查登录状态
  bool get isLoggedIn => _client.auth.currentUser != null;
} */
/*
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';

class AuthService {
  final _client = AppSupabaseClient().client;

  // 获取当前用户ID
  String? get currentUserId => _client.auth.currentUser?.id;

  // 获取当前用户
  User? get currentUser => _client.auth.currentUser;

  // 邮箱登录
  Future<void> signInWithEmail(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user == null) {
      throw Exception('登录失败');
    }
  }

  // 邮箱注册
  // Future<void> signUpWithEmail(
  //     String email, String password, String nickname) async {
  //   final response = await _client.auth.signUp(
  //     email: email,
  //     password: password,
  //   );

  //   if (response.user != null) {
  //     // ✅ 修复: 明确指定类型为 Map<String, dynamic>
  //     await _client.from('profiles').insert(<String, dynamic>{
  //       'id': response.user!.id,
  //       'nickname': nickname,
  //       'is_coser': false,
  //       'role': 'user',
  //       'cos_level': 'none',
  //     });
  //   }
  // }
  Future<void> signUpWithEmail(
    String email, String password, String nickname) async {
  final response = await _client.auth.signUp(
    email: email,
    password: password,
  );

  if (response.user != null) {
    // 1. 创建 profile
    await _client.from('profiles').insert(<String, dynamic>{
      'id': response.user!.id,
      'nickname': nickname,
      'is_coser': false,
      'role': 'user',
      'cos_level': 'none',
    });

    // 2. 立刻登出，避免“注册 = 已登录”
    await _client.auth.signOut();
    print('✅ [AuthService] 注册完成后已主动登出，等待用户手动登录');
  }
}

  // 登出
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // 检查登录状态
  bool get isLoggedIn => _client.auth.currentUser != null;
}*/

// lib/services/auth_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';

class AuthService {
  final _client = AppSupabaseClient().client;

  // 获取当前用户ID
  String? get currentUserId => _client.auth.currentUser?.id;

  // 获取当前用户
  User? get currentUser => _client.auth.currentUser;

  // 邮箱登录
  Future<void> signInWithEmail(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user == null) {
      throw Exception('登录失败');
    }
  }

  // 邮箱注册 —— ⭐ 注册后立刻 signOut，这样不会保持登录状态
  Future<void> signUpWithEmail(
    String email,
    String password,
    String nickname,
  ) async {
    print('📝 [注册流程] 开始注册...');

    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    // 这里 Supabase 默认已经「帮你登录」了，所以 currentUser 不为 null
    if (response.user != null) {
      try {
        // 如果 profiles 已经有这条记录，会 409
        // 可以用 upsert 防止重复冲突
        await _client.from('profiles').upsert(
          <String, dynamic>{
            'id': response.user!.id,
            'nickname': nickname,
            'is_coser': false,
            'role': 'user',
            'cos_level': 'none',
          },
          onConflict: 'id',
        );
      } catch (e) {
        print('❌ 创建或更新 profile 失败: $e');
        // 一般这里就打印一下，不用直接抛错，否则注册流程会被你自己中断
      }

      // ⭐⭐ 关键：注册完之后立刻退出登录
      await _client.auth.signOut();
      print('✅ 注册完成，已主动登出，等待用户手动登录');
    }
  }

  // 登出
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // 检查登录状态
  bool get isLoggedIn => _client.auth.currentUser != null;
}
