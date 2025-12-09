import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iacg/features/auth/login_page.dart';
import 'package:iacg/widgets/post_card.dart';
import '../../services/post_service.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';
import '../../services/profile_service.dart';
import 'package:iacg/features/post/post_compose_page.dart';
import 'package:iacg/features/search/search_page.dart';
import '../../services/auth_service.dart';
import '../../core/supabase_client.dart';

class HomeIslandTab extends StatefulWidget {
  const HomeIslandTab({super.key});

  @override
  State<HomeIslandTab> createState() => _HomeIslandTabState();
}

class _HomeIslandTabState extends State<HomeIslandTab>
    with SingleTickerProviderStateMixin {
  final List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  String _selectedType = '全部';
  final AuthService _authService = AuthService();

  // 分页相关变量
  int _currentPage = 1;
  bool _hasMore = true;
  final int _pageSize = 20;

  // 一级筛选：全部、关注
  final List<String> _topTabs = ['全部', '关注'];
  late TabController _tabController;
  int _selectedTopTab = 0;

  // 用户身份状态
  bool _isOrganizer = false;
  bool _loadingUserRole = true;

  // 群岛类型选项 - 增强二次元风格
  final List<Map<String, dynamic>> _islandTypes = [
    {'type': '全部', 'icon': Icons.all_inclusive, 'color': Color(0xFF8B5CF6)},
    {'type': '求助', 'icon': Icons.help_outline, 'color': Color(0xFFEC4899)},
    {'type': '分享', 'icon': Icons.share_outlined, 'color': Color(0xFF06B6D4)},
    {'type': '吐槽', 'icon': Icons.sentiment_dissatisfied_outlined, 'color': Color(0xFFF59E0B)},
    {'type': '找搭子', 'icon': Icons.group_add_outlined, 'color': Color(0xFF10B981)},
    {'type': '约拍', 'icon': Icons.photo_camera_outlined, 'color': Color(0xFFEF4444)},
    {'type': '其他', 'icon': Icons.more_horiz, 'color': Color(0xFF6B7280)},
  ];

  final ScrollController _scrollController = ScrollController();
  final PostService _postService = PostService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _topTabs.length, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _scrollController.addListener(_scrollListener);
    _loadPosts();
    _checkUserRole();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _selectedTopTab = _tabController.index;
        _currentPage = 1;
        _hasMore = true;
      });
      _loadPosts(isRefresh: true);
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMorePosts();
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

  Future<void> _loadPosts({bool isRefresh = false, String? type}) async {
    try {
      setState(() {
        if (isRefresh) {
          _currentPage = 1;
          _hasMore = true;
          _posts.clear();
        }
        if (type != null) {
          _selectedType = type;
        }
        _isLoading = true;
        _error = null;
      });

      if (kDebugMode) {
        debugPrint('开始加载群岛帖子，一级筛选: ${_topTabs[_selectedTopTab]}, 二级筛选: $_selectedType, 页码: $_currentPage');
      }

      List<Map<String, dynamic>> result;

      if (_selectedTopTab == 0) {
        // 全部标签：按类型筛选
        final String? islandType = _selectedType == '全部' ? null : _selectedType;
        result = await _postService.fetchIslandPosts(
          islandType: islandType,
          limit: _pageSize,
          offset: (isRefresh ? 0 : _currentPage - 1) * _pageSize,
        );
      } else {
        // 关注标签：获取关注用户的群岛帖子
        if (!_authService.isLoggedIn) {
          setState(() {
            _error = '请先登录查看关注内容';
            _isLoading = false;
          });
          return;
        }

        final userId = _authService.currentUser?.id;
        if (userId == null) {
          setState(() {
            _error = '用户信息获取失败';
            _isLoading = false;
          });
          return;
        }

        // 获取关注用户的ID列表
        final followsResponse = await _postService.fetchFollowingPosts();
        if (followsResponse.isEmpty) {
          setState(() {
            _posts.clear();
            _hasMore = false;
            _error = null;
            _isLoading = false;
          });
          return;
        }

        final followingIds = followsResponse
            .map((post) => post['author_id'] as String)
            .toSet()
            .toList();

        // 使用自定义查询获取关注用户的群岛帖子
        result = await _fetchFollowIslandPosts(
          followingIds,
          limit: _pageSize,
          offset: (isRefresh ? 0 : _currentPage - 1) * _pageSize,
        );
      }

      if (kDebugMode) {
        debugPrint('成功加载 ${result.length} 条帖子');
      }

      setState(() {
        if (isRefresh) {
          _posts.clear();
        }
        _posts.addAll(result);
        _hasMore = result.length >= _pageSize;
        _error = null;
      });
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('加载群岛帖子出错: $e');
        debugPrint('错误堆栈: $stack');
      }
      setState(() {
        _error = '加载失败: ${e.toString()}';
        if (isRefresh) {
          _posts.clear();
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMore) return;

    try {
      setState(() {
        _isLoadingMore = true;
      });

      _currentPage++;

      List<Map<String, dynamic>> result;

      if (_selectedTopTab == 0) {
        final String? islandType = _selectedType == '全部' ? null : _selectedType;
        result = await _postService.fetchIslandPosts(
          islandType: islandType,
          limit: _pageSize,
          offset: (_currentPage - 1) * _pageSize,
        );
      } else {
        // 关注标签：获取关注用户的群岛帖子
        if (!_authService.isLoggedIn) {
          return;
        }

        final userId = _authService.currentUser?.id;
        if (userId == null) return;

        // 获取关注用户的ID列表
        final followsResponse = await _postService.fetchFollowingPosts();
        if (followsResponse.isEmpty) {
          setState(() {
            _hasMore = false;
            _isLoadingMore = false;
          });
          return;
        }

        final followingIds = followsResponse
            .map((post) => post['author_id'] as String)
            .toSet()
            .toList();

        // 使用自定义查询获取关注用户的群岛帖子
        result = await _fetchFollowIslandPosts(
          followingIds,
          limit: _pageSize,
          offset: (_currentPage - 1) * _pageSize,
        );
      }

      setState(() {
        _posts.addAll(result);
        _hasMore = result.length >= _pageSize;
      });
    } catch (e) {
      _currentPage--; // 加载失败，回退页码
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载更多失败: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  // 自定义方法：获取关注用户的群岛帖子
  Future<List<Map<String, dynamic>>> _fetchFollowIslandPosts(
    List<String> followingIds, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('开始获取关注用户的群岛帖子，关注用户数: ${followingIds.length}, limit=$limit, offset=$offset');
      }

      // 使用PostService的client直接查询
      final client = AppSupabaseClient().client;
      
      final response = await client
          .from('posts')
          .select('''
            id, channel, title, content, island_type, created_at,
            comment_count, view_count, author_id,
            author:profiles!posts_author_id_fkey(id, nickname, avatar_url),
            post_media(media_url, media_type, sort_order)
          ''')
          .eq('channel', 'island')  // 只获取群岛帖子
          .eq('is_deleted', false)
          .eq('status', 'normal')
          .inFilter('author_id', followingIds)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      if (kDebugMode) {
        debugPrint('成功获取 ${(response as List).length} 条关注用户的群岛帖子');
      }

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('获取关注用户的群岛帖子失败: $e');
      }
      throw Exception('加载关注内容失败: ${e.toString()}');
    }
  }

  // 自定义方法：获取关注用户的COS帖子
  Future<List<Map<String, dynamic>>> _fetchFollowCosPosts(
    List<String> followingIds, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('开始获取关注用户的COS帖子，关注用户数: ${followingIds.length}, limit=$limit, offset=$offset');
      }

      // 使用PostService的client直接查询
      final client = AppSupabaseClient().client;
      
      final response = await client
          .from('posts')
          .select('''
            id, channel, title, content, island_type, created_at,
            comment_count, view_count, author_id,
            author:profiles!posts_author_id_fkey(id, nickname, avatar_url),
            post_media(media_url, media_type, sort_order)
          ''')
          .eq('channel', 'cos')  // 只获取COS帖子
          .eq('is_deleted', false)
          .eq('status', 'normal')
          .inFilter('author_id', followingIds)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      if (kDebugMode) {
        debugPrint('成功获取 ${(response as List).length} 条关注用户的COS帖子');
      }

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('获取关注用户的COS帖子失败: $e');
      }
      throw Exception('加载关注内容失败: ${e.toString()}');
    }
  }

  // 自定义方法：获取关注用户的全部帖子（COS + 群岛）
  Future<List<Map<String, dynamic>>> _fetchFollowAllPosts(
    List<String> followingIds, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('开始获取关注用户的全部帖子，关注用户数: ${followingIds.length}, limit=$limit, offset=$offset');
      }

      // 使用PostService的client直接查询
      final client = AppSupabaseClient().client;
      
      final response = await client
          .from('posts')
          .select('''
            id, channel, title, content, island_type, created_at,
            comment_count, view_count, author_id,
            author:profiles!posts_author_id_fkey(id, nickname, avatar_url),
            post_media(media_url, media_type, sort_order)
          ''')
          .inFilter('channel', ['cos', 'island'])  // 获取COS和群岛帖子
          .eq('is_deleted', false)
          .eq('status', 'normal')
          .inFilter('author_id', followingIds)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      if (kDebugMode) {
        debugPrint('成功获取 ${(response as List).length} 条关注用户的全部帖子');
      }

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('获取关注用户的全部帖子失败: $e');
      }
      throw Exception('加载关注内容失败: ${e.toString()}');
    }
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

  Widget _buildislandTypesButtons(){
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AnimeColors.cardWhite,
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _islandTypes.length,
        separatorBuilder: (context, index) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final typeData = _islandTypes[index];
          final type = typeData['type'] as String;
          final isSelected = _selectedType == type;

          return GestureDetector(
            onTap: () {
              if (!isSelected) {
                _scrollToTop();
                _loadPosts(type: type, isRefresh: true);
              }
            },
            child: Container(
              constraints: const BoxConstraints(
                minWidth: 20,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    type,
                    style: TextStyle(
                      color: isSelected ? AnimeColors.primaryPink : AnimeColors.textLight,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: isSelected ? 16 : 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 底部指示器
                  Container(
                    height: 3,
                    width: 24,
                    decoration: BoxDecoration(
                      color: isSelected ? AnimeColors.primaryPink : Colors.transparent,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 构建加载更多指示器 - 增强二次元风格
  Widget _buildLoadMoreIndicator() {
    if (!_hasMore && _posts.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Text(
              '已经到底了～',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return _isLoadingMore
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFED7099).withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFED7099).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFED7099)),
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '加载中...',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        : const SizedBox.shrink();
  }

  // 回到顶部
  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // 构建顶部导航栏 - 增强二次元风格
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
            Tab(text: '全部'),
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
      ],
    );
  }

// 处理发布按钮点击（添加登录检查）
Future<void> _handlePublishButtonTap() async {
  // 1. 首先检查用户是否登录
  final uid = _authService.currentUser?.id;
  if (uid == null) {
    // 用户未登录，显示提示
    if (mounted) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('需要登录'),
          shape: RoundedRectangleBorder( // 添加这一行
          borderRadius: BorderRadius.circular(18), // 设置圆角半径
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
                // 跳转到登录页面
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

  // 2. 用户已登录，显示频道选择
  showChannelSelectionBottomSheet();
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
              initialChildSize: 0.55, // 增加初始高度到55%
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

  // 构建空状态 - 增强二次元风格
  Widget _buildEmptyState() {
    String title;
    String subtitle;
    
    if (_selectedTopTab == 0) {
      // 全部标签
      title = _selectedType == '全部' ? '暂无群岛帖子' : '暂无$_selectedType类型的帖子';
      subtitle = '快来发布第一条帖子吧～';
    } else {
      // 关注标签
      if (!_authService.isLoggedIn) {
        title = '请先登录查看关注内容';
        subtitle = '登录后可以查看你关注的用户发布的帖子';
      } else {
        title = '暂无关注的用户发布的帖子';
        subtitle = '关注更多用户，发现更多精彩内容';
      }
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.grey[200]!,
                width: 2,
              ),
            ),
            child: Icon(
              _selectedTopTab == 0 ? Icons.forum_outlined : Icons.people_outline,
              size: 48,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => _loadPosts(isRefresh: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 2,
            ),
            child: const Text(
              '重新加载',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建单列布局
  Widget _buildSingleColumnLayout() {
    return RefreshIndicator(
      onRefresh: () => _loadPosts(isRefresh: true),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: PostCard(
                      post: _posts[index],
                      isLeftColumn: true, // 保持原有参数，但现在是单列
                    ),
                  );
                },
                childCount: _posts.length,
              ),
            ),
          ),
          // 加载更多指示器
          SliverToBoxAdapter(
            child: _buildLoadMoreIndicator(),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      backgroundColor: AnimeColors.backgroundLight,// 背景颜色
      body: Column(
        children: [
          // 二级筛选按钮 - 只在全部标签显示群岛类型筛选
          if (_selectedTopTab == 0) 
            _buildislandTypesButtons(),
          const SizedBox(height: 8),
          // 帖子列表
          Expanded(
            child: _isLoading
                ? const LoadingView()
                : _error != null
                    ? ErrorView(
                        error: _error!,
                        onRetry: () => _loadPosts(isRefresh: true))
                    : _posts.isEmpty
                        ? _buildEmptyState()
                        : _buildSingleColumnLayout(),
          ),
        ],
      ),
      // 右下角悬浮发布按钮
      floatingActionButton: FloatingActionButton(
        onPressed: _handlePublishButtonTap,
        backgroundColor: AnimeColors.primaryPink,
        foregroundColor: Colors.white,
        elevation: 4,
        mini:  true,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
