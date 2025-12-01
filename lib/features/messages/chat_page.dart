<<<<<<< HEAD
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

=======
/* //有头像班版
// lib/features/messages/chat_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
import '../../models/conversation.dart';
import '../../models/message.dart';
import '../../services/message_service.dart';
import '../../widgets/avatar_widget.dart';
import '../profile/user_profile_page.dart';
import '../profile/my_profile_page.dart';

class ChatPage extends StatefulWidget {
  final Conversation conversation;

<<<<<<< HEAD
  const ChatPage({super.key, required this.conversation});
=======
  const ChatPage({Key? key, required this.conversation}) : super(key: key);
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1

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
<<<<<<< HEAD
  RealtimeChannel? _conversationSubscription;
  late String _currentUserId;
  late bool _isConversationActive;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  void _initializeChat() {
    _currentUserId = Supabase.instance.client.auth.currentUser!.id;
    _isConversationActive = widget.conversation.isActive;

    _loadMessages();
    _subscribeToMessages();
    _subscribeToConversationStatus();
    _refreshConversationStatus();
    _markMessagesAsRead();
  }

  Future<void> _markMessagesAsRead() async {
    try {
      await _messageService.markMessagesAsRead(widget.conversation.id);
    } catch (e) {
      _showErrorSnackBar('标记消息为已读失败: $e');
    }
  }

=======
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
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _subscription?.unsubscribe();
<<<<<<< HEAD
    _conversationSubscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _refreshConversationStatus() async {
    try {
=======
    print('🗑️ 聊天页面销毁，取消订阅');
    super.dispose();
  }

  // 🔧 新增：刷新会话状态的方法
  Future<void> _refreshConversationStatus() async {
    try {
      print('🔄 [refreshConversationStatus] 刷新会话状态...');
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
      final response = await Supabase.instance.client
          .from('conversations')
          .select('status, last_message_at')
          .eq('id', widget.conversation.id)
          .single();

      final newStatus = response['status'] as String;
<<<<<<< HEAD
=======
      final lastMessageAt = response['last_message_at'];

      print('🔍 [refreshConversationStatus] 数据库中的会话状态: $newStatus');
      print('🔍 [refreshConversationStatus] 最后消息时间: $lastMessageAt');
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1

      if (mounted) {
        setState(() {
          _isConversationActive = (newStatus == 'active');
        });
<<<<<<< HEAD
      }
    } catch (e) {
      _showErrorSnackBar('刷新会话状态失败: $e');
    }
  }

  void _subscribeToConversationStatus() {
    _conversationSubscription = Supabase.instance.client
        .channel('conversation_status_${widget.conversation.id}')
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'conversations',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: widget.conversation.id,
      ),
      callback: (payload) {
        final newStatus = payload.newRecord['status'] as String?;

        if (newStatus != null && mounted) {
          setState(() {
            _isConversationActive = (newStatus == 'active');
          });
        }
      },
    ).subscribe((status, error) {
      if (error != null) {
        _showErrorSnackBar('会话状态订阅错误: $error');
      }
    });
  }

  Future<void> _loadMessages() async {
=======
        print('✅ [refreshConversationStatus] 会话状态刷新完成: $_isConversationActive');
      }
    } catch (e) {
      print('❌ [refreshConversationStatus] 刷新会话状态失败: $e');
    }
  }

  Future<void> _loadMessages() async {
    print('🔄 [loadMessages] 加载消息列表...');
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
    setState(() => _isLoading = true);

    try {
      final messages = await _messageService.fetchMessages(
        widget.conversation.id,
      );

<<<<<<< HEAD
=======
      print('✅ [loadMessages] 加载到 ${messages.length} 条消息');

>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
      setState(() {
        _messages = messages;
        _isLoading = false;
      });

<<<<<<< HEAD
      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('加载消息失败: $e');
=======
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
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
    }
  }

  void _subscribeToMessages() {
<<<<<<< HEAD
    _subscription = _messageService.subscribeToConversation(
      widget.conversation.id,
          (newMessage) {
        if (mounted) {
          final exists = _messages.any((m) => m.id == newMessage.id);
          if (!exists) {
            setState(() {
              _messages.add(newMessage);
            });

            _scrollToBottom();

            if (newMessage.senderId != _currentUserId) {
              _markMessagesAsRead();
            }
          }
=======
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
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
        }
      },
    );
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;
<<<<<<< HEAD

    if (!_isConversationActive) {
      if (!_checkChatLimit()) return;
    }

    setState(() => _isSending = true);

=======
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
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
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

<<<<<<< HEAD
      if (!_isConversationActive) {
        await _checkAndActivateConversation(sentMessage);
=======
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
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
      }

      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == -1);
<<<<<<< HEAD
          final exists = _messages.any((m) => m.id == sentMessage.id);
          if (!exists) {
            _messages.add(sentMessage);
          }
        });
      }
    } catch (e) {
=======
          _messages.add(sentMessage);
        });
      }
    } catch (e) {
      print('❌ [_sendMessage] 发送失败: $e');
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == -1);
        });
<<<<<<< HEAD
        _showErrorSnackBar('发送失败: $e');
=======
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e')),
        );
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

<<<<<<< HEAD
  bool _checkChatLimit() {
    final isInitiator = _currentUserId == widget.conversation.initiatorId;
    final validMessages = _messages.where((m) => m.id != -1).toList();

    final myCount = validMessages.where((m) => m.senderId == _currentUserId).length;
    final otherCount = validMessages.where((m) => m.senderId != _currentUserId).length;

    if (myCount >= 1 && otherCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isInitiator
                ? '已发送首条消息，等待对方回复'
                : '已回复对方，等待进一步交流',
          ),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _checkAndActivateConversation(Message sentMessage) async {
    final all = <Message>[
      ..._messages.where((m) => m.id != -1),
      sentMessage,
    ];

    final initiatorId = widget.conversation.initiatorId;
    final initiatorCount = all.where((m) => m.senderId == initiatorId).length;
    final otherCount = all.where((m) => m.senderId != initiatorId).length;

    if (initiatorCount >= 1 && otherCount >= 1) {
      await _updateConversationStatus('active');
    }
  }

=======
// 🔧 修复：同时更新数据库和本地状态（新版本 SDK）
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
  Future<void> _updateConversationStatus(String newStatus) async {
    try {
      await Supabase.instance.client
          .from('conversations')
<<<<<<< HEAD
          .update({'status': newStatus})
=======
          .update({
        'status': newStatus,
        // 'updated_at': DateTime.now().toIso8601String(),
      })
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
          .eq('id', widget.conversation.id);

      if (mounted) {
        setState(() {
          _isConversationActive = (newStatus == 'active');
        });
      }
<<<<<<< HEAD
    } catch (e) {
      _showErrorSnackBar('更新会话状态失败: $e');
=======
      print('✅ [_updateConversationStatus] 会话状态更新为: $newStatus');
    } catch (e) {
      print('❌ [_updateConversationStatus] 更新会话状态失败: $e');
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
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

<<<<<<< HEAD
=======
  // 🔧 新增：跳转到用户主页的方法
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
  void _navigateToUserProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfilePage(userId: userId),
      ),
    );
  }

<<<<<<< HEAD
=======
  // 🔧 新增：跳转到自己的个人主页（MyProfilePage）
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
  void _navigateToMyProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
<<<<<<< HEAD
        builder: (context) => MyProfilePage(),
=======
        builder: (context) => const MyProfilePage(),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
      ),
    );
  }

<<<<<<< HEAD
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

=======
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
  Widget _buildMessageBubble(Message message) {
    final isMe = message.senderId == _currentUserId;
    final isTemp = message.id == -1;
    final otherUser = widget.conversation.getOtherUser(_currentUserId);
<<<<<<< HEAD
=======
    // 🔧 新增：获取当前用户信息（用于显示自己的头像）
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
    final myUser = widget.conversation.getOtherUser(otherUser?.id ?? '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
<<<<<<< HEAD
=======
          // 🔧 新增：对方消息左侧显示可点击头像
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
          if (!isMe) ...[
            GestureDetector(
              onTap: () => _navigateToUserProfile(message.senderId),
              child: AvatarWidget(
                imageUrl: otherUser?.avatarUrl,
                size: 36,
                semanticsLabel: '${otherUser?.nickname ?? "用户"}的头像，点击查看主页',
              ),
            ),
            const SizedBox(width: 8),
          ],
<<<<<<< HEAD
=======
          
          // 消息气泡
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.55,
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
<<<<<<< HEAD
=======
          
          // 🔧 新增：自己的消息右侧显示可点击头像
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
          if (isMe) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _navigateToMyProfile(),
              child: AvatarWidget(
                imageUrl: myUser?.avatarUrl,
                size: 36,
                semanticsLabel: '我的头像，点击查看主页',
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final otherUser = widget.conversation.getOtherUser(_currentUserId);

    return Scaffold(
<<<<<<< HEAD
        backgroundColor: Colors.white,
      appBar: AppBar(
=======
      appBar: AppBar(
        // 🔧 修改：标题可点击跳转到用户主页
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
        title: GestureDetector(
          onTap: () {
            if (otherUser != null) {
              _navigateToUserProfile(otherUser.id);
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(otherUser?.nickname ?? '聊天'),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
            ],
          ),
        ),
        actions: [
<<<<<<< HEAD
=======
          // 🔧 修改：使用状态变量显示限聊模式
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
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
<<<<<<< HEAD
=======
          // 限聊提示
          // 🔧 修改：使用状态变量显示提示
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
          if (!_isConversationActive)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.orange.shade50,
              child: Text(
                _currentUserId == widget.conversation.initiatorId
<<<<<<< HEAD
                    ? '💡 您已发起会话，等待对方回复后即可自由聊天'
                    : '💡 对方已发起会话，回复首条消息后即可自由聊天',
=======
                    ? '💡 您已发起会话,等待对方回复后即可自由聊天'
                    : '💡 对方已发起会话,回复首条消息后即可自由聊天',
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
                style: const TextStyle(fontSize: 13, color: Colors.orange),
                textAlign: TextAlign.center,
              ),
            ),
<<<<<<< HEAD
=======

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
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
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
<<<<<<< HEAD
=======

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
} */

// lib/features/messages/chat_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/conversation.dart';
import '../../models/message.dart';
import '../../services/message_service.dart';
import '../../widgets/avatar_widget.dart';
import '../profile/user_profile_page.dart';
import '../profile/my_profile_page.dart';

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
  // 🔥 新增:会话状态订阅
  RealtimeChannel? _conversationSubscription;
  late String _currentUserId;

  // 🔧 新增:用于跟踪当前会话状态的变量
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
    // 🔥 新增:订阅会话状态变化
    _subscribeToConversationStatus();
    _refreshConversationStatus();
    _markMessagesAsRead(); // 🔧 新增:进入页面时标记消息为已读
  }

// 🔧 新增:标记当前会话消息为已读
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
    // 🔥 新增:取消会话状态订阅
    _conversationSubscription?.unsubscribe();
    print('🗑️ 聊天页面销毁,取消订阅');
    super.dispose();
  }

  // 🔧 新增:刷新会话状态的方法
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

  // 🔥 新增:订阅会话状态变化
  void _subscribeToConversationStatus() {
    print('🔄 [subscribeToConversationStatus] 订阅会话状态变化');

    _conversationSubscription = Supabase.instance.client
        .channel('conversation_status_${widget.conversation.id}')
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'conversations',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: widget.conversation.id,
      ),
      callback: (payload) {
        print('🔔 [subscribeToConversationStatus] 会话状态更新通知');
        final newStatus = payload.newRecord['status'] as String?;
        
        if (newStatus != null && mounted) {
          setState(() {
            _isConversationActive = (newStatus == 'active');
          });
          print('✅ [subscribeToConversationStatus] 实时更新会话状态为: $newStatus');
        }
      },
    )
        .subscribe((status, error) {
      print('📡 会话状态订阅状态: $status');
      if (error != null) {
        print('❌ 会话状态订阅错误: $error');
      }
    });
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
    print('🔄 [subscribeToMessages] 开始订阅消息,会话ID: ${widget.conversation.id}');

    _subscription = _messageService.subscribeToConversation(
      widget.conversation.id,
          (newMessage) {
        print('✅ [subscribeToMessages] 收到新消息: ${newMessage.content}');
        print('✅ 消息发送者: ${newMessage.senderId}');

        if (mounted) {
          // 🔥 优化:检查消息是否已存在,避免重复添加
          final exists = _messages.any((m) => m.id == newMessage.id);
          if (!exists) {
            setState(() {
              _messages.add(newMessage);
            });
            print('✅ 消息已添加到列表,当前消息数: ${_messages.length}');
            
            _scrollToBottom();
            
            // 🔥 新增:如果是对方发来的消息,立即标记为已读
            if (newMessage.senderId != _currentUserId) {
              _markMessagesAsRead();
            }
          } else {
            print('⚠️ 消息已存在,跳过添加');
          }
        }
      },
    );
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;
    print('🐶 NEW _sendMessage RUNNING');
    print('🔄 [_sendMessage] 准备发送消息: $content');

    // ============ 限聊逻辑开始 ============
    if (!_isConversationActive) {
      final isInitiator = _currentUserId == widget.conversation.initiatorId;

      // 只统计真正的消息(排除临时 id = -1)
      final validMessages = _messages.where((m) => m.id != -1).toList();

      // 我发了几条,对方发了几条
      final myCount =
          validMessages.where((m) => m.senderId == _currentUserId).length;
      final otherCount =
          validMessages.where((m) => m.senderId != _currentUserId).length;

      print('🔍 限聊检查: isInitiator=$isInitiator my=$myCount other=$otherCount');

      // 规则:在 pending 下,「谁」只要自己已经发过一条、对方还没回,就不能再发
      if (myCount >= 1 && otherCount == 0) {
        // 发起者:发完第一条在等人家 → 不准再骚扰
        // 接收者:理论上不会出现 otherCount==0,因为没消息就不会有这条会话
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isInitiator
                  ? '已发送首条消息,等待对方回复'
                  : '已回复对方,等待进一步交流',
            ),
          ),
        );
        print('❌ [_sendMessage] 限聊拦截:我已经发过,对方没回');
        return;
      }
    }
    // ============ 限聊逻辑结束 ============

    print('✅ [_sendMessage] 限聊检查通过,继续发送');

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

      print('✅ [_sendMessage] 发送成功,真实ID: ${sentMessage.id}');

      // 发送成功后,检查是否该激活会话
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

        print('🔍 激活检查:发起方=$initiatorCount, 对方=$otherCount');

        if (initiatorCount >= 1 && otherCount >= 1) {
          print('🔄 双方都发过,激活会话');
          await _updateConversationStatus('active');
        }
      }

      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == -1);
          // 🔥 优化:检查是否已存在,避免重复
          final exists = _messages.any((m) => m.id == sentMessage.id);
          if (!exists) {
            _messages.add(sentMessage);
          }
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

// 🔧 修复:同时更新数据库和本地状态(新版本 SDK)
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

  // 🔧 新增:跳转到用户主页的方法
  void _navigateToUserProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfilePage(userId: userId),
      ),
    );
  }

  // 🔧 新增:跳转到自己的个人主页(MyProfilePage)
  void _navigateToMyProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MyProfilePage(),
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    final isMe = message.senderId == _currentUserId;
    final isTemp = message.id == -1;
    final otherUser = widget.conversation.getOtherUser(_currentUserId);
    // 🔧 新增:获取当前用户信息(用于显示自己的头像)
    final myUser = widget.conversation.getOtherUser(otherUser?.id ?? '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔧 新增:对方消息左侧显示可点击头像
          if (!isMe) ...[
            GestureDetector(
              onTap: () => _navigateToUserProfile(message.senderId),
              child: AvatarWidget(
                imageUrl: otherUser?.avatarUrl,
                size: 36,
                semanticsLabel: '${otherUser?.nickname ?? "用户"}的头像,点击查看主页',
              ),
            ),
            const SizedBox(width: 8),
          ],
          
          // 消息气泡
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.55,
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
          
          // 🔧 新增:自己的消息右侧显示可点击头像
          if (isMe) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _navigateToMyProfile(),
              child: AvatarWidget(
                imageUrl: myUser?.avatarUrl,
                size: 36,
                semanticsLabel: '我的头像,点击查看主页',
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final otherUser = widget.conversation.getOtherUser(_currentUserId);

    return Scaffold(
      appBar: AppBar(
        // 🔧 修改:标题可点击跳转到用户主页
        title: GestureDetector(
          onTap: () {
            if (otherUser != null) {
              _navigateToUserProfile(otherUser.id);
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(otherUser?.nickname ?? '聊天'),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
            ],
          ),
        ),
        actions: [
          // 🔧 修改:使用状态变量显示限聊模式
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
          // 🔧 修改:使用状态变量显示提示
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
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
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