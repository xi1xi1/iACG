import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/message_service.dart'; // 🔥 新增：导入消息服务


class AppBottomNav extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  final NotificationService _notificationService = NotificationService();
  int _unreadCount = 0;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    _subscribeToNotifications();

    // 🔥 新增：添加全局未读消息监听
    MessageService.addListener(_onUnreadCountChanged);
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    // 🔥 新增：移除全局监听
    MessageService.removeListener(_onUnreadCountChanged);
    super.dispose();
  }

  // 🔥 新增：全局未读消息变化回调
  void _onUnreadCountChanged() {
    if (mounted) {
      _loadUnreadCount();
    }
  }

  /// 加载未读消息数
  Future<void> _loadUnreadCount() async {
    try {
      final count = await _notificationService.fetchUnreadCount();
      if (mounted) {
        setState(() {
          _unreadCount = count;
        });
      }
    } catch (e) {
      // 静默失败，不影响主功能
    }
  }

  /// 订阅实时通知，自动更新角标
  void _subscribeToNotifications() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _subscription = _notificationService.subscribeToNotifications(
      (newNotification) {
        if (mounted) {
          _loadUnreadCount(); // 收到新通知时刷新未读数
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: widget.currentIndex,
      onTap: (index) {
        widget.onTap(index);
        
        // 点击消息Tab时，刷新未读数（用户可能已读）
        if (index == 3) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _loadUnreadCount();
            }
          });
        }
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: Color(0xFFF8F8F8),
      items: [
        // 首页
        BottomNavigationBarItem(
          icon: _buildHomeIcon(false),
          activeIcon: _buildHomeIcon(true),
          label: '首页',
        ),
        // 关注
        BottomNavigationBarItem(
          icon: _buildCosIcon(false),
          activeIcon: _buildCosIcon(true),
          label: 'Cos',
        ),
        // 发布
        BottomNavigationBarItem(
          icon: _buildIslandIcon(false),
          activeIcon: _buildIslandIcon(true),
          label: '群岛',
        ),
        // 消息（带角标）
        BottomNavigationBarItem(
          icon: _buildMessageIcon(false),
          activeIcon: _buildMessageIcon(true),
          label: '消息',
        ),
        // 我的
        BottomNavigationBarItem(
          icon: _buildMeCosIcon(false),
          activeIcon: _buildMeCosIcon(true),
          label: '我的',
        ),
      ],
    );
  }

  /// 构建首页图标
  Widget _buildHomeIcon(bool isActive) {
    //使用 SVG 图标
    return SvgPicture.asset(
      isActive ? 'assets/icons/home.svg' : 'assets/icons/home.svg',
      width: 24,
      height: 24,
      color: isActive ? const Color(0xFFEC4899) : Colors.grey,
    );
  }

  /// 构建群岛图标
  Widget _buildIslandIcon(bool isActive) {
    //使用 SVG 图标
    return SvgPicture.asset(
      isActive ? 'assets/icons/island.svg' : 'assets/icons/island.svg',
      width: 24,
      height: 24,
      color: isActive ? const Color(0xFFEC4899) : Colors.grey,
    );
  }

  /// 构建cos图标
  Widget _buildCosIcon(bool isActive) {
    //使用 SVG 图标
    return SvgPicture.asset(
      isActive ? 'assets/icons/cos.svg' : 'assets/icons/cos.svg',
      width: 24,
      height: 24,
      color: isActive ? const Color(0xFFEC4899) : Colors.grey,
    );
  }

  /// 构建基础信息图标
  Widget _buildMesCosIcon(bool isActive) {
    //使用 SVG 图标
    return SvgPicture.asset(
      isActive ? 'assets/icons/message.svg' : 'assets/icons/message.svg',
      width: 24,
      height: 24,
      color: isActive ? const Color(0xFFEC4899) : Colors.grey,
    );
  }
  /// 构建消息图标（带未读角标）
  Widget _buildMessageIcon(bool isActive) {
    final icon = isActive
        ? _buildMesCosIcon(true)
        : _buildMesCosIcon(false);

    // 如果有未读消息，显示角标
    if (_unreadCount > 0) {
      return Badge(
        label: Text(
          _unreadCount > 99 ? '99+' : '$_unreadCount',
          style: const TextStyle(fontSize: 10),
        ),
        backgroundColor: Colors.red,
        textColor: Colors.white,
        child: icon,
      );
    }

    // 🔥 新增：检查是否有私信未读，显示小红点
    final hasUnreadMessages = MessageService.globalUnreadCount > 0;

    if (hasUnreadMessages) {
      return Stack(
        children: [
          icon,
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
          )
        ],
      );
    }

    return icon;
  }

  /// 构建我的图标
  Widget _buildMeCosIcon(bool isActive) {
    //使用 SVG 图标
    return SvgPicture.asset(
      isActive ? 'assets/icons/me.svg' : 'assets/icons/me.svg',
      width: 24,
      height: 24,
      color: isActive ? const Color(0xFFEC4899) : Colors.grey,
    );
  }


}
