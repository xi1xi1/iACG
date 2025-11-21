import 'package:flutter/material.dart';
import 'package:iacg/features/home/home_island_tab.dart';
import 'package:iacg/features/post/post_compose_page.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../services/auth_service.dart';
import '../home/home_page.dart';
import '../follow/follow_page.dart';
import '../messages/message_list_page.dart';
import '../profile/my_profile_page.dart';
import '../home/home_cos_tab.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _currentIndex = 0;
  final _authService = AuthService();

  // ✅ 首页和关注页无需登录即可访问
  final List<Widget> _pages = [
    const HomePage(),          // 首页 - 游客可访问
    const HomeCosTab(),        // 关注 - 游客可访问(显示登录提示)
    //_buildPlaceholder('发布'), // 发布 - 占位符
    const HomeIslandTab(),
    const MessageListPage(),   // 消息 - 需要登录
    const MyProfilePage(),     // 我的 - 需要登录
  ];

  // 🆕 新增：用于动态创建我的页面
  Widget _getCurrentPage() {
    // 如果不是"我的"页面，使用原来的页面
    print(_currentIndex);
    // if (_currentIndex != 4) {
    //   return _pages[_currentIndex];
    // }
    return _pages[_currentIndex];
    
    // 如果是"我的"页面，每次都重新创建
    //return const MyProfilePage();
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

  /// 处理底部导航点击
  void _onBottomNavTap(int index) {
    // ✅ 首页(0)和关注(1)无需登录即可访问
    if (index == 0 || index == 1) {
      setState(() {
        _currentIndex = index;
      });
      return;
    }

    // ✅ 发布功能(2)需要登录
    if (index == 2) {
      // if (!_authService.isLoggedIn) {
      //   _showLoginPrompt('发布内容需要登录');
      //   return;
      // }
      // _navigateToCompose();
      setState(() {
        _currentIndex = index;
      });
      return;
    }

    // ✅ 消息(3)需要登录
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

    // ✅ 我的(4)需要登录
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

    // 默认切换页面
    setState(() {
      _currentIndex = index;
    });
  }

  /// 发布功能入口：跳转到发帖页
  // void _navigateToCompose() {
  //   Navigator.of(context).push(
  //     MaterialPageRoute(
  //       builder: (_) => const PostComposePage(),
  //     ),
  //   );
  // }

  /// 显示登录提示对话框
  void _showLoginPrompt(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('登录提示'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToLogin();
            },
            child: const Text('去登录'),
          ),
        ],
      ),
    );
  }

  /// 跳转到登录页面
  void _navigateToLogin() {
    Navigator.of(context).pushNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getCurrentPage(), // 🆕 修改：使用动态创建页面
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTap,
      ),
    );
  }
}