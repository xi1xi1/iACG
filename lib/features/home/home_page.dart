
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iacg/features/auth/login_page.dart';
import 'package:iacg/features/messages/chat_page.dart';
import 'package:iacg/features/messages/message_list_page.dart';
import 'package:iacg/features/search/search_page.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../services/profile_service.dart';
import '../../services/notification_service.dart'; // 🔥 新增
import 'home_recommend_tab.dart';
import 'home_events_tab.dart';
import 'home_following_tab.dart';
import 'package:iacg/features/post/post_compose_page.dart';
import 'package:iacg/features/post/post_detail_page.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../widgets/post_card.dart';
import 'home_recommend_tab_with_events.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _authService = AuthService();
  final PageController _eventPageController =
      PageController(viewportFraction: 0.95);
  int _currentEventPage = 0;

  // 活动数据状态
  final List<Map<String, dynamic>> _events = [];
  bool _isEventsLoading = true;
  String? _eventsError;

  // 用户身份状态
  bool _isOrganizer = false;
  bool _loadingUserRole = true;

  // 🔥 新增：通知未读计数
  int _notificationUnreadCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadEvents();
    _checkUserRole();
    
    // 🔥 新增：初始化通知监听
    _initNotificationListener();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _eventPageController.dispose();
    // 🔥 新增：移除通知监听
    NotificationService.removeListener(_updateNotificationCount);
    super.dispose();
  }

  // 🔥 新增：初始化通知监听器
  void _initNotificationListener() {
    // 添加监听器
    NotificationService.addListener(_updateNotificationCount);
    
    // 首次加载未读计数
    _loadNotificationCount();
  }

  // 🔥 新增：更新通知计数（监听器回调）
  void _updateNotificationCount() {
    if (mounted) {
      setState(() {
        _notificationUnreadCount = NotificationService.globalUnreadCount;
      });
    }
  }

  // 🔥 新增：加载通知未读计数
  Future<void> _loadNotificationCount() async {
    if (!_authService.isLoggedIn) {
      setState(() {
        _notificationUnreadCount = 0;
      });
      return;
    }

    try {
      await NotificationService().fetchUnreadCount();
      // fetchUnreadCount 会自动更新 globalUnreadCount 并触发监听器
    } catch (e) {
      print('❌ 加载通知未读数失败: $e');
    }
  }

  // 加载活动数据 - 使用新的方法
  Future<void> _loadEvents() async {
    try {
      setState(() {
        _isEventsLoading = true;
        _eventsError = null;
      });

      final result = await EventService().fetchHomePageEvents();

      setState(() {
        _events.clear();
        _events.addAll(result);
      });
    } catch (e) {
      print('加载活动数据失败: $e');
      setState(() {
        _eventsError = e.toString();
      });
    } finally {
      setState(() {
        _isEventsLoading = false;
      });
    }
  }

  // 检查用户是否是活动组织者
  Future<void> _checkUserRole() async {
    try {
      if (!_authService.isLoggedIn) {
        setState(() {
          _isOrganizer = false;
          _loadingUserRole = false;
        });
        return;
      }

      final profile = await ProfileService().fetchMyProfile();
      if (profile != null) {
        setState(() {
          _isOrganizer = profile.role == 'organizer';
          _loadingUserRole = false;
        });
      } else {
        setState(() => _loadingUserRole = false);
      }
    } catch (e) {
      print('检查用户身份失败: $e');
      setState(() => _loadingUserRole = false);
    }
  }

  // 重构的活动卡片设计
  Widget _buildEventCard(Map<String, dynamic> event) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              height: 180,
              color: AnimeColors.backgroundLight,
              child: _getEventImage(event),
            ),
            Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 16,
              bottom: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event['name']?.toString() ?? '未知活动',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 4,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (event['event_type'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AnimeColors.primaryPink.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        event['event_type'].toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    _navigateToEventPostDetail(event);
                  },
                  splashColor: AnimeColors.primaryPink.withOpacity(0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToEventPostDetail(Map<String, dynamic> event) {
    final postId = event['post_id'];
    if (postId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PostDetailPage(postId: postId as int),
        ),
      );
    } else {
      final post = event['post'];
      if (post != null && post is Map && post['id'] != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PostDetailPage(postId: post['id'] as int),
          ),
        );
      }
    }
  }

  Widget _getEventImage(Map<String, dynamic> event) {
    if (event['post_media'] != null && event['post_media'] is List) {
      final mediaList = event['post_media'] as List;
      if (mediaList.isNotEmpty) {
        List<dynamic> sortedMedia = List.from(mediaList);
        sortedMedia.sort((a, b) {
          final orderA = (a['sort_order'] as num?)?.toInt() ?? 0;
          final orderB = (b['sort_order'] as num?)?.toInt() ?? 0;
          return orderA.compareTo(orderB);
        });

        final firstMedia = sortedMedia.first;
        if (firstMedia is Map) {
          final imageUrl = firstMedia['media_url'];
          final mediaType = firstMedia['media_type'];

          if (imageUrl != null &&
              imageUrl.toString().isNotEmpty &&
              mediaType == 'image') {
            return _buildNetworkImage(imageUrl.toString());
          }
        }
      }
    }

    if (event['cover_image'] != null &&
        event['cover_image'].toString().isNotEmpty) {
      return _buildNetworkImage(event['cover_image'].toString());
    }

    return _buildEventPlaceholder('暂无图片');
  }

  Widget _buildNetworkImage(String imageUrl) {
    return FutureBuilder<ImageInfo>(
      future: _getImageInfo(imageUrl),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          final imageInfo = snapshot.data!;
          final width = imageInfo.image.width.toDouble();
          final height = imageInfo.image.height.toDouble();
          final aspectRatio = width / height;
          final clampedAspectRatio = aspectRatio.clamp(0.75, 2.5);
          
          return AspectRatio(
            aspectRatio: clampedAspectRatio,
            child: Image.network(
              imageUrl,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildEventPlaceholder('图片加载失败');
              },
            ),
          );
        }
        
        return AspectRatio(
          aspectRatio: 16/9,
          child: Container(
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        );
      },
    );
  }

  Future<ImageInfo> _getImageInfo(String imageUrl) async {
    final completer = Completer<ImageInfo>();
    final imageProvider = NetworkImage(imageUrl);
    
    imageProvider.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        if (!completer.isCompleted) {
          completer.complete(info);
        }
      }),
    );
    
    return completer.future;
  }

  Widget _buildEventPlaceholder(String message) {
    return Container(
      color: Colors.grey[300],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event, size: 48, color: Colors.grey[500]),
          const SizedBox(height: 8),
          Text(message,
              style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildRecommendTab() {
    return const HomeRecommendTabWithEvents();
  }

  Future<void> _handlePublishButtonTap() async {
    final uid = _authService.currentUser?.id;
    if (uid == null) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('需要登录'),
            shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
            content: const Text('登录后才能发布帖子，去登录吧～'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LoginPage(),
                    ),
                  );
                },
                child: const Text('去登录', style: TextStyle(color: Color(0xFFED7099))),
              ),
            ],
          ),
        );
      }
      return;
    }

    showChannelSelectionBottomSheet();
  }

  void showChannelSelectionBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            color: Colors.black.withOpacity(0.4),
            child: DraggableScrollableSheet(
              initialChildSize: 0.55,
              minChildSize: 0.45,
              maxChildSize: 0.55,
              snap: true,
              snapSizes: const [0.54, 0.55],
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: AnimeColors.cardWhite,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 20),
                        child: Text(
                          '请选择发布频道',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AnimeColors.textDark,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 280,
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          physics: const ClampingScrollPhysics(),
                          children: [
                            _buildChannelOption(
                              label: 'COS作品',
                              icon: Icons.photo_camera,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PostComposePage(initialChannel: 'cos'),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildChannelOption(
                              label: '群岛社区',
                              icon: Icons.people,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PostComposePage(initialChannel: 'island'),
                                  ),
                                );
                              },
                            ),
                            if (_isOrganizer) ...[
                              const SizedBox(height: 16),
                              _buildChannelOption(
                                label: '活动',
                                icon: Icons.event,
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => PostComposePage(initialChannel: 'event'),
                                    ),
                                  );
                                },
                              ),
                            ],
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildChannelOption({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AnimeColors.primaryPink.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: AnimeColors.primaryPink,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AnimeColors.textDark,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AnimeColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AnimeColors.cardWhite,
        elevation: 0,
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Image.asset(
            'assets/images/IACG_L.PNG',
            fit: BoxFit.contain,
          ),
        ),
        leadingWidth: 80,
        title: Container(
          width: 160,
          color: AnimeColors.cardWhite,
          child: TabBar(
            controller: _tabController,
            labelColor: AnimeColors.primaryPink,
            unselectedLabelColor: AnimeColors.textLight,
            indicatorColor: AnimeColors.primaryPink,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 16,
            ),
            tabs: const [
              Tab(text: '推荐'),
              Tab(text: '关注'),
            ],
            isScrollable: false,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.search,
              color: Colors.black,
              size: 24,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchPage()),
              );
            },
            tooltip: '搜索',
          ),
          // 🔥 修改：添加小红点的信封按钮
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Stack(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.markunread_outlined,
                    color: Colors.black,
                    size: 24,
                  ),
                  onPressed: () {
                    if (!_authService.isLoggedIn) {
                      _showLoginPrompt('查看通知需要登录');
                      return;
                    }
                    // 🔥 修改：跳转到消息页面（保持原有逻辑）
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MessageListPage()),
                    ).then((_) {
                      // 🔥 从消息页面返回时刷新未读计数
                      _loadNotificationCount();
                    });
                  },
                  tooltip: '消息',
                ),
                // 🔥 新增：小红点
                if (_notificationUnreadCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFED7099),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          HomeRecommendTabWithEvents(),
          HomeFollowingTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handlePublishButtonTap,
        backgroundColor: AnimeColors.primaryPink,
        foregroundColor: Colors.white,
        elevation: 4,
        mini: true,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
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
              Navigator.of(context).pushNamed('/login');
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
}