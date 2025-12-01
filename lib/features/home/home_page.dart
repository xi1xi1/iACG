<<<<<<< HEAD
import 'dart:async';
=======
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
import 'package:flutter/material.dart';
import 'package:iacg/features/search/search_page.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import 'home_recommend_tab.dart';
import 'home_events_tab.dart';
import 'home_following_tab.dart'; // 新增关注标签页
import 'package:iacg/features/post/post_compose_page.dart';
import 'package:iacg/features/post/post_detail_page.dart';

<<<<<<< HEAD
class AnimeColors {
  static const Color primaryPink = Color(0xFFEC719A); // 粉色
  static const Color secondaryPurple = Color(0xFF8B5CF6); // 紫色
  static const Color accentCyan = Color(0xFF06B6D4); // 青色
  static const Color backgroundLight = Color(0xFFF8FAFC); // 浅灰背景
  static const Color textDark = Color(0xFF1F2937); // 深色文字
  static const Color textLight = Color(0xFF6B7280); // 浅色文字
  static const Color cardWhite = Color(0xFFFFFFFF); // 卡片白色
  static const Color gradientStart = Color(0xFFEC4899); // 渐变开始
  static const Color gradientEnd = Color(0xFF8B5CF6); // 渐变结束
}

=======
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
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
<<<<<<< HEAD
      PageController(viewportFraction: 0.95);
=======
      PageController(viewportFraction: 0.9);
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
  int _currentEventPage = 0;

  // 活动数据状态
  final List<Map<String, dynamic>> _events = [];
  bool _isEventsLoading = true;
  String? _eventsError;

  @override
  void initState() {
    super.initState();
    // 修改：长度改为3，包含推荐、活动、关注
    _tabController = TabController(length: 3, vsync: this);
    _loadEvents();
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
      print('=== 活动数据调试信息 ===');
      print('获取到 ${result.length} 个活动');
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

<<<<<<< HEAD
  // 重构的活动卡片设计 - 二次元风格，优化左右空隙
  Widget _buildEventCard(Map<String, dynamic> event) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
=======
  // 重构的活动卡片设计
  Widget _buildEventCard(Map<String, dynamic> event) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
        child: Stack(
          children: [
            // 活动背景图片 - 占满整个容器
            Container(
              width: double.infinity,
<<<<<<< HEAD
              height: 360,
              color: AnimeColors.backgroundLight,
              child: _getEventImage(event),
            ),

            // 二次元风格渐变遮罩层
            Container(
              width: double.infinity,
              height: 360,
=======
              height: 200,
              color: Colors.grey[200],
              child: _getEventImage(event),
            ),

            // 渐变遮罩层
            Container(
              width: double.infinity,
              height: 200,
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
<<<<<<< HEAD
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6, 1.0],
=======
                    Colors.black.withOpacity(0.55),
                    Colors.black.withOpacity(0.28),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45, 1.0],
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
                ),
              ),
            ),

<<<<<<< HEAD
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
=======
            // 活动名称
            Positioned(
              left: 16,
              bottom: 16,
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.55,
                child: Text(
                  event['name']?.toString() ?? '未知活动',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
              ),
            ),

            // 点击区域 - 修改点击事件
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
<<<<<<< HEAD
                  borderRadius: BorderRadius.circular(20),
=======
                  borderRadius: BorderRadius.circular(16),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
                  onTap: () {
                    // 跳转到活动对应的帖子详情页
                    _navigateToEventPostDetail(event);
                  },
<<<<<<< HEAD
                  splashColor: AnimeColors.primaryPink.withOpacity(0.3),
=======
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

<<<<<<< HEAD


=======
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
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

<<<<<<< HEAD
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
=======
  // 构建网络图片组件
  Widget _buildNetworkImage(String imageUrl) {
    return Image.network(
      imageUrl,
      width: double.infinity,
      height: 200,
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
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
            ),
          ),
        );
      },
<<<<<<< HEAD
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

=======
      errorBuilder: (context, error, stackTrace) {
        print('图片加载失败: $error - URL: $imageUrl');
        return _buildEventPlaceholder('图片加载失败');
      },
    );
  }

>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
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

<<<<<<< HEAD
  // 修改：将活动预览部分重构为独立的组件，优化布局和分页指示器
=======
  // 修改：将活动预览部分重构为独立的组件
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
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
<<<<<<< HEAD
        const SizedBox(height: 8),
        SizedBox(
          height: 260,
=======
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '热门活动',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  _tabController.animateTo(1); // 跳转到活动页
                },
                child: const Text(
                  '查看全部',
                  style: TextStyle(fontSize: 14, color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
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
<<<<<<< HEAD
              
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
=======
              if (_events.length > 1) ...[
                Positioned(
                  left: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        if (_currentEventPage > 0) {
                          _eventPageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      child: AnimatedOpacity(
                        opacity: _currentEventPage > 0 ? 1.0 : 0.3,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        if (_currentEventPage < _events.length - 1) {
                          _eventPageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      child: AnimatedOpacity(
                        opacity:
                            _currentEventPage < _events.length - 1 ? 1.0 : 0.3,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_events.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _currentEventPage == index ? 20 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color:
                    _currentEventPage == index ? Colors.blue : Colors.grey[300],
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
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

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    final tabs = ['推荐', '活动', '关注'];

    return Scaffold(
      backgroundColor: AnimeColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AnimeColors.cardWhite,
        elevation: 0,
        title: Row(
          children: [
            // Logo图片部分
            Image.asset(
              'assets/images/IACG_L.PNG',
              height: 32,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 16),
            // 搜索框 - 二次元风格
=======
    // 修改：标签改为3个
    final tabs = ['推荐', '活动', '关注'];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'iACG',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 16),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
<<<<<<< HEAD
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
=======
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
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
<<<<<<< HEAD
                    hintStyle: TextStyle(color: AnimeColors.textLight),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.grey,
                      size: 20,
                    ),
=======
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
<<<<<<< HEAD
          // 发布按钮 - 二次元风格
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AnimeColors.primaryPink,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AnimeColors.primaryPink.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PostComposePage()),
                );
              },
              tooltip: '发布',
            ),
          ),
          if (!_authService.isLoggedIn)
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pushNamed('/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AnimeColors.primaryPink,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                ),
                child: const Text(
                  '登录',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              color: AnimeColors.cardWhite,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
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
                fontSize: 14,
              ),
              tabs: tabs.map((tab) => Tab(text: tab)).toList(),
              isScrollable: false,
            ),
          ),
=======
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PostComposePage()),
              );
            },
            tooltip: '发布',
          ),
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
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 推荐页 - 修改为使用 CustomScrollView
          _buildRecommendTab(),
          // 活动页
          const HomeEventsTab(),
          // 新增：关注页
          const HomeFollowingTab(),
        ],
      ),
    );
  }
}
