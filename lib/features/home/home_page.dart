import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'home_recommend_tab.dart';
import 'home_cos_tab.dart';
import 'home_island_tab.dart';
import 'home_events_tab.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ['推荐', 'COS', '群岛', '活动'];
    final tabPages = [
      const HomeRecommendTab(),
      const HomeCosTab(),
      const HomeIslandTab(),
      const HomeEventsTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('iACG'),
        actions: [
          if (!_authService.isLoggedIn)
            TextButton(
              onPressed: () => Navigator.of(context).pushNamed('/login'),
              child: const Text(
                '登录',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: tabs.map((tab) => Tab(text: tab)).toList(),
          isScrollable: true,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: tabPages,
      ),
    );
  }
}
