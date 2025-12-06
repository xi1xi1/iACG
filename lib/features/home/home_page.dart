import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iacg/features/messages/chat_page.dart';
import 'package:iacg/features/messages/message_list_page.dart';
import 'package:iacg/features/search/search_page.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../services/profile_service.dart';
import 'home_recommend_tab.dart';
import 'home_events_tab.dart';
import 'home_following_tab.dart'; // 新增关注标签页
import 'package:iacg/features/post/post_compose_page.dart';
import 'package:iacg/features/post/post_detail_page.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../widgets/post_card.dart';



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

  // 未读消息计数
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    // 修改：长度改为2，只包含推荐和关注（活动已移至底部导航栏）
    _tabController = TabController(length: 2, vsync: this);
    _loadEvents();
    _checkUserRole();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _eventPageController.dispose();
    super.dispose();
  }

  // 加载活动数据 - 使用新的方法
  Future<void> _loadEvents() async {
    try {
      setState(() {
        _isEventsLoading = true;
        _eventsError = null;
      });

      // 使用专门为首页优化的活动查询方法
      final result = await EventService().fetchHomePageEvents();

      // 调试信息
      print('=== 精选活动数据调试信息 ===');
      print('获取到 ${result.length} 个精选活动');
      for (var i = 0; i < result.length; i++) {
        print('活动 $i: ${result[i]['name']}');
        print('  - post_media: ${result[i]['post_media']}');
        if (result[i]['post_media'] != null &&
            result[i]['post_media'] is List) {
          final mediaList = result[i]['post_media'] as List;
          print('  - 图片数量: ${mediaList.length}');
          for (var j = 0; j < mediaList.length; j++) {
            if (mediaList[j] is Map) {
              print('    - 图片 $j URL: ${(mediaList[j] as Map)['media_url']}');
              print('    - 图片 $j 类型: ${(mediaList[j] as Map)['media_type']}');
            }
          }
        }
      }

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
      // 首先检查用户是否登录
      if (!_authService.isLoggedIn) {
        setState(() {
          _isOrganizer = false;
          _loadingUserRole = false;
        });
        return;
      }

      // 获取用户资料并检查角色
      final profile = await ProfileService().fetchMyProfile();
      if (profile != null) {
        setState(() {
          _isOrganizer = profile.role == 'organizer';
          _loadingUserRole = false;
        });
        print('用户身份检查完成: isOrganizer = $_isOrganizer, role = ${profile.role}');
      } else {
        setState(() => _loadingUserRole = false);
      }
    } catch (e) {
      print('检查用户身份失败: $e');
      setState(() => _loadingUserRole = false);
    }
  }

  // 重构的活动卡片设计 - 二次元风格，优化左右空隙
  Widget _buildEventCard(Map<String, dynamic> event) {
    return Container(
      //color: Colors.red[100],
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // 活动背景图片 - 占满整个容器
            Container(
              width: double.infinity,
              height: 180,
              color: AnimeColors.backgroundLight,
              child: _getEventImage(event),
            ),

            // 二次元风格渐变遮罩层
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

            // 活动名称 - 二次元风格
            Positioned(
              left: 16,
              bottom: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 活动标题
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
                  // 活动类型标签
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

            // 点击区域 - 修改点击事件
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    // 跳转到活动对应的帖子详情页
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



  // 新增：跳转到活动帖子详情页的方法
  void _navigateToEventPostDetail(Map<String, dynamic> event) {
    // 从活动数据中获取关联的帖子ID
    final postId = event['post_id'];
    if (postId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PostDetailPage(postId: postId as int),
        ),
      );
    } else {
      // 如果没有帖子ID，尝试从 post 字段中获取
      final post = event['post'];
      if (post != null && post is Map && post['id'] != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PostDetailPage(postId: post['id'] as int),
          ),
        );
      } else {
        print('活动没有关联的帖子ID，无法跳转');
        // 可以显示一个提示
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('活动详情暂不可用')),
        );
      }
    }
  }

  // 获取活动图片 - 从 post_media 中获取
  Widget _getEventImage(Map<String, dynamic> event) {
    print('=== 图片获取调试 ===');
    print('活动: ${event['name']}');
    print('post_media: ${event['post_media']}');

    // 方法1: 从 post_media 中获取第一张图片
    if (event['post_media'] != null && event['post_media'] is List) {
      final mediaList = event['post_media'] as List;
      print('post_media 数量: ${mediaList.length}');

      if (mediaList.isNotEmpty) {
        // 按 sort_order 排序，获取第一张图片
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
            print('使用 post_media 图片: $imageUrl');
            return _buildNetworkImage(imageUrl.toString());
          }
        }
      }
    }

    // 方法2: 尝试 events 表的 cover_image 字段
    if (event['cover_image'] != null &&
        event['cover_image'].toString().isNotEmpty) {
      print('使用 cover_image: ${event['cover_image']}');
      return _buildNetworkImage(event['cover_image'].toString());
    }

    // 如果没有图片，显示占位图
    print('没有找到活动图片，使用占位图');
    return _buildEventPlaceholder('暂无图片');
  }

  // 构建网络图片组件 - 自适应版本
  Widget _buildNetworkImage(String imageUrl) {
    return FutureBuilder<ImageInfo>(
      future: _getImageInfo(imageUrl),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          final imageInfo = snapshot.data!;
          final width = imageInfo.image.width.toDouble();
          final height = imageInfo.image.height.toDouble();
          final aspectRatio = width / height;
          
          // 限制宽高比范围，避免极端比例
          final clampedAspectRatio = aspectRatio.clamp(0.75, 2.5);
          
          return AspectRatio(
            aspectRatio: clampedAspectRatio,
            child: Image.network(
              imageUrl,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                print('图片加载失败: $error - URL: $imageUrl');
                return _buildEventPlaceholder('图片加载失败');
              },
            ),
          );
        }
        
        // 加载中或出错时使用默认比例
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

  // 获取图片信息
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

  // 活动占位图
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

  // 修改：将活动预览部分重构为独立的组件，优化布局和分页指示器
  Widget _buildEventsPreview() {
    if (_isEventsLoading) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_eventsError != null) {
      return SizedBox(
        height: 120,
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
      return SizedBox(
        height: 120,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: Stack(
            children: [
              PageView.builder(
                controller: _eventPageController,
                itemCount: _events.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentEventPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  return _buildEventCard(_events[index]);
                },
              ),
              
              // 分页指示器 - 放在图片右下角
              if (_events.length > 1)
                Positioned(
                  right: 32,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: List.generate(_events.length, (index) {
                        return Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentEventPage == index 
                                ? Colors.white 
                                : Colors.white.withOpacity(0.4),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // 新增：构建推荐页内容（包含活动预览和帖子列表）
  Widget _buildRecommendTab() {
    return CustomScrollView(
      slivers: [
        // 活动预览部分
        SliverToBoxAdapter(
          child: _buildEventsPreview(),
        ),
        // 帖子列表部分
        const SliverToBoxAdapter(
          child: HomeRecommendTab(),
        ),
      ],
    );
  }

  // 显示频道选择底部弹窗
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
              initialChildSize: 0.55, // 增加初始高度到55%F
              minChildSize: 0.45, // 最小高度40%
              maxChildSize: 0.55, // 最大高度70%
              snap: true,
              snapSizes: const [0.54, 0.55], // 设置吸附点
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
                      // 顶部拖拽指示器
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      
                      // 标题
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
                      
                      // 频道选项 - 使用固定高度确保完全显示
                      SizedBox(
                        height: 280, // 固定高度确保三个选项完全显示
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          physics: const ClampingScrollPhysics(), // 禁用弹性效果
                          children: [
                            // COS作品
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
                            
                            // 群岛社区
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
                            
                            // 活动 - 只在用户是活动组织者时显示
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

  // 构建频道选项
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
          //color: Colors.red[100],
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Image.asset(
            'assets/images/IACG_L.PNG',
            fit: BoxFit.contain,
          ),
        ),
        leadingWidth: 80,
        title: Container(
          width: 160,
          color: AnimeColors.cardWhite,
          //color: Colors.red[100],
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
            tabs: [
              Tab(text: '推荐'),
              Tab(text: '关注'),
            ],
            isScrollable: false,
          ),
        ),
        centerTitle: true,
        actions: [
          // 搜索按钮（放大镜图标）- 放在消息按钮左侧
          IconButton(
            icon: Icon(
              Icons.search,
              color: AnimeColors.textDark,
              size: 24,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchPage()),
              );
            },
            tooltip: '搜索',
          ),
          // 消息按钮 - 放在右上角原来发布按钮的位置
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: SvgPicture.asset(
                'assets/icons/envelope.svg',
                width: 21,
                height: 21,
                color: Colors.black,
              ),
              onPressed: () {
                if (!_authService.isLoggedIn) {
                  _showLoginPrompt('查看消息需要登录');
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MessageListPage()),
                );
              },
              tooltip: '消息',
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 推荐页 - 修改为使用 CustomScrollView
          _buildRecommendTab(),
          // 关注页
          const HomeFollowingTab(),
        ],
      ),
      // 右下角悬浮发布按钮
      floatingActionButton: FloatingActionButton(
        onPressed: showChannelSelectionBottomSheet,
        backgroundColor: AnimeColors.primaryPink,
        foregroundColor: Colors.white,
        elevation: 4,
        mini:  true,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // 显示登录提示
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
