// lib/features/notifications/notification_list_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/notification.dart';
import '../../services/notification_service.dart';
import '../../services/message_service.dart';
import '../profile/user_profile_page.dart';
import '../messages/chat_page.dart';

class NotificationListPage extends StatefulWidget {
  const NotificationListPage({Key? key}) : super(key: key);

  @override
  State<NotificationListPage> createState() => _NotificationListPageState();
}

class _NotificationListPageState extends State<NotificationListPage> {
  final NotificationService _notificationService = NotificationService();
  final MessageService _messageService = MessageService();
  
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String? _error;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _subscribeToNotifications();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  /// 订阅实时通知
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
      print('❌  $e');
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
      
      // 更新本地状态
      setState(() {
        _notifications = _notifications.map((notif) {
          return NotificationModel(
            id: notif.id,
            userId: notif.userId,
            type: notif.type,
            refId: notif.refId,
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

  /// 标记单个通知为已读
  Future<void> _markNotificationAsRead(NotificationModel notification) async {
    try {
      await _notificationService.markAsRead(notification.id);
      
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          _notifications[index] = NotificationModel(
            id: notification.id,
            userId: notification.userId,
            type: notification.type,
            refId: notification.refId,
            title: notification.title,
            content: notification.content,
            isRead: true,
            createdAt: notification.createdAt,
          );
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('标记为已读'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      print('❌ 标记已读失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  /// 删除通知
  Future<void> _deleteNotification(NotificationModel notification) async {
    try {
      // 从本地列表移除
      setState(() {
        _notifications.removeWhere((n) => n.id == notification.id);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通知已删除'), duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      print('❌ 删除通知失败: $e');
    }
  }

  /// 显示删除确认对话框
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
    ) ?? false;
  }

  Future<void> _handleNotificationTap(NotificationModel notification) async {
    print('🔄 处理通知点击: ${notification.type} - ${notification.title}');
    
    // 先标记为已读
    if (!notification.isRead) {
      try {
        await _notificationService.markAsRead(notification.id);
        
        // 立即更新本地状态，让小红点立即消失
        setState(() {
          final index = _notifications.indexWhere((n) => n.id == notification.id);
          if (index != -1) {
            _notifications[index] = NotificationModel(
              id: notification.id,
              userId: notification.userId,
              type: notification.type,
              refId: notification.refId,
              title: notification.title,
              content: notification.content,
              isRead: true, // 标记为已读
              createdAt: notification.createdAt,
            );
          }
        });
        
        print('✅ 通知标记为已读: ${notification.id}');
      } catch (e) {
        print('❌ 标记已读失败: $e');
        // 即使标记失败也继续跳转
      }
    }

    // 根据类型处理跳转
    if (!mounted) return;

    try {
      switch (notification.type) {
        case 'like':
        case 'comment':
          // 跳转到帖子详情页
          if (notification.refId != null) {
            _navigateToPostDetail(notification.refId!);
          } else {
            _showNotificationDetail(notification);
          }
          break;
          
        case 'follow':
          // 关注通知 - 显示详情
          _showNotificationDetail(notification);
          break;
          
        case 'message':
          // 跳转到聊天 (refId 存储的是 conversation_id)
          if (notification.refId != null) {
            await _navigateToChat(notification.refId!);
          } else {
            _showNotificationDetail(notification);
          }
          break;
          
        case 'event':
          // 活动通知 - 显示详情
          _showNotificationDetail(notification);
          break;
          
        case 'system':
          // 系统通知 - 显示详情
          _showNotificationDetail(notification);
          break;
          
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

  /// 跳转到帖子详情页
  void _navigateToPostDetail(int postId) {
    // TODO: 等成员B实现了 PostDetailPage 后，改为实际跳转
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('跳转到帖子详情 #$postId (待成员B实现)')),
    );
  }

  /// 跳转到聊天页面
  Future<void> _navigateToChat(int conversationId) async {
    try {
      print('🔄 跳转到聊天页面: $conversationId');
      
      // 获取会话信息
      final conversations = await _messageService.fetchConversations();
      final conversation = conversations.firstWhere(
        (c) => c.id == conversationId,
        orElse: () => throw Exception('会话不存在'),
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(conversation: conversation),
          ),
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

  /// 显示通知详情对话框
  void _showNotificationDetail(NotificationModel notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(notification.iconEmoji),
            const SizedBox(width: 8),
            Expanded(child: Text(notification.title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notification.content != null) 
              Text(notification.content!),
            const SizedBox(height: 8),
            Text(
              '类型: ${notification.typeDisplay}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            Text(
              '时间: ${_formatTime(notification.createdAt)}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            Text(
              '状态: ${notification.isRead ? "已读" : "未读"}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (!notification.isRead)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _markNotificationAsRead(notification);
              },
              child: const Text('标记已读'),
            ),
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('加载失败: $_error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadNotifications,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('暂无通知', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 8),
            Text(
              '新的互动会在这里显示',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 全部已读按钮
        if (_notifications.any((n) => !n.isRead))
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                const Icon(Icons.done_all, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                const Text(
                  '全部标记为已读',
                  style: TextStyle(fontSize: 14),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _markAllAsRead,
                  child: const Text('确认'),
                ),
              ],
            ),
          ),

        // 通知列表
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadNotifications,
            child: ListView.separated(
              itemCount: _notifications.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
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
                  secondaryBackground: Container(
                    color: Colors.green,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 20),
                    child: const Icon(Icons.done_all, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    if (direction == DismissDirection.endToStart) {
                      // 左滑删除
                      return await _showDeleteConfirmation(notification);
                    } else {
                      // 右滑标记为已读
                      if (!notification.isRead) {
                        await _markNotificationAsRead(notification);
                      }
                      return false; // 不删除，只是标记已读
                    }
                  },
                  onDismissed: (direction) {
                    if (direction == DismissDirection.endToStart) {
                      _deleteNotification(notification);
                    }
                  },
                  child: Material(
                    color: notification.isRead ? Colors.white : Colors.blue.shade50,
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: notification.isRead
                              ? Colors.grey.shade200
                              : Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            notification.iconEmoji,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              notification.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: notification.isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                                color: notification.isRead ? Colors.grey.shade700 : Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (notification.content != null)
                            Text(
                              notification.content!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: notification.isRead ? Colors.grey : Colors.black87,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTime(notification.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      trailing: notification.isRead 
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                              onPressed: () => _showDeleteConfirmation(notification).then((confirmed) {
                                if (confirmed) {
                                  _deleteNotification(notification);
                                }
                              }),
                            )
                          : IconButton(
                              icon: const Icon(Icons.done_all, size: 20, color: Colors.blue),
                              onPressed: () => _markNotificationAsRead(notification),
                            ),
                      onTap: () => _handleNotificationTap(notification),
                      onLongPress: () => _showNotificationDetail(notification),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
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
}