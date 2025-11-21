// lib/features/messages/chat_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/conversation.dart';
import '../../models/message.dart';
import '../../services/message_service.dart';

class ChatPage extends StatefulWidget {
  final Conversation conversation;

  const ChatPage({Key? key, required this.conversation}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final MessageService _messageService = MessageService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  RealtimeChannel? _subscription;
  late String _currentUserId;

  // 🔧 新增：用于跟踪当前会话状态的变量
  late bool _isConversationActive;

  // 在 _ChatPageState 类的 initState 方法中添加
  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser!.id;
    _isConversationActive = widget.conversation.isActive;

    print('🔄 [ChatPage] 初始化聊天页面');
    print('🔄 当前用户: $_currentUserId');
    print('🔄 会话ID: ${widget.conversation.id}');
    print('🔄 会话状态: ${widget.conversation.status}');
    print('🔄 会话是否激活: $_isConversationActive');
    print('🔄 发起者ID: ${widget.conversation.initiatorId}');

    _loadMessages();
    _subscribeToMessages();
    _refreshConversationStatus();
    _markMessagesAsRead(); // 🔧 新增：进入页面时标记消息为已读
  }

// 🔧 新增：标记当前会话消息为已读
  Future<void> _markMessagesAsRead() async {
    try {
      await _messageService.markMessagesAsRead(widget.conversation.id);
      print('✅ 标记当前会话消息为已读');
    } catch (e) {
      print('❌ 标记消息为已读失败: $e');
    }
  }
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _subscription?.unsubscribe();
    print('🗑️ 聊天页面销毁，取消订阅');
    super.dispose();
  }

  // 🔧 新增：刷新会话状态的方法
  Future<void> _refreshConversationStatus() async {
    try {
      print('🔄 [refreshConversationStatus] 刷新会话状态...');
      final response = await Supabase.instance.client
          .from('conversations')
          .select('status, last_message_at')
          .eq('id', widget.conversation.id)
          .single();

      final newStatus = response['status'] as String;
      final lastMessageAt = response['last_message_at'];

      print('🔍 [refreshConversationStatus] 数据库中的会话状态: $newStatus');
      print('🔍 [refreshConversationStatus] 最后消息时间: $lastMessageAt');

      if (mounted) {
        setState(() {
          _isConversationActive = (newStatus == 'active');
        });
        print('✅ [refreshConversationStatus] 会话状态刷新完成: $_isConversationActive');
      }
    } catch (e) {
      print('❌ [refreshConversationStatus] 刷新会话状态失败: $e');
    }
  }

  Future<void> _loadMessages() async {
    print('🔄 [loadMessages] 加载消息列表...');
    setState(() => _isLoading = true);

    try {
      final messages = await _messageService.fetchMessages(
        widget.conversation.id,
      );

      print('✅ [loadMessages] 加载到 ${messages.length} 条消息');

      setState(() {
        _messages = messages;
        _isLoading = false;
      });

      // 滚动到底部
      _scrollToBottom();
    } catch (e) {
      print('❌ [loadMessages] 加载消息失败: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载消息失败: $e')),
        );
      }
    }
  }

  void _subscribeToMessages() {
    print('🔄 [subscribeToMessages] 开始订阅消息，会话ID: ${widget.conversation.id}');

    _subscription = _messageService.subscribeToConversation(
      widget.conversation.id,
          (newMessage) {
        print('✅ [subscribeToMessages] 收到新消息: ${newMessage.content}');
        print('✅ 消息发送者: ${newMessage.senderId}');

        if (mounted) {
          setState(() {
            _messages.add(newMessage);
          });
          print('✅ 消息已添加到列表，当前消息数: ${_messages.length}');

          _scrollToBottom();
        }
      },
    );
  }

  // Future<void> _sendMessage() async {
  //   final content = _messageController.text.trim();
  //   if (content.isEmpty) return;

  //   print('🔄 [_sendMessage] 准备发送消息: $content');

  //   // 🔧 修改：使用状态变量而不是直接检查 conversation
  //   if (!_isConversationActive && 
  //       _currentUserId != widget.conversation.initiatorId) {
  //     print('❌ [_sendMessage] 限聊模式限制，无法发送消息');
  //     print('❌ 当前会话激活状态: $_isConversationActive');
  //     print('❌ 当前用户: $_currentUserId');
  //     print('❌ 发起者: ${widget.conversation.initiatorId}');

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('对方尚未回复,暂时无法发送消息')),
  //     );
  //     return;
  //   }

  //   print('✅ [_sendMessage] 限聊检查通过，继续发送消息');

  //   setState(() => _isSending = true);
  //   final tempMessage = Message(
  //     id: -1, // 临时ID
  //     conversationId: widget.conversation.id,
  //     senderId: _currentUserId,
  //     content: content,
  //     contentType: 'text',
  //     createdAt: DateTime.now(),
  //   );

  //   // 立即显示发送中的消息
  //   setState(() {
  //     _messages.add(tempMessage);
  //   });
  //   _messageController.clear();
  //   _scrollToBottom();

  //   try {
  //     final sentMessage = await _messageService.sendMessage(
  //       conversationId: widget.conversation.id,
  //       content: content,
  //     );

  //     print('✅ [_sendMessage] 消息发送成功，消息ID: ${sentMessage.id}');

  //     // 🔧 关键修复：检查是否需要更新会话状态
  //     if (!_isConversationActive && 
  //         _currentUserId != widget.conversation.initiatorId) {
  //       print('🔄 [_sendMessage] 首次回复，更新会话状态为 active');

  //       // 更新本地会话状态
  //       _updateConversationStatus('active');
  //     }

  //     // 替换临时消息为真实消息
  //     if (mounted) {
  //       setState(() {
  //         _messages.removeWhere((msg) => msg.id == -1);
  //         _messages.add(sentMessage);
  //       });
  //       print('✅ 消息已更新为真实消息');
  //     }

  //   } catch (e) {
  //     print('❌ [_sendMessage] 发送失败: $e');

  //     // 发送失败时移除临时消息
  //     if (mounted) {
  //       setState(() {
  //         _messages.removeWhere((msg) => msg.id == -1);
  //       });

  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('发送失败: $e')),
  //       );
  //     }
  //   } finally {
  //     if (mounted) {
  //       setState(() => _isSending = false);
  //     }
  //   }
  // }
  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;
    print('🐶 NEW _sendMessage RUNNING');
    print('🔄 [_sendMessage] 准备发送消息: $content');

    // ============ 限聊逻辑开始 ============
    if (!_isConversationActive) {
      final isInitiator = _currentUserId == widget.conversation.initiatorId;

      // 只统计真正的消息（排除临时 id = -1）
      final validMessages = _messages.where((m) => m.id != -1).toList();

      // 我发了几条，对方发了几条
      final myCount =
          validMessages.where((m) => m.senderId == _currentUserId).length;
      final otherCount =
          validMessages.where((m) => m.senderId != _currentUserId).length;

      print('🔍 限聊检查: isInitiator=$isInitiator my=$myCount other=$otherCount');

      // 规则：在 pending 下，「谁」只要自己已经发过一条、对方还没回，就不能再发
      if (myCount >= 1 && otherCount == 0) {
        // 发起者：发完第一条在等人家 → 不准再骚扰
        // 接收者：理论上不会出现 otherCount==0，因为没消息就不会有这条会话
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isInitiator
                  ? '已发送首条消息，等待对方回复'
                  : '已回复对方，等待进一步交流',
            ),
          ),
        );
        print('❌ [_sendMessage] 限聊拦截：我已经发过，对方没回');
        return;
      }
    }
    // ============ 限聊逻辑结束 ============

    print('✅ [_sendMessage] 限聊检查通过，继续发送');

    setState(() => _isSending = true);

    // 本地临时消息
    final tempMessage = Message(
      id: -1,
      conversationId: widget.conversation.id,
      senderId: _currentUserId,
      content: content,
      contentType: 'text',
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(tempMessage);
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      final sentMessage = await _messageService.sendMessage(
        conversationId: widget.conversation.id,
        content: content,
      );

      print('✅ [_sendMessage] 发送成功，真实ID: ${sentMessage.id}');

      // 发送成功后，检查是否该激活会话
      if (!_isConversationActive) {
        final all = <Message>[
          ..._messages.where((m) => m.id != -1),
          sentMessage,
        ];

        final initiatorId = widget.conversation.initiatorId;
        final initiatorCount =
            all.where((m) => m.senderId == initiatorId).length;
        final otherCount =
            all.where((m) => m.senderId != initiatorId).length;

        print('🔍 激活检查：发起方=$initiatorCount, 对方=$otherCount');

        if (initiatorCount >= 1 && otherCount >= 1) {
          print('🔄 双方都发过，激活会话');
          await _updateConversationStatus('active');
        }
      }

      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == -1);
          _messages.add(sentMessage);
        });
      }
    } catch (e) {
      print('❌ [_sendMessage] 发送失败: $e');
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == -1);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }



  // 🔧 新增：更新会话状态的方法
  // void _updateConversationStatus(String newStatus) {
  //   setState(() {
  //     _isConversationActive = (newStatus == 'active');
  //   });

  //   print('✅ [_updateConversationStatus] 会话状态更新为: $newStatus');
  //   print('✅ 当前会话激活状态: $_isConversationActive');
  // }

// 🔧 修复：同时更新数据库和本地状态（新版本 SDK）
  Future<void> _updateConversationStatus(String newStatus) async {
    try {
      await Supabase.instance.client
          .from('conversations')
          .update({
        'status': newStatus,
        // 'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', widget.conversation.id);

      if (mounted) {
        setState(() {
          _isConversationActive = (newStatus == 'active');
        });
      }
      print('✅ [_updateConversationStatus] 会话状态更新为: $newStatus');
    } catch (e) {
      print('❌ [_updateConversationStatus] 更新会话状态失败: $e');
    }
  }



  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessageBubble(Message message) {
    final isMe = message.senderId == _currentUserId;
    final isTemp = message.id == -1;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isTemp
              ? Colors.grey.shade300
              : (isMe ? Theme.of(context).primaryColor : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isTemp) ...[
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                message.content,
                style: TextStyle(
                  color: isTemp ? Colors.grey : (isMe ? Colors.white : Colors.black87),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final otherUser = widget.conversation.getOtherUser(_currentUserId);

    return Scaffold(
      appBar: AppBar(
        title: Text(otherUser?.nickname ?? '聊天'),
        actions: [
          // 🔧 修改：使用状态变量显示限聊模式
          if (!_isConversationActive)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '限聊模式',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 限聊提示
          // 🔧 修改：使用状态变量显示提示
          if (!_isConversationActive)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.orange.shade50,
              child: Text(
                _currentUserId == widget.conversation.initiatorId
                    ? '💡 您已发起会话,等待对方回复后即可自由聊天'
                    : '💡 对方已发起会话,回复首条消息后即可自由聊天',
                style: const TextStyle(fontSize: 13, color: Colors.orange),
                textAlign: TextAlign.center,
              ),
            ),

          // 调试信息
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(4),
            color: Colors.blue.shade50,
            child: Text(
              '消息数: ${_messages.length} | 会话状态: ${_isConversationActive ? "active" : "pending"} | 用户: ${_currentUserId.substring(0, 8)}',
              style: const TextStyle(fontSize: 12, color: Colors.blue),
              textAlign: TextAlign.center,
            ),
          ),

          // 消息列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('暂无消息', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),

          // 输入框
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: '输入消息...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isSending ? null : _sendMessage,
                  icon: _isSending
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}