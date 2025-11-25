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
  final int _pageSize = 10;

  // 群岛类型选项 - 只显示数据库中实际存在的类型
  final List<String> _islandTypes = ['全部', '求助', '分享', '吐槽', '找搭子', '约拍', '其他'];

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

  // 构建加载更多指示器
  Widget _buildLoadMoreIndicator() {
    if (!_hasMore && _posts.isNotEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            '已经到底了～',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return _isLoadingMore
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(),
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

  // 构建顶部导航栏
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
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
    );
  }

  // 构建类型筛选器
  Widget _buildTypeFilter() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _islandTypes.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final type = _islandTypes[index];
          final isSelected = _selectedType == type;

          return GestureDetector(
            onTap: () {
              if (!isSelected) {
                _scrollToTop();
                _loadPosts(type: type, isRefresh: true);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                type,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.forum_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            _selectedType == '全部' ? '暂无群岛帖子' : '暂无$_selectedType类型的帖子',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _loadPosts(isRefresh: true),
            child: const Text('重新加载'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
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
                        : RefreshIndicator(
                            onRefresh: () => _loadPosts(isRefresh: true),
                            child: ListView.builder(
                              controller: _scrollController,
                              itemCount: _posts.length + 1,
                              itemBuilder: (context, index) {
                                if (index == _posts.length) {
                                  return _buildLoadMoreIndicator();
                                }
                                return PostCard(post: _posts[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
