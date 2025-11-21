// lib/services/message_service.dart
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/conversation.dart';
import '../models/message.dart';

class MessageService {
  final SupabaseClient _client = Supabase.instance.client;

  // 🔥 新增：全局未读消息状态
  static int _globalUnreadCount = 0;
  static final List<VoidCallback> _listeners = [];

  // 🔥 新增：获取全局未读消息数
  static int get globalUnreadCount => _globalUnreadCount;

  // 🔥 新增：添加监听器
  static void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  // 🔥 新增：移除监听器
  static void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  // 🔥 新增：更新全局未读消息数
  static void _updateGlobalUnreadCount(int count) {
    _globalUnreadCount = count;
    _notifyListeners();
  }

  // 🔥 新增：通知所有监听器
  static void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  // 🔥 新增：初始化全局未读消息状态
  Future<void> initializeGlobalUnreadCount() async {
    final count = await getTotalUnreadCount();
    _updateGlobalUnreadCount(count);
  }

  // 🔥 修改：获取所有会话的总未读消息数量 - 同时更新全局状态
  Future<int> getTotalUnreadCount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      _updateGlobalUnreadCount(0);
      return 0;
    }

    try {
      final conversations = await _client
          .from('conversations')
          .select('id')
          .or('user_a.eq.$userId,user_b.eq.$userId');

      int totalUnread = 0;
      for (final conv in conversations) {
        final convId = conv['id'] as int;
        final count = await getConversationUnreadCount(convId);
        totalUnread += count;
      }

      _updateGlobalUnreadCount(totalUnread);
      return totalUnread;
    } catch (e) {
      print('❌ 获取总未读消息数失败: $e');
      _updateGlobalUnreadCount(0);
      return 0;
    }
  }

  // 🔥 修改：标记消息为已读时更新全局状态
  Future<void> markMessagesAsRead(int conversationId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _client
          .from('messages')
          .update(<String, dynamic>{'is_read': true})
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId)
          .eq('is_read', false);

      print('✅ 标记会话 $conversationId 消息为已读');

      // 更新全局未读状态
      await getTotalUnreadCount();
    } catch (e) {
      print('❌ 标记消息为已读失败: $e');
      rethrow;
    }
  }

  // 🔥 新增：订阅全局新消息
  RealtimeChannel? _globalSubscription;

  void subscribeToGlobalMessages() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    print('🌍 开始订阅全局新消息');

    _globalSubscription = _client
        .channel('global_messages_$userId')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) async {
        final senderId = payload.newRecord['sender_id'] as String?;
        if (senderId == userId) return; // 忽略自己发送的消息

        print('🔔 收到全局新消息推送，更新未读计数');

        // 更新全局未读计数
        await getTotalUnreadCount();
      },
    )
        .subscribe((status, error) {
      print('🌍 全局订阅状态: $status');
      if (error != null) {
        print('❌ 全局订阅错误: $error');
      }
    });
  }

  void unsubscribeFromGlobalMessages() {
    _globalSubscription?.unsubscribe();
    _globalSubscription = null;
    print('🌍 取消全局消息订阅');
  }

  /// 获取或创建会话
  Future<Conversation> getOrCreateConversation(String otherUserId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('未登录');

    // 先尝试查找现有会话
    final response = await _client
        .from('conversations')
        .select('''
          *,
          user_a:profiles!conversations_user_a_fkey(*),
          user_b:profiles!conversations_user_b_fkey(*)
        ''')
        .or('and(user_a.eq.$userId,user_b.eq.$otherUserId),and(user_a.eq.$otherUserId,user_b.eq.$userId)');

    if (response != null && response.isNotEmpty) {
      return Conversation.fromJson(Map<String, dynamic>.from(response[0]));
    }

    // 创建新会话
    final newConv = await _client
        .from('conversations')
        .insert(<String, dynamic>{
      'user_a': userId,
      'user_b': otherUserId,
      'initiator_id': userId,
      'status': 'pending',
      'type': 'single',
    })
        .select('''
          *,
          user_a:profiles!conversations_user_a_fkey(*),
          user_b:profiles!conversations_user_b_fkey(*)
        ''')
        .single();

    return Conversation.fromJson(Map<String, dynamic>.from(newConv));
  }

  // 修改 fetchConversations 方法
  Future<List<Conversation>> fetchConversations() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      print('🔄 获取会话列表，当前用户: $userId');

      // 首先获取会话列表
      final response = await _client
          .from('conversations')
          .select('''
            *,
            user_a:profiles!conversations_user_a_fkey(*),
            user_b:profiles!conversations_user_b_fkey(*)
          ''')
          .or('user_a.eq.$userId,user_b.eq.$userId')
          .order('last_message_at', ascending: false);

      print('✅ 获取到 ${response.length} 个会话');

      // 为每个会话单独获取最后一条消息
      final conversations = <Conversation>[];
      for (final conv in response) {
        try {
          // 获取最后一条消息
          final lastMessageResponse = await _client
              .from('messages')
              .select('content')
              .eq('conversation_id', conv['id'])
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

          final lastMessageContent = lastMessageResponse?['content'] as String?;

          conversations.add(Conversation.fromJson({
            ...conv,
            'last_message': lastMessageContent,
          }));
        } catch (e) {
          print('❌ 获取会话 ${conv['id']} 的最后一条消息失败: $e');
          // 如果获取失败，仍然添加会话但没有最后一条消息
          conversations.add(Conversation.fromJson({
            ...conv,
            'last_message': null,
          }));
        }
      }

      return conversations;
    } catch (e) {
      print('❌ 获取会话列表失败: $e');
      rethrow;
    }
  }

  Future<List<Message>> fetchMessages(int conversationId, {int limit = 50}) async {
    final response = await _client
        .from('messages')
        .select('''
          *,
          sender:profiles!messages_sender_id_fkey(*)
        ''')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .limit(limit);

    return (response as List)
        .map((json) => Message.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  /// 获取会话的未读消息数量
  Future<int> getConversationUnreadCount(int conversationId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final response = await _client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .eq('is_read', false)
          .neq('sender_id', userId);

      return response.length;
    } catch (e) {
      print('❌ 获取未读消息数失败: $e');
      return 0;
    }
  }

  Future<Message> sendMessage({
    required int conversationId,
    required String content,
    String contentType = 'text',
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('未登录');

    print('📄 [sendMessage] 开始发送消息');
    print('📄 会话ID: $conversationId, 内容: $content, 用户: $userId');

    // 检查会话状态
    final convResponse = await _client
        .from('conversations')
        .select('status, initiator_id, user_a, user_b')
        .eq('id', conversationId)
        .single();

    print('🔍 [sendMessage] 会话原始数据: $convResponse');

    final status = convResponse['status'] as String;
    final initiatorId = convResponse['initiator_id'] as String;
    final userA = convResponse['user_a'] as String;
    final userB = convResponse['user_b'] as String;

    print('🔍 [sendMessage] 会话状态: $status, 发起者: $initiatorId, 用户A: $userA, 用户B: $userB');

    // ✅ 限聊逻辑
    if (status == 'pending') {
      final msgStats = await _client
          .from('messages')
          .select('sender_id')
          .eq('conversation_id', conversationId);

      final List data = msgStats as List;

      final myCount = data.where((m) => m['sender_id'] == userId).length;
      final otherCount = data.where((m) => m['sender_id'] != userId).length;

      final isInitiator = userId == initiatorId;

      print('🔍 [sendMessage] 限聊检查: isInitiator=$isInitiator my=$myCount other=$otherCount');

      if (isInitiator && myCount >= 1 && otherCount == 0) {
        print('❌ [sendMessage] 限聊模式限制: 发起者已发过首条消息，等待对方回复');
        throw Exception('已发送首条消息，等待对方回复');
      }
    }

    print('✅ [sendMessage] 限聊检查通过，准备发送消息');

    // 发送消息
    final message = await _client
        .from('messages')
        .insert(<String, dynamic>{
      'conversation_id': conversationId,
      'sender_id': userId,
      'content': content,
      'content_type': contentType,
      'is_read': false,
    })
        .select('''
          *,
          sender:profiles!messages_sender_id_fkey(*)
        ''')
        .single();

    print('✅ [sendMessage] 消息插入数据库成功: ${message['id']}');

    // 更新会话状态
    final updates = <String, dynamic>{
      'last_message_at': DateTime.now().toIso8601String(),
    };

    if (status == 'pending' && userId != initiatorId) {
      updates['status'] = 'active';
      print('📄 [sendMessage] 检测到首次回复，更新会话状态为 active');
    }

    print('📄 [sendMessage] 准备更新会话信息: $updates');

    try {
      final updateResult = await _client
          .from('conversations')
          .update(updates)
          .eq('id', conversationId);

      print('✅ [sendMessage] 会话信息更新完成，结果: $updateResult');

    } catch (e) {
      print('❌ [sendMessage] 更新会话信息失败: $e');
      rethrow;
    }

    return Message.fromJson(Map<String, dynamic>.from(message));
  }

  RealtimeChannel subscribeToConversation(
      int conversationId,
      void Function(Message) onNewMessage,
      ) {
    print('📄 创建实时订阅，会话ID: $conversationId');

    final channel = _client
        .channel('messages:$conversationId')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'conversation_id',
        value: conversationId,
      ),
      callback: (payload) async {
        print('🔔 收到实时通知，消息ID: ${payload.newRecord['id']}');

        try {
          final msgId = payload.newRecord['id'];
          final fullMsg = await _client
              .from('messages')
              .select('''
                    *,
                    sender:profiles!messages_sender_id_fkey(*)
                  ''')
              .eq('id', msgId)
              .single();

          final message = Message.fromJson(Map<String, dynamic>.from(fullMsg));
          print('✅ 实时消息处理完成: ${message.content}');
          onNewMessage(message);
        } catch (e) {
          print('❌ 处理实时消息失败: $e');
        }
      },
    )
        .subscribe((status, error) {
      print('📡 订阅状态: $status');
      if (error != null) {
        print('❌ 订阅错误: $error');
      }
    });

    return channel;
  }
}