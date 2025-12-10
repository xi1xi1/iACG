// 创建一个专门处理密码修改的服务类：services/password_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class PasswordService {
  final SupabaseClient _supabase;

  PasswordService() : _supabase = Supabase.instance.client;

  // 修改密码（需要用户已登录）
  Future<void> updatePassword(String newPassword) async {
    try {
      final response = await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (response.user == null) {
        throw Exception('密码更新失败');
      }
    } catch (e) {
      rethrow;
    }
  }

  // 发送密码重置邮件（用于忘记密码）
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'app://reset-password', // 你的应用重定向URL
      );
    } catch (e) {
      rethrow;
    }
  }

  // 验证密码强度
   bool isPasswordValid(String password) {
    return password.length >= 6;
  }
}
