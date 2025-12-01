import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/conversation.dart';
import '../../services/message_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/avatar_widget.dart';
import 'chat_page.dart';
import '../notifications/notification_list_page.dart';
import '../auth/login_page.dart';

class MessageListPage extends StatefulWidget {
  const MessageListPage({super.key});

  @override
  State<MessageListPage> createState() => _MessageListPageState();
}

class _MessageListPageState extends State<MessageListPage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final MessageService _messageService = MessageService();
  final NotificationService _notificationService = NotificationService();

  late TabController _tabController;

  List<Conversation> _conversations = [];
  Map<int, int> _unreadCounts = {};
  int _totalUnreadCount = 0;
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _error;

  RealtimeChannel? _messageSubscription;
  RealtimeChannel? _conversationSubscription;
  bool _hasNewMessage = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkLoginStatus();

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        if (_tabController.index == 1) {
          _loadConversations();
          setState(() => _hasNewMessage = false);
        }
      }
    });
  }

  void _checkLoginStatus() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    setState(() => _isLoggedIn = currentUser != null);

    if (_isLoggedIn) {
      _loadData();
      _subscribeToNewMessages();
      _subscribeToConversationUpdates();
      MessageService.addListener(_onMessageUnreadCountChanged);
      NotificationService.addListener(_onNotificationUnreadCountChanged);
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageSubscription?.unsubscribe();
    _conversationSubscription?.unsubscribe();
    if (_isLoggedIn) {
      MessageService.removeListener(_onMessageUnreadCountChanged);
      NotificationService.removeListener(_onNotificationUnreadCountChanged);
    }
    super.dispose();
  }

  void _onNotificationUnreadCountChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onMessageUnreadCountChanged() {
    if (mounted && _isLoggedIn) {
      _updateUnreadCounts();
      if (_tabController.index == 1) {
        _loadConversations();
      }
    }
  }

  Future<void> _updateUnreadCounts() async {
    if (!_isLoggedIn) return;

    try {
      final unreadCounts = <int, int>{};
      int totalUnread = 0;

      for (final conv in _conversations) {
        final count = await _messageService.getConversationUnreadCount(conv.id);
        unreadCounts[conv.id] = count;
        totalUnread += count;
      }

      if (mounted) {
        setState(() {
          _unreadCounts = unreadCounts;
          _totalUnreadCount = totalUnread;
        });
      }
    } catch (e) {
      print('❌ 更新未读数量失败: $e');
    }
  }

  void _subscribeToNewMessages() {
    if (!_isLoggedIn) return;

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    _messageSubscription = Supabase.instance.client
        .channel('msg_list_messages_$currentUserId')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) async {
        final senderId = payload.newRecord['sender_id'] as String?;
        if (senderId == currentUserId) return;

        if (mounted) {
          setState(() => _hasNewMessage = true);
          await _loadConversations();
        }
        _messageService.getTotalUnreadCount();
      },
    ).subscribe();
  }

  void _subscribeToConversationUpdates() {
    if (!_isLoggedIn) return;

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    _conversationSubscription = Supabase.instance.client
        .channel('msg_list_conversations_$currentUserId')
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'conversations',
      callback: (payload) async {
        if (mounted) await _loadConversations();
      },
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'conversations',
      callback: (payload) async {
        if (mounted) await _loadConversations();
      },
    ).subscribe();
  }

  Future<void> _loadData() async {
    if (!_isLoggedIn) return;

    await Future.wait([
      _loadConversations(),
      _notificationService.fetchUnreadCount(),
    ]);
  }

  Future<void> _loadConversations() async {
    if (!_isLoggedIn) return;

    if (_conversations.isEmpty) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final conversations = await _messageService.fetchConversations();

      final unreadCounts = <int, int>{};
      int totalUnread = 0;

      for (final conv in conversations) {
        final count = await _messageService.getConversationUnreadCount(conv.id);
        unreadCounts[conv.id] = count;
        totalUnread += count;
      }

      if (mounted) {
        setState(() {
          _conversations = conversations;
          _unreadCounts = unreadCounts;
          _totalUnreadCount = totalUnread;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _enterChat(Conversation conv) async {
    if (!_isLoggedIn) return;

    setState(() {
      _unreadCounts[conv.id] = 0;
      _totalUnreadCount = _unreadCounts.values.fold(0, (a, b) => a + b);
    });

    await _messageService.getTotalUnreadCount();

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatPage(conversation: conv)),
    );

    await _loadConversations();
    await _messageService.getTotalUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (!_isLoggedIn) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('消息'),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('此功能需要登录', style: TextStyle(fontSize: 16, color: Colors.black87)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消', style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (context) => const LoginPage()));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEC4899),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('去登录'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final notificationUnreadCount = NotificationService.globalUnreadCount;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '消息',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F2F3), width: 1)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFEC4899),
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: const Color(0xFFEC4899),
              unselectedLabelColor: const Color(0xFF505050),
              labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              unselectedLabelStyle: const TextStyle(fontSize: 16),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('通知'),
                      if (notificationUnreadCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEC4899),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            notificationUnreadCount > 99 ? '99+' : notificationUnreadCount.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 12, height: 1),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('私信'),
                      if (_totalUnreadCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEC4899),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _totalUnreadCount > 99 ? '99+' : _totalUnreadCount.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 12, height: 1),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const NotificationListPage(),
          _buildConversationList(),
        ],
      ),
    );
  }

  Widget _buildConversationList() {
    if (!_isLoggedIn) return _buildEmptyState('请先登录');
    if (_isLoading) return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC4899))));

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Color(0xFFEC4899)),
            const SizedBox(height: 16),
            Text('加载失败: $_error', style: const TextStyle(color: Colors.black87)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadConversations,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEC4899),
                foregroundColor: Colors.white,
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_conversations.isEmpty) {
      return _buildEmptyState('暂无私信', '从用户主页发起聊天吧');
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      backgroundColor: Colors.white,
      color: const Color(0xFFEC4899),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _conversations.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final conv = _conversations[index];
          final currentUserId = Supabase.instance.client.auth.currentUser!.id;
          final otherUser = conv.getOtherUser(currentUserId);
          final unreadCount = _unreadCounts[conv.id] ?? 0;

          if (otherUser == null) return const SizedBox.shrink();

          return _buildConversationItem(conv, otherUser, unreadCount);
        },
      ),
    );
  }

  // 修复：移除 UserProfile 类型，直接使用 dynamic 或者从 Conversation 中获取用户信息
  Widget _buildConversationItem(Conversation conv, dynamic otherUser, int unreadCount) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Stack(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: const Color(0xFFEC4899).withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: AvatarWidget(
                    imageUrl: otherUser.avatarUrl,
                    size: 52
                ),
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEC4899),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (_hasNewMessage && _isLatestConversation(conv))
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEC4899),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                otherUser.nickname ?? '用户',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              _formatTime(conv.lastMessageAt ?? DateTime.now()),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF999999),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            conv.lastMessageContent ?? '暂无消息',
            style: TextStyle(
              fontSize: 14,
              color: unreadCount > 0 ? Colors.black87 : const Color(0xFF999999),
              fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        onTap: () => _enterChat(conv),
      ),
    );
  }

  Widget _buildEmptyState(String title, [String? subtitle]) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline, size: 80, color: Color(0xFFEC4899)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _isLatestConversation(Conversation conv) {
    if (_conversations.isEmpty) return false;
    return conv.id == _conversations.first.id;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDay = DateTime(time.year, time.month, time.day);

    if (messageDay == today) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (messageDay == yesterday) {
      return '昨天';
    } else if (now.difference(time).inDays < 7) {
      return '${now.difference(time).inDays}天前';
    } else {
      return '${time.month}月${time.day}日';
    }
  }
}