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

  // 修改为三个选项：全部、作品、群岛
  final List<String> _filterTypes = ['全部', '作品', '群岛'];
  String _selectedType = '全部';

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

  // 根据筛选类型过滤帖子
  List<Map<String, dynamic>> _filterPosts(List<Map<String, dynamic>> posts) {
    if (_selectedType == '作品') {
      // 只显示COS帖子
      return posts.where((post) => post['channel'] == 'cos').toList();
    } else if (_selectedType == '群岛') {
      // 只显示群岛帖子
      return posts.where((post) => post['channel'] == 'island').toList();
    }
    // 全部：显示所有帖子（COS + 群岛）
    return posts;
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

      // 一次性获取所有关注帖子
      final result = await _postService.fetchFollowingPosts();

      setState(() {
        _allPosts.clear();
        _displayPosts.clear();
        _allPosts.addAll(result);

        // 根据筛选类型过滤帖子
        final filteredPosts = _filterPosts(_allPosts);

        // 初始显示第一页
        _currentDisplayCount = _pageSize;
        if (filteredPosts.length <= _pageSize) {
          _displayPosts.addAll(filteredPosts);
        } else {
          _displayPosts.addAll(filteredPosts.sublist(0, _pageSize));
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
    // 根据筛选类型获取过滤后的帖子
    final filteredPosts = _filterPosts(_allPosts);

    if (_isLoadingMore || _currentDisplayCount >= filteredPosts.length) return;

    setState(() {
      _isLoadingMore = true;
    });

    // 模拟异步加载
    Future.delayed(const Duration(milliseconds: 500), () {
      final nextCount = _currentDisplayCount + _pageSize;
      final endIndex =
          nextCount > filteredPosts.length ? filteredPosts.length : nextCount;

      setState(() {
        _displayPosts
            .addAll(filteredPosts.sublist(_currentDisplayCount, endIndex));
        _currentDisplayCount = endIndex;
        _isLoadingMore = false;
      });
    });
  }

  // 构建加载更多指示器
  Widget _buildLoadMoreIndicator() {
    final filteredPosts = _filterPosts(_allPosts);

    if (_currentDisplayCount >= filteredPosts.length &&
        _displayPosts.isNotEmpty) {
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

  // 构建二级筛选按钮
  Widget _buildFilterButtons() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int index = 0; index < _filterTypes.length; index++) ...[
              if (index > 0) const SizedBox(width: 50), // 按钮之间间隔
              _buildFilterButton(_filterTypes[index]),
            ],
          ],
        ),
      ),
    );
  }

  // 构建单个筛选按钮
  Widget _buildFilterButton(String type) {
    final isSelected = _selectedType == type;

    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          setState(() {
            _selectedType = type;
            // 重新筛选并显示帖子
            _displayPosts.clear();
            final filteredPosts = _filterPosts(_allPosts);
            _currentDisplayCount = _pageSize;
            if (filteredPosts.length <= _pageSize) {
              _displayPosts.addAll(filteredPosts);
            } else {
              _displayPosts.addAll(filteredPosts.sublist(0, _pageSize));
            }
          });
        }
      },
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 80,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              type,
              style: TextStyle(
                color: isSelected ? Color(0xFFED7099) : Color(0xFF666666),
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
                color: isSelected ? Color(0xFFED7099) : Colors.transparent,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 自定义关注空状态
  Widget _buildFollowingEmptyView() {
    String title;
    String subtitle;

    if (_selectedType == '作品') {
      title = '关注的用户还没有发布COS作品';
      subtitle = '关注更多COS创作者，发现更多精彩作品';
    } else if (_selectedType == '群岛') {
      title = '关注的用户还没有发布群岛内容';
      subtitle = '关注更多群岛创作者，发现更多精彩内容';
    } else {
      title = '还没有关注任何人\n快去发现有趣的创作者吧！';
      subtitle = '';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
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

  // 构建内容
  Widget _buildContent() {
    if (_isLoading) return const LoadingView();
    if (_error != null) {
      return ErrorView(
        error: _error!,
        onRetry: _loadAllFollowingPosts,
      );
    }
    if (_displayPosts.isEmpty) {
      return _buildFollowingEmptyView();
    }

    return Column(
      children: [
        // 二级筛选按钮
        _buildFilterButtons(),
        const SizedBox(height: 8),
        // 帖子列表
        Expanded(
          child: RefreshIndicator(
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
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 未登录状态
    if (!_authService.isLoggedIn) {
      return _buildNotLoggedInView();
    }

    return Column(
      children: [
        // 二级筛选按钮 - 全部、作品、群岛
        _buildFilterButtons(),
        const SizedBox(height: 8),
        // 帖子列表
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }
}
