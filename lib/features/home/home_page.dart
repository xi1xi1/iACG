import 'package:flutter/material.dart';
import 'package:iacg/features/search/search_page.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import 'home_recommend_tab.dart';
import 'home_cos_tab.dart';
import 'home_island_tab.dart';
import 'home_events_tab.dart';
import 'package:iacg/features/post/post_compose_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _authService = AuthService();
  final PageController _eventPageController = PageController(viewportFraction: 0.8);
  int _currentEventPage = 0;

  // 活动数据状态
  final List<Map<String, dynamic>> _events = [];
  bool _isEventsLoading = true;
  String? _eventsError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadEvents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _eventPageController.dispose();
    super.dispose();
  }

  // 加载活动数据
  Future<void> _loadEvents() async {
    try {
      setState(() {
        _isEventsLoading = true;
        _eventsError = null;
      });

      final result = await EventService().fetchUpcomingEvents();
      setState(() {
        _events.clear();
        _events.addAll(result);
      });
    } catch (e) {
      setState(() {
        _eventsError = e.toString();
      });
    } finally {
      setState(() {
        _isEventsLoading = false;
      });
    }
  }

  // 格式化活动时间
  String _formatEventTime(String startTime, String endTime) {
    try {
      final start = DateTime.parse(startTime);
      final end = DateTime.parse(endTime);
      return '${start.month}月${start.day}日 - ${end.month}月${end.day}日';
    } catch (e) {
      return '时间未知';
    }
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 280,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 活动图片 - 如果没有图片则使用占位图
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: Container(
                height: 100, // 减少图片高度
                width: double.infinity,
                color: Colors.grey[200],
                child: event['image_url'] != null
                    ? Image.network(
                  event['image_url'],
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                )
                    : const Icon(
                  Icons.event,
                  size: 40,
                  color: Colors.grey,
                ),
              ),
            ),
            // 活动信息
            Padding(
              padding: const EdgeInsets.all(10), // 减少内边距
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event['name']?.toString() ?? '未知活动',
                    style: const TextStyle(
                      fontSize: 14, // 减小字体大小
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6), // 减少间距
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _formatEventTime(event['start_time'], event['end_time']),
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]), // 减小字体
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2), // 减少间距
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${event['city'] ?? '未知城市'} · ${event['location'] ?? '未知地点'}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]), // 减小字体
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 修改：创建一个新的推荐页面，将活动预览整合到滚动视图中
  Widget _buildRecommendPage() {
    return CustomScrollView(
      slivers: [
        // 热门活动部分
        SliverToBoxAdapter(
          child: _buildEventsPreview(),
        ),
        // 推荐内容部分 - 现在 HomeRecommendTab 返回一个 Sliver
        const HomeRecommendTab(),
      ],
    );
  }

  Widget _buildEventsPreview() {
    if (_isEventsLoading) {
      return Container(
        height: 180, // 固定高度
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_eventsError != null) {
      return Container(
        height: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('加载失败: $_eventsError', style: const TextStyle(fontSize: 12)),
              TextButton(
                onPressed: _loadEvents,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_events.isEmpty) {
      return Container(
        height: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('暂无活动', style: TextStyle(fontSize: 12)),
              TextButton(
                onPressed: _loadEvents,
                child: const Text('刷新'),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.grey[50], // 添加背景色区分
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题区域
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), // 调整顶部间距
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '热门活动',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // 切换到活动标签
                    _tabController.animateTo(1);
                  },
                  child: const Text(
                    '查看全部',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
          // 活动卡片滑动区域
          SizedBox(
            height: 190,
            child: PageView.builder(
              controller: _eventPageController,
              itemCount: _events.length,
              onPageChanged: (index) {
                setState(() {
                  _currentEventPage = index;
                });
              },
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _buildEventCard(_events[index]),
                );
              },
            ),
          ),
          // 指示器
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_events.length, (index) {
              return Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentEventPage == index
                      ? Colors.blue
                      : Colors.grey[300],
                ),
              );
            }),
          ),
          const SizedBox(height: 16), // 增加底部间距
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ['推荐', '活动'];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // 标题
            const Text(
              'iACG',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 16),
            // 搜索框
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  readOnly: true,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SearchPage()),
                    );
                  },
                  decoration: InputDecoration(
                    hintText: '搜索内容...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          // 发布按钮
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PostComposePage()),
              );
            },
            tooltip: '发布',
          ),
          // 登录按钮（未登录时显示）
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
        children: [
          // 推荐标签页 - 使用整合的滚动视图
          _buildRecommendPage(),
          // 活动标签页
          const HomeEventsTab(),
        ],
      ),
    );
  }
}