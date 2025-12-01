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

  const ChatPage({super.key, required this.conversation});

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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _subscription?.unsubscribe();
    _conversationSubscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _refreshConversationStatus() async {
    try {
      final response = await Supabase.instance.client
          .from('conversations')
          .select('status, last_message_at')
          .eq('id', widget.conversation.id)
          .single();

      final newStatus = response['status'] as String;

      if (mounted) {
        setState(() {
          _isConversationActive = (newStatus == 'active');
        });
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
    setState(() => _isLoading = true);

    try {
      final messages = await _messageService.fetchMessages(
        widget.conversation.id,
      );

      setState(() {
        _messages = messages;
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('加载消息失败: $e');
    }
  }

  void _subscribeToMessages() {
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
        }
      },
    );
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    if (!_isConversationActive) {
      if (!_checkChatLimit()) return;
    }

    setState(() => _isSending = true);

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

      if (!_isConversationActive) {
        await _checkAndActivateConversation(sentMessage);
      }

      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == -1);
          final exists = _messages.any((m) => m.id == sentMessage.id);
          if (!exists) {
            _messages.add(sentMessage);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == -1);
        });
        _showErrorSnackBar('发送失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

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

  Future<void> _updateConversationStatus(String newStatus) async {
    try {
      await Supabase.instance.client
          .from('conversations')
          .update({'status': newStatus})
          .eq('id', widget.conversation.id);

      if (mounted) {
        setState(() {
          _isConversationActive = (newStatus == 'active');
        });
      }
    } catch (e) {
      _showErrorSnackBar('更新会话状态失败: $e');
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

  void _navigateToUserProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfilePage(userId: userId),
      ),
    );
  }

  void _navigateToMyProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyProfilePage(),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Widget _buildMessageBubble(Message message) {
    final isMe = message.senderId == _currentUserId;
    final isTemp = message.id == -1;
    final otherUser = widget.conversation.getOtherUser(_currentUserId);
    final myUser = widget.conversation.getOtherUser(otherUser?.id ?? '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
        backgroundColor: Colors.white,
      appBar: AppBar(
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
          if (!_isConversationActive)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.orange.shade50,
              child: Text(
                _currentUserId == widget.conversation.initiatorId
                    ? '💡 您已发起会话，等待对方回复后即可自由聊天'
                    : '💡 对方已发起会话，回复首条消息后即可自由聊天',
                style: const TextStyle(fontSize: 13, color: Colors.orange),
                textAlign: TextAlign.center,
              ),
            ),
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