// lib/services/notification_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification.dart';

class NotificationService {
  final SupabaseClient _client = Supabase.instance.client;

  /// 获取通知列表
  Future<List<NotificationModel>> fetchNotifications({int limit = 50}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      print('✅ 获取到 ${response.length} 条通知');
      return (response as List)
          .map((json) => NotificationModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ 获取通知失败: $e');
      rethrow;
    }
  }

  /// 获取未读通知数量
  Future<int> fetchUnreadCount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final response = await _client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);

      final count = (response as List).length;
      print('✅ 未读通知数量: $count');
      return count;
    } catch (e) {
      print('❌ 获取未读数量失败: $e');
      return 0;
    }
  }

  /// 标记单条通知为已读
  Future<void> markAsRead(int notificationId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId)
          .eq('user_id', userId);
      
      print('✅ 标记通知为已读: $notificationId');
    } catch (e) {
      print('❌ 标记已读失败: $e');
      rethrow;
    }
  }

  /// 标记所有通知为已读
  Future<void> markAllAsRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
      
      print('✅ 全部标记为已读');
    } catch (e) {
      print('❌ 全部标记已读失败: $e');
      rethrow;
    }
  }

  /// 订阅新通知（实时）
  RealtimeChannel subscribeToNotifications(
    void Function(NotificationModel) onNewNotification,
  ) {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('未登录');

    print('🔄 订阅通知，用户ID: $userId');

    return _client
        .channel('notifications:user_id=eq.$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            print('🔔 收到实时通知: ${payload.newRecord}');
            if (payload.newRecord != null) {
              try {
                final notification = NotificationModel.fromJson(payload.newRecord!);
                print('✅ 解析通知成功: ${notification.title}');
                onNewNotification(notification);
              } catch (e) {
                print('❌ 解析通知失败: $e');
              }
            }
          },
        )
        .subscribe((status, error) {
          print('📡 通知订阅状态: $status');
          if (error != null) {
            print('❌ 通知订阅错误: $error');
          }
        });
  }
}