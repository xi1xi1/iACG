import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iacg/features/home/home_island_tab.dart';
import 'package:iacg/features/home/home_page.dart';
import 'package:iacg/features/home/home_cos_tab.dart';
import 'package:iacg/features/messages/message_list_page.dart';
import 'package:iacg/features/profile/my_profile_page.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../services/auth_service.dart';
import '../../services/message_service.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _currentIndex = 0;
  final _authService = AuthService();
  final _messageService = MessageService();

  // 🔥 新增：全局消息订阅
  RealtimeChannel? _globalMessageSubscription;

  final List<Widget> _pages = [
    const HomePage(),
    const HomeCosTab(),
    const HomeIslandTab(),
    const MessageListPage(),
    const MyProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _initGlobalMessageSubscription();

    // 🔥 监听登录状态变化
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        _initGlobalMessageSubscription();
      } else if (event == AuthChangeEvent.signedOut) {
        _disposeGlobalMessageSubscription();
      }
    });
  }

  // 🔥 新增：初始化全局消息订阅
  Future<void> _initGlobalMessageSubscription() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    print('🌍 [RootShell] 初始化全局消息订阅，用户: ${user.id}');

    // 初始化全局未读消息计数
    await _messageService.initializeGlobalUnreadCount();

    // 订阅全局新消息
    _globalMessageSubscription?.unsubscribe();
    _globalMessageSubscription = Supabase.instance.client
        .channel('root_global_messages_${user.id}')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) async {
        final senderId = payload.newRecord['sender_id'] as String?;

        // 忽略自己发送的消息
        if (senderId == user.id) return;

        print('🔔 [RootShell] 收到全局新消息推送');

        // 更新全局未读计数
        await _messageService.getTotalUnreadCount();
      },
    )
        .subscribe((status, error) {
      print('🌍 [RootShell] 全局消息订阅状态: $status');
      if (error != null) {
        print('❌ [RootShell] 全局消息订阅错误: $error');
      }
    });
  }

  // 🔥 新增：销毁全局消息订阅
  void _disposeGlobalMessageSubscription() {
    _globalMessageSubscription?.unsubscribe();
    _globalMessageSubscription = null;
    print('🌍 [RootShell] 取消全局消息订阅');
  }

  @override
  void dispose() {
    _disposeGlobalMessageSubscription();
    super.dispose();
  }

  Widget _getCurrentPage() {
    print(_currentIndex);
    return _pages[_currentIndex];
  }

  static Widget _buildPlaceholder(String name) {
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              '$name 功能开发中',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _onBottomNavTap(int index) {
    if (index == 0 || index == 1) {
      setState(() {
        _currentIndex = index;
      });
      return;
    }

    if (index == 2) {
      setState(() {
        _currentIndex = index;
      });
      return;
    }

    if (index == 3) {
      if (!_authService.isLoggedIn) {
        _showLoginPrompt('此功能需要登录');
        return;
      }
      setState(() {
        _currentIndex = index;
      });
      return;
    }

    if (index == 4) {
      if (!_authService.isLoggedIn) {
        _showLoginPrompt('此功能需要登录');
        return;
      }
      setState(() {
        _currentIndex = index;
      });
      return;
    }

    setState(() {
      _currentIndex = index;
    });
  }

  void _showLoginPrompt(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          '登录提示',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF666666),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF666666),
            ),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToLogin();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFED7099),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('去登录'),
          ),
        ],
      ),
    );
  }

  void _navigateToLogin() {
    Navigator.of(context).pushNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getCurrentPage(),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTap,
      ),
    );
  }
}