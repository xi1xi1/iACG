import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/notification.dart';
import '../../services/notification_service.dart';
import '../../services/message_service.dart';
import '../../services/post_service.dart';
import '../../services/profile_service.dart';
import '../../widgets/avatar_widget.dart';
import '../profile/user_profile_page.dart';
import '../messages/chat_page.dart';
import '../post/post_detail_page.dart';

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

      // 调试：打印通知数据详情
      if (notifications.isNotEmpty) {
        print('📊 通知数据详情:');
        for (int i = 0; i < notifications.length && i < 3; i++) {
          final notification = notifications[i];
          print('  [$i] 类型: ${notification.type}');
          print('      refId: ${notification.refId}');
          print('      refUserId: ${notification.refUserId}');
          print('      标题: ${notification.title}');
          print('      内容: ${notification.content}');
        }
      }

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
    if (notification.isRead) return; // 🔥 已读的不需要再标记

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
    print('🔄 处理通知点击: ${notification.type} - ${notification.title}');

    // 🔥 先标记为已读
    await _markNotificationAsRead(notification);

    if (!mounted) return;

    try {
      switch (notification.type) {
        case 'follow':
          // ✅ 关注通知：跳转到关注者的用户主页
          await _navigateToFollowNotifier(notification);
          break;

        case 'like':
        case 'comment':
        case 'new_post':
          // ✅ 点赞、评论、新帖子通知：跳转到对应的帖子详情页
          final postId = _getSafeInt(notification.refId);
          if (postId != null) {
            _navigateToPostDetail(postId);
          } else {
            _showNotificationDetail(notification);
          }
          break;

        case 'message':
          // ✅ 消息通知：跳转到聊天页
          final conversationId = _getSafeInt(notification.refId);
          if (conversationId != null) {
            await _navigateToChat(conversationId);
          } else {
            _showNotificationDetail(notification);
          }
          break;

        case 'event':
          // ✅ 活动通知：跳转到活动详情页（这里是帖子详情页）
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

  // ✅ 辅助方法：安全地获取整数值
  int? _getSafeInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is BigInt) return value.toInt();
    if (value is num) return value.toInt();
    return null;
  }

  Future<void> _navigateToFollowNotifier(NotificationModel notification) async {
    print('🔍 处理关注通知，获取关注者信息');
    print('  refUserId: ${notification.refUserId}');

    if (notification.refUserId != null && notification.refUserId!.isNotEmpty) {
      print('✅ 从 refUserId 找到关注者ID: ${notification.refUserId}');
      _navigateToUserProfile(notification.refUserId!);
      return;
    }

    if (notification.content != null) {
      print('🔍 尝试从内容解析用户名...');

      final patterns = [
        RegExp(r'用户\s*\[([^\]]+)\]'),
        RegExp(r'^([^ ]+)\s+关注了你'),
        RegExp(r'^([^ ]+)\s+回关了你'),
        RegExp(r'🎉\s*([^ ]+)\s+回关了你'),
      ];

      String? userName;
      for (final pattern in patterns) {
        final match = pattern.firstMatch(notification.content!);
        if (match != null) {
          userName = match.group(1);
          break;
        }
      }

      if (userName != null) {
        print('🔍 从内容解析出用户名: $userName');

        try {
          final userResponse = await _supabase
              .from('profiles')
              .select('id')
              .ilike('nickname', userName)
              .maybeSingle();

          if (userResponse != null && userResponse.isNotEmpty) {
            final userId = userResponse['id'] as String?;
            if (userId != null && userId.isNotEmpty) {
              print('✅ 从用户名找到用户ID: $userId');
              _navigateToUserProfile(userId);
              return;
            }
          }
        } catch (e) {
          print('⚠️ 从用户名查找用户失败: $e');
        }
      }
    }

    print('⚠️ 无法确定关注者用户ID');
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

  // ✅ 获取通知对应的头像URL
  Future<String?> _getNotificationAvatarUrl(
      NotificationModel notification) async {
    switch (notification.type) {
      case 'follow':
        // 关注通知：使用 ref_user_id（关注者）
        if (notification.refUserId != null &&
            notification.refUserId!.isNotEmpty) {
          return await _getUserAvatarUrl(notification.refUserId!);
        }
        break;

      case 'like':
      case 'comment':
      case 'new_post':
        // 帖子相关通知：通过 ref_id（帖子ID）获取作者头像
        final postId = _getSafeInt(notification.refId);
        if (postId != null) {
          return await _getPostAuthorAvatarUrl(postId);
        }
        break;

      case 'message':
        // 消息通知：使用 ref_user_id（发消息者）
        if (notification.refUserId != null &&
            notification.refUserId!.isNotEmpty) {
          return await _getUserAvatarUrl(notification.refUserId!);
        }
        break;

      case 'event':
      case 'system':
        // 系统和活动通知：默认使用系统头像（返回null会使用默认头像）
        return null;
    }

    return null;
  }

  // ✅ 获取用户头像URL（带缓存）
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

  // ✅ 通过帖子ID获取作者头像URL（使用 getPostDetail 方法）
  Future<String?> _getPostAuthorAvatarUrl(int postId) async {
    if (_postAuthorAvatarCache.containsKey(postId)) {
      return _postAuthorAvatarCache[postId];
    }

    try {
      // 使用 getPostDetail 方法获取帖子详情
      final post = await _postService.getPostDetail(postId);
      if (post != null) {
        // 获取作者信息
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
            // 使用通知发布方的头像
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
          // 只有有未读通知时才显示这一行
          if (unreadCount > 0) _buildUnreadHeader(unreadCount),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

// 构建未读通知状态栏
  Widget _buildUnreadHeader(int unreadCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white, // ✅ 正确：将颜色放在 decoration 中
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFED7099),
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
          children: [
            const Icon(Icons.notifications_none,
                size: 80, color: Color(0xFFED7099)),
            const SizedBox(height: 16),
            const Text(
              '暂无通知',
              style: TextStyle(
                fontSize: 18,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
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
                        // 使用通知对应的用户头像
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

  Color _getTypeColor(String type) {
    switch (type) {
      case 'follow':
        return Colors.blue.shade600;
      case 'like':
        return const Color(0xFFED7099);
      case 'comment':
        return Colors.green.shade600;
      case 'message':
        return Colors.purple.shade600;
      case 'event':
        return Colors.orange.shade600;
      case 'new_post':
        return Colors.teal.shade600;
      case 'system':
        return Colors.grey.shade600;
      default:
        return Colors.grey.shade600;
    }
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
