<<<<<<< HEAD
=======
/* // lib/features/messages/message_list_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/conversation.dart';
import '../../models/message.dart';
import '../../services/message_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/avatar_widget.dart';
import 'chat_page.dart';
import '../notifications/notification_list_page.dart';
import '../auth/login_page.dart'; // 🔥 新增：导入登录页面

class MessageListPage extends StatefulWidget {
  const MessageListPage({Key? key}) : super(key: key);

  @override
  State<MessageListPage> createState() => _MessageListPageState();
}

class _MessageListPageState extends State<MessageListPage>
    with SingleTickerProviderStateMixin {
  final MessageService _messageService = MessageService();
  final NotificationService _notificationService = NotificationService();

  late TabController _tabController;

  List<Conversation> _conversations = [];
  Map<int, int> _unreadCounts = {};
  int _totalUnreadCount = 0;
  int _notificationUnreadCount = 0;
  bool _isLoading = true;
  bool _isLoggedIn = false; // 🔥 新增：登录状态检查
  String? _error;

  // 🔥 新增：实时订阅相关变量
  RealtimeChannel? _messageSubscription;
  bool _hasNewMessage = false; // 控制私信Tab右上角红点

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // 🔥 修改：先检查登录状态
    _checkLoginStatus();

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        if (_tabController.index == 1) {
          _loadConversations();
          // 🔥 切换到私信Tab时清除红点
          setState(() {
            _hasNewMessage = false;
          });
        } else if (_tabController.index == 0) {
          _updateNotificationUnreadCount();
        }
      }
    });
  }

  // 🔥 新增：检查登录状态
  void _checkLoginStatus() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    setState(() {
      _isLoggedIn = currentUser != null;
    });

    if (_isLoggedIn) {
      _loadData();
      _subscribeToNewMessages();
      MessageService.addListener(_onUnreadCountChanged);
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageSubscription?.unsubscribe(); // 🔥 取消订阅
    // 🔥 新增：移除全局监听（只在登录状态下）
    if (_isLoggedIn) {
      MessageService.removeListener(_onUnreadCountChanged);
    }
    super.dispose();
  }

  // 🔥 新增：全局未读消息变化回调
  void _onUnreadCountChanged() {
    if (mounted && _tabController.index == 1 && _isLoggedIn) {
      // 如果在私信Tab，立即刷新未读数量
      _updateUnreadCounts();
    }
  }

  // 🔥 新增：更新未读数量显示
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

  // 🔥 新增：订阅新消息实时推送
  void _subscribeToNewMessages() {
    if (!_isLoggedIn) return;

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    _messageSubscription = Supabase.instance.client
        .channel('new_messages_$currentUserId')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        print('🔔 收到新消息实时推送: ${payload.newRecord}');

        // 检查是否是自己发送的消息
        final senderId = payload.newRecord['sender_id'] as String?;
        if (senderId == currentUserId) return;

        // 更新状态：显示红点
        if (mounted) {
          setState(() {
            _hasNewMessage = true;
          });
        }

        // 🔥 新增：立即更新全局未读计数
        _messageService.getTotalUnreadCount();

        // 如果当前在私信Tab，刷新会话列表和未读数量
        if (_tabController.index == 1) {
          _loadConversations();
        }
      },
    )
        .subscribe();
  }

  Future<void> _loadData() async {
    if (!_isLoggedIn) return;

    await Future.wait([
      _loadConversations(),
      _loadNotificationUnreadCount(),
    ]);
  }

  Future<void> _loadConversations() async {
    if (!_isLoggedIn) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final conversations = await _messageService.fetchConversations();

      final unreadCounts = <int, int>{};
      int totalUnread = 0;

      for (final conv in conversations) {
        final count = await _messageService.getConversationUnreadCount(conv.id);
        unreadCounts[conv.id] = count;
        totalUnread += count;
      }

      setState(() {
        _conversations = conversations;
        _unreadCounts = unreadCounts;
        _totalUnreadCount = totalUnread;
        _isLoading = false;
      });

      print('✅ 加载完成: ${conversations.length} 个会话, $totalUnread 条未读消息');

    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNotificationUnreadCount() async {
    if (!_isLoggedIn) return;

    try {
      final count = await _notificationService.fetchUnreadCount();
      setState(() {
        _notificationUnreadCount = count;
      });
    } catch (e) {
      print('❌ 加载通知未读数失败: $e');
    }
  }

  void _updateNotificationUnreadCount() {
    if (!_isLoggedIn) return;
    _loadNotificationUnreadCount();
  }

  Future<void> _enterChat(Conversation conv) async {
    if (!_isLoggedIn) return;

    // 立即更新本地 UI，提供即时反馈
    setState(() {
      _unreadCounts[conv.id] = 0;
      _totalUnreadCount = _unreadCounts.values.fold(0, (a, b) => a + b);
    });

    // 🔥 新增：进入聊天前更新全局未读计数
    await _messageService.getTotalUnreadCount();

    // 进入聊天页面
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(conversation: conv),
      ),
    );

    // 返回后重新加载会话列表（确保数据同步）
    await _loadConversations();

    // 🔥 新增：返回后再次更新全局未读计数
    await _messageService.getTotalUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 新增：未登录状态显示登录提示
    if (!_isLoggedIn) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('消息'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('此功能需要登录', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context), // 取消按钮
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: () {
                      // 跳转到登录页面
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginPage()
                        ),
                      );
                    },
                    child: const Text('去登录'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('消息'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            // 通知 Tab
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('通知'),
                  if (_notificationUnreadCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _notificationUnreadCount > 99 ? '99+' : _notificationUnreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 🔥 优化：私信 Tab - 新增右上角小红点
            Tab(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('私信'),
                      if (_totalUnreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _totalUnreadCount > 99 ? '99+' : _totalUnreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  // 🔥 新增：右上角小红点（用于新消息提醒）
                  if (_hasNewMessage && _totalUnreadCount == 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _isLoggedIn ? const NotificationListPage() : const SizedBox(),
          _buildConversationList(),
        ],
      ),
    );
  }

  Widget _buildConversationList() {
    if (!_isLoggedIn) {
      return const Center(
        child: Text('请先登录'),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('加载失败: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadConversations,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_conversations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('暂无私信', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 8),
            Text(
              '从用户主页发起聊天吧',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.builder(
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          final conv = _conversations[index];
          final currentUserId = Supabase.instance.client.auth.currentUser!.id;
          final otherUser = conv.getOtherUser(currentUserId);
          final unreadCount = _unreadCounts[conv.id] ?? 0;

          if (otherUser == null) return const SizedBox.shrink();

          return ListTile(
            leading: Stack(
              children: [
                AvatarWidget(
                  imageUrl: otherUser.avatarUrl,
                  size: 44,
                ),
                // 🔥 优化：即使未读数为0，如果有新消息也显示小红点
                if (unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else if (_hasNewMessage && _isLatestConversation(conv))
                // 🔥 新增：最新消息的小红点提示
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),
            title: Row(
              children: [
                Expanded(child: Text(otherUser.nickname)),
                // 时间显示在右上角
                Text(
                  _formatTime(conv.lastMessageAt ?? DateTime.now()),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            subtitle: Text(
              // 显示最后一条消息内容，如果没有消息就显示空
              conv.lastMessageContent ?? '',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _enterChat(conv),
          );
        },
      ),
    );
  }

  // 🔥 新增：判断是否为最新消息的会话
  bool _isLatestConversation(Conversation conv) {
    if (_conversations.isEmpty) return false;

    // 假设最新消息的会话排在列表最前面
    final latestConv = _conversations.first;
    return conv.id == latestConv.id;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${time.month}月${time.day}日';
  }
} */








/* // lib/features/messages/message_list_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/conversation.dart';
import '../../models/message.dart';
import '../../services/message_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/avatar_widget.dart';
import 'chat_page.dart';
import '../notifications/notification_list_page.dart';
import '../auth/login_page.dart';

class MessageListPage extends StatefulWidget {
  const MessageListPage({Key? key}) : super(key: key);

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
  int _notificationUnreadCount = 0;
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _error;

  RealtimeChannel? _messageSubscription;
  RealtimeChannel? _conversationSubscription;
  bool _hasNewMessage = false;

  // 🔥 保持页面状态
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
          setState(() {
            _hasNewMessage = false;
          });
        } else if (_tabController.index == 0) {
          _updateNotificationUnreadCount();
        }
      }
    });
  }

  void _checkLoginStatus() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    setState(() {
      _isLoggedIn = currentUser != null;
    });

    if (_isLoggedIn) {
      _loadData();
      _subscribeToNewMessages();
      _subscribeToConversationUpdates();
      MessageService.addListener(_onUnreadCountChanged);
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageSubscription?.unsubscribe();
    _conversationSubscription?.unsubscribe();
    if (_isLoggedIn) {
      MessageService.removeListener(_onUnreadCountChanged);
    }
    super.dispose();
  }

  void _onUnreadCountChanged() {
    if (mounted && _isLoggedIn) {
      _updateUnreadCounts();
      // 🔥 强制刷新会话列表
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

  // 🔥 订阅新消息实时推送
  void _subscribeToNewMessages() {
    if (!_isLoggedIn) return;

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    print('🔔 [MessageListPage] 开始订阅新消息');

    _messageSubscription = Supabase.instance.client
        .channel('msg_list_messages_$currentUserId')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) async {
        print('🔔 [MessageListPage] 收到新消息推送: ${payload.newRecord}');

        final senderId = payload.newRecord['sender_id'] as String?;
        final conversationId = payload.newRecord['conversation_id'] as int?;

        // 忽略自己发送的消息
        if (senderId == currentUserId) return;

        // 检查这个会话是否属于当前用户
        final isMyConversation = _conversations.any((c) => c.id == conversationId);

        if (mounted) {
          setState(() {
            _hasNewMessage = true;
          });

          // 🔥 立即刷新会话列表和未读计数
          await _loadConversations();
        }

        // 更新全局未读计数
        _messageService.getTotalUnreadCount();
      },
    )
        .subscribe((status, error) {
      print('📡 [MessageListPage] 消息订阅状态: $status');
      if (error != null) {
        print('❌ [MessageListPage] 消息订阅错误: $error');
      }
    });
  }

  // 🔥 新增：订阅会话状态更新
  void _subscribeToConversationUpdates() {
    if (!_isLoggedIn) return;

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    print('🔔 [MessageListPage] 开始订阅会话状态更新');

    _conversationSubscription = Supabase.instance.client
        .channel('msg_list_conversations_$currentUserId')
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'conversations',
      callback: (payload) async {
        print('🔔 [MessageListPage] 会话状态更新: ${payload.newRecord}');

        if (mounted) {
          // 刷新会话列表
          await _loadConversations();
        }
      },
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'conversations',
      callback: (payload) async {
        print('🔔 [MessageListPage] 新会话创建: ${payload.newRecord}');

        if (mounted) {
          // 刷新会话列表
          await _loadConversations();
        }
      },
    )
        .subscribe((status, error) {
      print('📡 [MessageListPage] 会话订阅状态: $status');
      if (error != null) {
        print('❌ [MessageListPage] 会话订阅错误: $error');
      }
    });
  }

  Future<void> _loadData() async {
    if (!_isLoggedIn) return;

    await Future.wait([
      _loadConversations(),
      _loadNotificationUnreadCount(),
    ]);
  }

  Future<void> _loadConversations() async {
    if (!_isLoggedIn) return;

    // 🔥 只在首次加载时显示loading
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

      print('✅ [MessageListPage] 加载完成: ${conversations.length} 个会话, $totalUnread 条未读消息');

    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadNotificationUnreadCount() async {
    if (!_isLoggedIn) return;

    try {
      final count = await _notificationService.fetchUnreadCount();
      if (mounted) {
        setState(() {
          _notificationUnreadCount = count;
        });
      }
    } catch (e) {
      print('❌ 加载通知未读数失败: $e');
    }
  }

  void _updateNotificationUnreadCount() {
    if (!_isLoggedIn) return;
    _loadNotificationUnreadCount();
  }

  Future<void> _enterChat(Conversation conv) async {
    if (!_isLoggedIn) return;

    // 立即更新本地 UI，提供即时反馈
    setState(() {
      _unreadCounts[conv.id] = 0;
      _totalUnreadCount = _unreadCounts.values.fold(0, (a, b) => a + b);
    });

    // 进入聊天前更新全局未读计数
    await _messageService.getTotalUnreadCount();

    // 进入聊天页面
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(conversation: conv),
      ),
    );

    // 返回后重新加载会话列表（确保数据同步）
    await _loadConversations();

    // 返回后再次更新全局未读计数
    await _messageService.getTotalUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 🔥 AutomaticKeepAliveClientMixin 需要

    if (!_isLoggedIn) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('消息'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('此功能需要登录', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                      );
                    },
                    child: const Text('去登录'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('消息'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('通知'),
                  if (_notificationUnreadCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _notificationUnreadCount > 99 ? '99+' : _notificationUnreadCount.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('私信'),
                      if (_totalUnreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _totalUnreadCount > 99 ? '99+' : _totalUnreadCount.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_hasNewMessage && _totalUnreadCount == 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _isLoggedIn ? const NotificationListPage() : const SizedBox(),
          _buildConversationList(),
        ],
      ),
    );
  }

  Widget _buildConversationList() {
    if (!_isLoggedIn) {
      return const Center(child: Text('请先登录'));
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('加载失败: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadConversations,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_conversations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('暂无私信', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 8),
            Text('从用户主页发起聊天吧', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.builder(
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          final conv = _conversations[index];
          final currentUserId = Supabase.instance.client.auth.currentUser!.id;
          final otherUser = conv.getOtherUser(currentUserId);
          final unreadCount = _unreadCounts[conv.id] ?? 0;

          if (otherUser == null) return const SizedBox.shrink();

          return ListTile(
            leading: Stack(
              children: [
                AvatarWidget(imageUrl: otherUser.avatarUrl, size: 44),
                if (unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else if (_hasNewMessage && _isLatestConversation(conv))
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),
            title: Row(
              children: [
                Expanded(child: Text(otherUser.nickname)),
                Text(
                  _formatTime(conv.lastMessageAt ?? DateTime.now()),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            subtitle: Text(
              conv.lastMessageContent ?? '',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _enterChat(conv),
          );
        },
      ),
    );
  }

  bool _isLatestConversation(Conversation conv) {
    if (_conversations.isEmpty) return false;
    final latestConv = _conversations.first;
    return conv.id == latestConv.id;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${time.month}月${time.day}日';
  }
} */







// lib/features/messages/message_list_page.dart
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
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
<<<<<<< HEAD
  const MessageListPage({super.key});
=======
  const MessageListPage({Key? key}) : super(key: key);
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1

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
<<<<<<< HEAD
=======
      // 🔥 新增：监听通知未读数变化
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
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
<<<<<<< HEAD
=======
      // 🔥 新增：移除通知监听
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
      NotificationService.removeListener(_onNotificationUnreadCountChanged);
    }
    super.dispose();
  }

<<<<<<< HEAD
  void _onNotificationUnreadCountChanged() {
    if (mounted) {
      setState(() {});
=======
  // 🔥 新增：通知未读数变化回调 - 立即刷新UI
  void _onNotificationUnreadCountChanged() {
    if (mounted) {
      setState(() {});  // 触发重建，使用最新的 globalUnreadCount
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
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
<<<<<<< HEAD
      _notificationService.fetchUnreadCount(),
=======
      _notificationService.fetchUnreadCount(),  // 🔥 这会自动更新全局状态
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
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
<<<<<<< HEAD
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('消息'),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black,
        ),
=======
        appBar: AppBar(title: const Text('消息')),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
<<<<<<< HEAD
              const Text('此功能需要登录', style: TextStyle(fontSize: 16, color: Colors.black87)),
=======
              const Text('此功能需要登录', style: TextStyle(fontSize: 16)),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
<<<<<<< HEAD
                    child: const Text('取消', style: TextStyle(color: Colors.grey)),
=======
                    child: const Text('取消'),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (context) => const LoginPage()));
                    },
<<<<<<< HEAD
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEC4899),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
=======
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
                    child: const Text('去登录'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

<<<<<<< HEAD
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
=======
    // 🔥 使用全局未读通知数
    final notificationUnreadCount = NotificationService.globalUnreadCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('消息'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            // 🔥 通知 Tab - 使用全局状态
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('通知'),
                  if (notificationUnreadCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        notificationUnreadCount > 99 ? '99+' : notificationUnreadCount.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 私信 Tab
            Tab(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Row(
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('私信'),
                      if (_totalUnreadCount > 0) ...[
<<<<<<< HEAD
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEC4899),
=======
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _totalUnreadCount > 99 ? '99+' : _totalUnreadCount.toString(),
<<<<<<< HEAD
                            style: const TextStyle(color: Colors.white, fontSize: 12, height: 1),
=======
                            style: const TextStyle(color: Colors.white, fontSize: 10),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
                          ),
                        ),
                      ],
                    ],
                  ),
<<<<<<< HEAD
                ),
              ],
            ),
          ),
=======
                  if (_hasNewMessage && _totalUnreadCount == 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
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
<<<<<<< HEAD
    if (!_isLoggedIn) return _buildEmptyState('请先登录');
    if (_isLoading) return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC4899))));
=======
    if (!_isLoggedIn) return const Center(child: Text('请先登录'));
    if (_isLoading) return const Center(child: CircularProgressIndicator());
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
<<<<<<< HEAD
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
=======
            Text('加载失败: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadConversations, child: const Text('重试')),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
          ],
        ),
      );
    }

    if (_conversations.isEmpty) {
<<<<<<< HEAD
      return _buildEmptyState('暂无私信', '从用户主页发起聊天吧');
=======
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('暂无私信', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 8),
            Text('从用户主页发起聊天吧', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
<<<<<<< HEAD
      backgroundColor: Colors.white,
      color: const Color(0xFFEC4899),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _conversations.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
=======
      child: ListView.builder(
        itemCount: _conversations.length,
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
        itemBuilder: (context, index) {
          final conv = _conversations[index];
          final currentUserId = Supabase.instance.client.auth.currentUser!.id;
          final otherUser = conv.getOtherUser(currentUserId);
          final unreadCount = _unreadCounts[conv.id] ?? 0;

          if (otherUser == null) return const SizedBox.shrink();

<<<<<<< HEAD
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
=======
          return ListTile(
            leading: Stack(
              children: [
                AvatarWidget(imageUrl: otherUser.avatarUrl, size: 44),
                if (unreadCount > 0)
                  Positioned(
                    right: 0, top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else if (_hasNewMessage && _isLatestConversation(conv))
                  Positioned(
                    right: 0, top: 0,
                    child: Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
              ],
            ),
            title: Row(
              children: [
                Expanded(child: Text(otherUser.nickname)),
                Text(_formatTime(conv.lastMessageAt ?? DateTime.now()),
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            subtitle: Text(
              conv.lastMessageContent ?? '',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _enterChat(conv),
          );
        },
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
      ),
    );
  }

  bool _isLatestConversation(Conversation conv) {
    if (_conversations.isEmpty) return false;
    return conv.id == _conversations.first.id;
  }

  String _formatTime(DateTime time) {
<<<<<<< HEAD
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
=======
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${time.month}月${time.day}日';
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
  }
}