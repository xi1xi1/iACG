// lib/utils/chat_helper.dart
import 'package:flutter/material.dart';
import '../models/conversation.dart';
import '../services/message_service.dart';
import '../features/messages/chat_page.dart';

class ChatHelper {
  static final MessageService _messageService = MessageService();

  /// 从任意页面发起私信
  static Future<void> startChatWith({
    required BuildContext context,
    required String userId,
  }) async {
    try {
      // 显示加载
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // 获取或创建会话
      final conversation = await _messageService.getOrCreateConversation(userId);

      // 关闭加载
      if (context.mounted) {
        Navigator.pop(context);

        // 跳转到聊天页面
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(conversation: conversation),
          ),
        );
      }
    } catch (e) {
      // 关闭加载
      if (context.mounted) {
        Navigator.pop(context);
        
        // 显示错误
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开聊天失败: $e')),
        );
      }
    }
  }
}