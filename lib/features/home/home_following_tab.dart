import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../services/post_service.dart';
import '../../widgets/post_card.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';
import '../../services/auth_service.dart';

class HomeFollowingTab extends StatefulWidget {
  const HomeFollowingTab({super.key});

  @override
  State<HomeFollowingTab> createState() => _HomeFollowingTabState();
}

class _HomeFollowingTabState extends State<HomeFollowingTab> {
  final List<Map<String, dynamic>> _allPosts = []; // 所有关注帖子
  final List<Map<String, dynamic>> _displayPosts = []; // 当前显示的帖子
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  final AuthService _authService = AuthService();

  // 分页相关变量
  final int _pageSize = 10;
  int _currentDisplayCount = 0;

  final ScrollController _scrollController = ScrollController();
  final PostService _postService = PostService();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadAllFollowingPosts();
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
        _currentDisplayCount < _allPosts.length) {
      _loadMorePosts();
    }
  }

  Future<void> _loadAllFollowingPosts() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // 检查用户是否登录
      if (!_authService.isLoggedIn) {
        setState(() {
          _error = '请先登录查看关注内容';
          _isLoading = false;
        });
        return;
      }

      // 一次性获取所有关注帖子（使用原有的 fetchFollowingPosts 方法）
      final result = await _postService.fetchFollowingPosts();

      setState(() {
        _allPosts.clear();
        _displayPosts.clear();
        _allPosts.addAll(result);

        // 初始显示第一页
        _currentDisplayCount = _pageSize;
        if (_allPosts.length <= _pageSize) {
          _displayPosts.addAll(_allPosts);
        } else {
          _displayPosts.addAll(_allPosts.sublist(0, _pageSize));
        }
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _loadMorePosts() {
    if (_isLoadingMore || _currentDisplayCount >= _allPosts.length) return;

    setState(() {
      _isLoadingMore = true;
    });

    // 模拟异步加载
    Future.delayed(const Duration(milliseconds: 500), () {
      final nextCount = _currentDisplayCount + _pageSize;
      final endIndex =
          nextCount > _allPosts.length ? _allPosts.length : nextCount;

      setState(() {
        _displayPosts.addAll(_allPosts.sublist(_currentDisplayCount, endIndex));
        _currentDisplayCount = endIndex;
        _isLoadingMore = false;
      });
    });
  }

  // 构建加载更多指示器
  Widget _buildLoadMoreIndicator() {
    if (_currentDisplayCount >= _allPosts.length && _displayPosts.isNotEmpty) {
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

  // 未登录状态视图
  Widget _buildNotLoggedInView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            '登录后查看关注内容',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushNamed('/login');
            },
            child: const Text('立即登录'),
          ),
        ],
      ),
    );
  }

  // 自定义关注空状态
  Widget _buildFollowingEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            '还没有关注任何人\n快去发现有趣的创作者吧！',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // 可以跳转到发现页面
              // Navigator.of(context).pushNamed('/discover');
            },
            child: const Text('去发现'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 未登录状态
    if (!_authService.isLoggedIn) {
      return _buildNotLoggedInView();
    }

    // 加载状态
    if (_isLoading) return const LoadingView();

    // 错误状态
    if (_error != null) {
      return ErrorView(
        error: _error!,
        onRetry: _loadAllFollowingPosts,
      );
    }

    // 空状态
    if (_displayPosts.isEmpty) {
      return _buildFollowingEmptyView();
    }

    return RefreshIndicator(
      onRefresh: _loadAllFollowingPosts,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 瀑布流网格
          SliverToBoxAdapter(
            child: MasonryGridView.builder(
              gridDelegate:
                  const SliverSimpleGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
              ),
              mainAxisSpacing: 1,
              crossAxisSpacing: 1,
              padding: const EdgeInsets.all(1),
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: _displayPosts.length,
              itemBuilder: (context, index) {
                return PostCard(
                  post: _displayPosts[index],
                );
              },
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
}
