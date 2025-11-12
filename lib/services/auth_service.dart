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
