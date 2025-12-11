

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/notification.dart';
import '../../services/message_service.dart';
import '../../services/notification_service.dart';
import '../../services/post_service.dart';
import '../../services/profile_service.dart';
import '../../widgets/avatar_widget.dart';
import '../messages/chat_page.dart';
import '../post/post_detail_page.dart';
import '../profile/user_profile_page.dart';
import 'notification_category_page.dart'; // 🔥 新增：导入分类页面

class NotificationListPage extends StatefulWidget {
  const NotificationListPage({super.key});

  @override
  State<NotificationListPage> createState() => _NotificationListPageState();
}

class _NotificationListPageState extends State<NotificationListPage> {
  final NotificationService _notificationService = NotificationService();
  final MessageService _messageService = MessageService();
  final PostService _postService = PostService();
  final ProfileService _profileService = ProfileService();
  final SupabaseClient _supabase = Supabase.instance.client;

  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String? _error;
  RealtimeChannel? _subscription;

  // 缓存：用户ID -> 头像URL
  final Map<String, String> _userAvatarCache = {};
  // 缓存：帖子ID -> 作者头像URL
  final Map<int, String> _postAuthorAvatarCache = {};

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _subscribeToNotifications();

    final currentUserId = _supabase.auth.currentUser?.id;
    print('🔍 当前登录用户ID: $currentUserId');
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  void _subscribeToNotifications() {
    try {
      _subscription = _notificationService.subscribeToNotifications(
        (newNotification) {
          print('🔄 收到新实时通知: ${newNotification.title}');
          if (mounted) {
            setState(() {
              _notifications.insert(0, newNotification);
            });
          }
        },
      );
    } catch (e) {
      print('❌ 订阅通知失败: $e');
    }
  }

  Future<void> _loadNotifications() async {
    print('🔄 加载通知列表...');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final notifications = await _notificationService.fetchNotifications();

      // 🔥 同时更新全局未读计数
      await _notificationService.fetchUnreadCount();

      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });

      print('✅ 通知加载完成，共 ${notifications.length} 条');
    } catch (e) {
      print('❌ 加载通知失败: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // 🔥 新增：计算各分类的未读数量
  int _getCategoryUnreadCount(String category) {
    if (category == 'interaction') {
      return _notifications.where((n) => 
        !n.isRead && (n.type == 'comment' || n.type == 'share')
      ).length;
    } else if (category == 'like') {
      return _notifications.where((n) => 
        !n.isRead && n.type == 'like'
      ).length;
    }
    return 0;
  }

  // 🔥 新增：导航到分类页面
  void _navigateToCategoryPage(String category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationCategoryPage(category: category),
      ),
    ).then((_) {
      // 从分类页面返回时刷新列表
      _loadNotifications();
    });
  }

  Future<void> _markAllAsRead() async {
    try {
      await _notificationService.markAllAsRead();

      // 🔥 立即更新本地状态
      setState(() {
        _notifications = _notifications.map((notif) {
          return NotificationModel(
            id: notif.id,
            userId: notif.userId,
            type: notif.type,
            refId: notif.refId,
            refUserId: notif.refUserId,
            title: notif.title,
            content: notif.content,
            isRead: true,
            createdAt: notif.createdAt,
          );
        }).toList();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已全部标记为已读')),
        );
      }
    } catch (e) {
      print('❌ 全部标记已读失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  Future<void> _markNotificationAsRead(NotificationModel notification) async {
    if (notification.isRead) return;

    try {
      await _notificationService.markAsRead(notification.id);

      // 🔥 立即更新本地状态
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          _notifications[index] = NotificationModel(
            id: notification.id,
            userId: notification.userId,
            type: notification.type,
            refId: notification.refId,
            refUserId: notification.refUserId,
            title: notification.title,
            content: notification.content,
            isRead: true,
            createdAt: notification.createdAt,
          );
        }
      });
    } catch (e) {
      print('❌ 标记已读失败: $e');
    }
  }

  Future<void> _deleteNotification(NotificationModel notification) async {
    try {
      setState(() {
        _notifications.removeWhere((n) => n.id == notification.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('通知已删除'), duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      print('❌ 删除通知失败: $e');
    }
  }

  Future<bool> _showDeleteConfirmation(NotificationModel notification) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除通知'),
            content: Text('确定要删除 "${notification.title}" 吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _handleNotificationTap(NotificationModel notification) async {
  print('📄 处理通知点击: ${notification.type} - ${notification.title}');

  // 🔥 先标记为已读
  await _markNotificationAsRead(notification);

  if (!mounted) return;

  try {
    switch (notification.type) {
      case 'follow':
        await _navigateToFollowNotifier(notification);
        break;

      case 'like':
      case 'comment':
      case 'share':      // ✅ 添加这一行
      case 'new_post':
        final postId = _getSafeInt(notification.refId);
        if (postId != null) {
          _navigateToPostDetail(postId);
        } else {
          _showNotificationDetail(notification);
        }
        break;

      case 'message':
        final conversationId = _getSafeInt(notification.refId);
        if (conversationId != null) {
          await _navigateToChat(conversationId);
        } else {
          _showNotificationDetail(notification);
        }
        break;

      case 'event':
        final eventId = _getSafeInt(notification.refId);
        if (eventId != null) {
          _navigateToPostDetail(eventId);
        } else {
          _showNotificationDetail(notification);
        }
        break;

      case 'system':
      default:
        _showNotificationDetail(notification);
        break;
    }
  } catch (e) {
    print('❌ 通知跳转失败: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('跳转失败: $e')),
      );
    }
  }
}

  int? _getSafeInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is BigInt) return value.toInt();
    if (value is num) return value.toInt();
    return null;
  }

  Future<void> _navigateToFollowNotifier(NotificationModel notification) async {
    if (notification.refUserId != null && notification.refUserId!.isNotEmpty) {
      _navigateToUserProfile(notification.refUserId!);
      return;
    }
    _showNotificationDetail(notification);
  }

  void _navigateToUserProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfilePage(userId: userId),
      ),
    );
  }

  void _navigateToPostDetail(int postId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PostDetailPage(postId: postId)),
    );
  }

  Future<void> _navigateToChat(int conversationId) async {
    try {
      final conversations = await _messageService.fetchConversations();
      final conversation = conversations.firstWhere(
        (c) => c.id == conversationId,
        orElse: () => throw Exception('会话不存在'),
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ChatPage(conversation: conversation)),
        );
      }
    } catch (e) {
      print('❌ 打开聊天失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开聊天失败: $e')),
        );
      }
    }
  }

  Future<String?> _getNotificationAvatarUrl(NotificationModel notification) async {
    switch (notification.type) {
      case 'follow':
        if (notification.refUserId != null && 
            notification.refUserId!.isNotEmpty) {
          return await _getUserAvatarUrl(notification.refUserId!);
        }
        break;

      case 'like':
      case 'comment':
      case 'new_post':
        // 🔥 优先使用 ref_user_id（操作者头像）
        if (notification.refUserId != null && 
            notification.refUserId!.isNotEmpty) {
          return await _getUserAvatarUrl(notification.refUserId!);
        }
        // 如果没有，则尝试获取帖子作者头像
        final postId = _getSafeInt(notification.refId);
        if (postId != null) {
          return await _getPostAuthorAvatarUrl(postId);
        }
        break;

      case 'message':
        if (notification.refUserId != null && 
            notification.refUserId!.isNotEmpty) {
          return await _getUserAvatarUrl(notification.refUserId!);
        }
        break;

      case 'event':
      case 'system':
        return null;
    }

    return null;
  }

  Future<String?> _getUserAvatarUrl(String userId) async {
    if (_userAvatarCache.containsKey(userId)) {
      return _userAvatarCache[userId];
    }

    try {
      final profile = await _profileService.fetchUserProfile(userId);
      if (profile != null &&
          profile.avatarUrl != null &&
          profile.avatarUrl!.isNotEmpty) {
        _userAvatarCache[userId] = profile.avatarUrl!;
        return profile.avatarUrl;
      }
    } catch (e) {
      print('⚠️ 获取用户头像失败 (userId: $userId): $e');
    }

    return null;
  }

  Future<String?> _getPostAuthorAvatarUrl(int postId) async {
    if (_postAuthorAvatarCache.containsKey(postId)) {
      return _postAuthorAvatarCache[postId];
    }

    try {
      final post = await _postService.getPostDetail(postId);
      if (post != null) {
        final author = post['author'] as Map<String, dynamic>?;
        if (author != null) {
          final avatarUrl = author['avatar_url'] as String?;
          if (avatarUrl != null && avatarUrl.isNotEmpty) {
            _postAuthorAvatarCache[postId] = avatarUrl;
            return avatarUrl;
          }
        }
      }
    } catch (e) {
      print('⚠️ 获取帖子作者头像失败 (postId: $postId): $e');
    }

    return null;
  }

  void _showNotificationDetail(NotificationModel notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            FutureBuilder<String?>(
              future: _getNotificationAvatarUrl(notification),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }

                return AvatarWidget(
                  imageUrl: snapshot.data,
                  size: 32,
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(notification.title)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (notification.content != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    notification.content!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Spacer(),
                  Text(
                    _formatTime(notification.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 🔥 新增：分类快捷入口
          _buildCategoryButtons(),
          // 只有有未读通知时才显示这一行
          if (unreadCount > 0) _buildUnreadHeader(unreadCount),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  // 🔥 新增：构建分类按钮区域
  Widget _buildCategoryButtons() {
    final interactionCount = _getCategoryUnreadCount('interaction');
    final likeCount = _getCategoryUnreadCount('like');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          // 评论和转发按钮
          Expanded(
            child: _buildCategoryButton(
              label: '评论及转发',
              icon: Icons.comment_outlined,
              unreadCount: interactionCount,
              onTap: () => _navigateToCategoryPage('interaction'),
            ),
          ),
          const SizedBox(width: 12),
          // 点赞按钮
          Expanded(
            child: _buildCategoryButton(
              label: '点赞',
              icon: Icons.favorite_outline,
              unreadCount: likeCount,
              onTap: () => _navigateToCategoryPage('like'),
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 新增：构建单个分类按钮
  Widget _buildCategoryButton({
    required String label,
    required IconData icon,
    required int unreadCount,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: const Color(0xFFED7099)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unreadCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFED7099),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnreadHeader(int unreadCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFED7099),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$unreadCount 条未读通知',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _markAllAsRead,
            child: Row(
              children: [
                const Icon(
                  Icons.done_all,
                  size: 18,
                  color: Color(0xFFED7099),
                ),
                const SizedBox(width: 4),
                Text(
                  '一键已读',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFED7099)),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Color(0xFFED7099)),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '加载失败: $_error',
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black87),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadNotifications,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFED7099),
                foregroundColor: Colors.white,
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.notifications_none,
                size: 80, color: Color(0xFFED7099)),
            SizedBox(height: 16),
            Text(
              '暂无通知',
              style: TextStyle(
                fontSize: 18,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '新的互动会在这里显示',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      backgroundColor: Colors.white,
      color: const Color(0xFFED7099),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _notifications.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Colors.grey.shade100,
        ),
        itemBuilder: (context, index) {
          final notification = _notifications[index];

          return Dismissible(
            key: Key('notification_${notification.id}'),
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            direction: DismissDirection.endToStart,
            confirmDismiss: (direction) =>
                _showDeleteConfirmation(notification),
            onDismissed: (direction) => _deleteNotification(notification),
            child: Container(
              color:
                  notification.isRead ? Colors.white : const Color(0xFFF0F8FF),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _handleNotificationTap(notification),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FutureBuilder<String?>(
                          future: _getNotificationAvatarUrl(notification),
                          builder: (context, snapshot) {
                            return AvatarWidget(
                              imageUrl: snapshot.data,
                              size: 48,
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!notification.isRead)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(
                                        top: 6,
                                        right: 8,
                                      ),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFED7099),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      notification.title,
                                      style: TextStyle(
                                        fontWeight: notification.isRead
                                            ? FontWeight.normal
                                            : FontWeight.w600,
                                        fontSize: 14,
                                        color: notification.isRead
                                            ? Colors.grey.shade700
                                            : Colors.black,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (notification.content != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  notification.content!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: notification.isRead
                                        ? Colors.grey.shade600
                                        : Colors.black87,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                _formatTime(notification.createdAt),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final notificationDay = DateTime(time.year, time.month, time.day);

    if (notificationDay == today) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (notificationDay == yesterday) {
      return '昨天 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (now.difference(time).inDays < 7) {
      final daysAgo = now.difference(time).inDays;
      return '$daysAgo天前';
    } else {
      return '${time.month}月${time.day}日';
    }
  }
}