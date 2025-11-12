import 'package:flutter/material.dart';
import '../../widgets/app_bottom_nav.dart';
import '../home/home_page.dart';
import '../follow/follow_page.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _currentIndex = 0;

  // 页面列表 - 对应底部导航
  final List<Widget> _pages = [
    const HomePage(),
    const FollowPage(),
    _buildPlaceholder('发布'),
    _buildPlaceholder('消息'),
    _buildPlaceholder('我的'),
  ];

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
            const SizedBox(height: 16),
            if (name == '发布' || name == '消息' || name == '我的')
              const Text(
                '请先登录后使用',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  // 处理底部导航点击
  void _onBottomNavTap(int index) {
    if (index == 2 || index == 3 || index == 4) {
      // 发布、消息、我的页面需要登录
      _showLoginPrompt();
      return;
    }

    setState(() {
      _currentIndex = index;
    });
  }

  // 显示登录提示
  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('登录提示'),
        content: const Text('请先登录后使用此功能'),
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

  // 跳转到登录页面
  void _navigateToLogin() {
    Navigator.of(context).pushNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTap,
      ),
    );
  }
}
