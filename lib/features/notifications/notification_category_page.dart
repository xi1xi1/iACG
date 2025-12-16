import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/notification.dart';
import '../../services/notification_service.dart';
import '../../services/post_service.dart';
import '../../services/profile_service.dart';
import '../../widgets/avatar_widget.dart';
import '../post/post_detail_page.dart';

class NotificationCategoryPage extends StatefulWidget {
  final String category; // 'interaction' 或 'like'

  const NotificationCategoryPage({
    super.key,
    required this.category,
  });

  @override
  State<NotificationCategoryPage> createState() => _NotificationCategoryPageState();
}

class _NotificationCategoryPageState extends State<NotificationCategoryPage> {
  final NotificationService _notificationService = NotificationService();
  final PostService _postService = PostService();
  final ProfileService _profileService = ProfileService();
  final SupabaseClient _supabase = Supabase.instance.client;

  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String? _error;

  // 缓存
  final Map<String, String> _userAvatarCache = {};
  final Map<int, String> _postAuthorAvatarCache = {};

  @override
  void initState() {
    super.initState();
    _loadCategoryNotifications();
  }

  String get _pageTitle {
    return widget.category == 'interaction' ? '评论和转发' : '点赞';
  }

  Future<void> _loadCategoryNotifications() async {
    print('🔄 加载分类通知: ${widget.category}');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final allNotifications = await _notificationService.fetchNotifications();
      print('📊 总通知数: ${allNotifications.length}');

      // 打印所有通知的类型，用于调试
      for (var n in allNotifications) {
        print('  - 通知类型: ${n.type}, 标题: ${n.title}');
      }

      // 根据分类筛选通知
      List<NotificationModel> filtered;
      if (widget.category == 'interaction') {
        // 评论和转发
        filtered = allNotifications.where((n) =>
        n.type == 'comment' || n.type == 'share'
        ).toList();
        print('✅ 评论和转发通知数: ${filtered.length}');
      } else {
        // 点赞
        filtered = allNotifications.where((n) =>
        n.type == 'like'
        ).toList();
        print('✅ 点赞通知数: ${filtered.length}');
      }

      setState(() {
        _notifications = filtered;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ 加载分类通知失败: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
// 一键已读
  Future<void> _markAllCategoryAsRead() async {
    try {
      // 调用新的分类标记方法
      await _notificationService.markCategoryAsRead(widget.category);

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
            isRead: true,  // 全部标记为已读
            createdAt: notif.createdAt,
          );
        }).toList();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_pageTitle}通知已标记为已读')),
        );
      }
    } catch (e) {
      print('❌ 分类通知全部标记已读失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

// 获取当前分类的未读数量
  int get _unreadCount {
    return _notifications.where((n) => !n.isRead).length;
  }

  Future<void> _markAsReadAndNavigate(NotificationModel notification) async {
    // 标记为已读
    if (!notification.isRead) {
      try {
        await _notificationService.markAsRead(notification.id);
      } catch (e) {
        print('❌ 标记已读失败: $e');
      }
    }

    // 跳转到帖子详情
    final postId = _getSafeInt(notification.refId);
    if (postId != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostDetailPage(postId: postId),
        ),
      );
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

  // 获取通知对应的头像URL
  Future<String?> _getNotificationAvatarUrl(NotificationModel notification) async {
    // 对于点赞和评论，使用 ref_user_id（操作者的头像）
    if (notification.refUserId != null && notification.refUserId!.isNotEmpty) {
      return await _getUserAvatarUrl(notification.refUserId!);
    }

    // 如果没有 ref_user_id，尝试通过帖子获取作者头像
    final postId = _getSafeInt(notification.refId);
    if (postId != null) {
      return await _getPostAuthorAvatarUrl(postId);
    }

    return null;
  }

  // 获取用户头像URL（带缓存）
  Future<String?> _getUserAvatarUrl(String userId) async {
    if (_userAvatarCache.containsKey(userId)) {
      return _userAvatarCache[userId];
    }

    try {
      final profile = await _profileService.fetchUserProfile(userId);
      if (profile != null && profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) {
        _userAvatarCache[userId] = profile.avatarUrl!;
        return profile.avatarUrl;
      }
    } catch (e) {
      print('⚠️ 获取用户头像失败 (userId: $userId): $e');
    }

    return null;
  }

  // 通过帖子ID获取作者头像URL
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _pageTitle,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,

      ),
      body: _buildBody(),
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
            Text('加载失败: $_error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCategoryNotifications,
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
            const Icon(Icons.notifications_none, size: 80, color: Color(0xFFED7099)),
            const SizedBox(height: 16),
            Text(
              '暂无${_pageTitle}通知',
              style: const TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    // 如果有未读通知，在顶部显示提示
    return Column(
      children: [
        if (_unreadCount > 0)
          Container(
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
                  '$_unreadCount 条未读通知',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _markAllCategoryAsRead,
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
          ),
        // 通知列表
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadCategoryNotifications,
            backgroundColor: Colors.white,
            color: const Color(0xFFED7099),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _notifications.length,
              separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                return _buildNotificationItem(notification);
              },
            ),
          ),
        ),
      ],
    );
  }
  // Widget _buildBody() {
  //   if (_isLoading) {
  //     return const Center(
  //       child: CircularProgressIndicator(
  //         valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFED7099)),
  //       ),
  //     );
  //   }

  //   if (_error != null) {
  //     return Center(
  //       child: Column(
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         children: [
  //           const Icon(Icons.error_outline, size: 64, color: Color(0xFFED7099)),
  //           const SizedBox(height: 16),
  //           Text('加载失败: $_error', textAlign: TextAlign.center),
  //           const SizedBox(height: 16),
  //           ElevatedButton(
  //             onPressed: _loadCategoryNotifications,
  //             style: ElevatedButton.styleFrom(
  //               backgroundColor: const Color(0xFFED7099),
  //               foregroundColor: Colors.white,
  //             ),
  //             child: const Text('重试'),
  //           ),
  //         ],
  //       ),
  //     );
  //   }

  //   if (_notifications.isEmpty) {
  //     return Center(
  //       child: Column(
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         children: [
  //           const Icon(Icons.notifications_none, size: 80, color: Color(0xFFED7099)),
  //           const SizedBox(height: 16),
  //           Text(
  //             '暂无${_pageTitle}通知',
  //             style: const TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.w500),
  //           ),
  //         ],
  //       ),
  //     );
  //   }

  //   return RefreshIndicator(
  //     onRefresh: _loadCategoryNotifications,
  //     backgroundColor: Colors.white,
  //     color: const Color(0xFFED7099),
  //     child: ListView.separated(
  //       padding: const EdgeInsets.symmetric(vertical: 8),
  //       itemCount: _notifications.length,
  //       separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
  //       itemBuilder: (context, index) {
  //         final notification = _notifications[index];
  //         return _buildNotificationItem(notification);
  //       },
  //     ),
  //   );
  // }

  Widget _buildNotificationItem(NotificationModel notification) {
    return Container(
      color: notification.isRead ? Colors.white : const Color(0xFFF0F8FF),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _markAsReadAndNavigate(notification),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头像
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
                // 内容
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
                              margin: const EdgeInsets.only(top: 6, right: 8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFED7099),
                                shape: BoxShape.circle,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w600,
                                fontSize: 14,
                                color: notification.isRead ? Colors.grey.shade700 : Colors.black,
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
                            color: notification.isRead ? Colors.grey.shade600 : Colors.black87,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        _formatTime(notification.createdAt),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
