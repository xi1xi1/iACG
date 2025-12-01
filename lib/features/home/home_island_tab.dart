import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iacg/widgets/post_card.dart';
import '../../services/post_service.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';
import 'package:iacg/features/post/post_compose_page.dart';
import 'package:iacg/features/search/search_page.dart';
import '../../services/auth_service.dart';

class HomeIslandTab extends StatefulWidget {
  const HomeIslandTab({super.key});

  @override
  State<HomeIslandTab> createState() => _HomeIslandTabState();
}

class _HomeIslandTabState extends State<HomeIslandTab> {
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
    _scrollController.addListener(_scrollListener);
    _loadPosts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMorePosts();
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
        debugPrint('开始加载群岛帖子，类型: $_selectedType, 页码: $_currentPage');
      }

      // 使用真实的群岛帖子数据
      final String? islandType = _selectedType == '全部' ? null : _selectedType;
      final result = await _postService.fetchIslandPosts(
        islandType: islandType,
        limit: _pageSize,
        offset: (isRefresh ? 0 : _currentPage - 1) * _pageSize,
      );

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

      final String? islandType = _selectedType == '全部' ? null : _selectedType;
      final result = await _postService.fetchIslandPosts(
        islandType: islandType,
        limit: _pageSize,
        offset: (_currentPage - 1) * _pageSize,
      );

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
                    color: const Color(0xFF8B5CF6).withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
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
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
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
                  hintStyle: TextStyle(color: AnimeColors.textLight),
                  border: InputBorder.none,
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
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
    );
  }

  // 构建类型筛选器 - 修改为首页样式
  Widget _buildTypeFilter() {
    return Container(
      height: 48,
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
                minWidth: 60,
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

  // 构建空状态 - 增强二次元风格
  Widget _buildEmptyState() {
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
              Icons.forum_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _selectedType == '全部' ? '暂无群岛帖子' : '暂无$_selectedType类型的帖子',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '快来发布第一条帖子吧～',
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
          // 类型筛选器
          _buildTypeFilter(),
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
      // 浮动回到顶部按钮
      floatingActionButton: _scrollController.hasClients && 
          _scrollController.offset > 300
          ? FloatingActionButton(
              onPressed: _scrollToTop,
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              elevation: 4,
              child: const Icon(Icons.arrow_upward_rounded),
            )
          : null,
    );
  }
}
