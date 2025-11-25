import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:iacg/services/tag_service.dart';
import 'package:iacg/widgets/post_card.dart';
import '../../services/post_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';
import 'package:iacg/features/post/post_compose_page.dart';
import 'package:iacg/features/search/search_page.dart';

class HomeCosTab extends StatefulWidget {
  const HomeCosTab({super.key});

  @override
  State<HomeCosTab> createState() => _HomeCosTabState();
}

class _HomeCosTabState extends State<HomeCosTab>
    with SingleTickerProviderStateMixin {
  final List<Map<String, dynamic>> _posts = [];
  final List<Map<String, dynamic>> _ipTags = [];
  final TagService _tagService = TagService();
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isLoadingTags = true;
  String? _error;

  // 分页相关变量
  int _currentPage = 1;
  bool _hasMore = true;
  final int _pageSize = 10;

  // 顶部标签：全部、关注
  final List<String> _topTabs = ['全部', '关注'];
  late TabController _tabController;
  int _selectedTopTab = 0;

  // 筛选状态（仅用于"全部"标签）
  String _selectedCategory = '全部';
  String _selectedIp = '全部';

  // 筛选面板状态
  bool _showFilterPanel = false;
  FilterType _currentFilterType = FilterType.none;

  // COS 分类选项
  final List<String> _cosCategories = ['全部', '动漫', '游戏', '漫画', '小说', '其他'];

  final PostService _postService = PostService();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _topTabs.length, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _scrollController.addListener(_scrollListener);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _selectedTopTab = _tabController.index;
        _showFilterPanel = false;
        _currentFilterType = FilterType.none;
        _currentPage = 1;
        _hasMore = true;
      });
      _loadPosts();

      // 如果是"全部"标签，加载IP标签
      if (_tabController.index == 0) {
        _loadIpTags();
      }
    }
  }

  Future<void> _loadInitialData() async {
    await _loadPosts();
    if (_selectedTopTab == 0) {
      await _loadIpTags();
    }
  }

  Future<void> _loadPosts({bool isRefresh = false}) async {
    try {
      setState(() {
        if (isRefresh) {
          _currentPage = 1;
          _hasMore = true;
          _posts.clear();
        }
        _isLoading = true;
        _error = null;
      });

      if (kDebugMode) {
        debugPrint(
            '开始加载COS帖子，标签: ${_topTabs[_selectedTopTab]}, 分类: $_selectedCategory, IP: $_selectedIp, 页码: $_currentPage');
      }

      List<Map<String, dynamic>> result;

      if (_selectedTopTab == 0) {
        // 全部标签：按类型和IP筛选
        final String? cosCategory =
            _selectedCategory == '全部' ? null : _selectedCategory;
        final String? ipTag = _selectedIp == '全部' ? null : _selectedIp;

        result = await _postService.fetchCosPosts(
          category: cosCategory,
          ipTag: ipTag,
          limit: _pageSize,
          offset: (isRefresh ? 0 : _currentPage - 1) * _pageSize,
        );
      } else {
        // 关注标签：获取关注用户的COS帖子
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

        result = await _postService.fetchFollowPosts(
          userId,
          limit: _pageSize,
          offset: (isRefresh ? 0 : _currentPage - 1) * _pageSize,
        );
      }

      if (kDebugMode) {
        debugPrint('加载完成: ${result.length} 条');
      }

      setState(() {
        if (isRefresh) {
          _posts.clear();
        }
        _posts.addAll(result);
        _hasMore = result.length >= _pageSize;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = '加载失败: ${e.toString()}';
        if (isRefresh) {
          _posts.clear();
        }
      });
      if (kDebugMode) {
        debugPrint('COS页面加载错误: $e');
      }
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
        final String? cosCategory =
            _selectedCategory == '全部' ? null : _selectedCategory;
        final String? ipTag = _selectedIp == '全部' ? null : _selectedIp;

        result = await _postService.fetchCosPosts(
          category: cosCategory,
          ipTag: ipTag,
          limit: _pageSize,
          offset: (_currentPage - 1) * _pageSize,
        );
      } else {
        final userId = _authService.currentUser?.id;
        if (userId == null) return;

        result = await _postService.fetchFollowPosts(
          userId,
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

  Future<void> _loadIpTags() async {
    setState(() {
      _isLoadingTags = true;
    });

    try {
      // 按当前所选类型获取 IP；当 _selectedCategory == '全部' 时，
      // TagService 会自动返回"热门 IP"
      final list = await _tagService.fetchIpTagsByCategory(
        categoryZh: _selectedCategory,
        limit: 50,
      );

      // 若该类型暂时没有相关 IP，则退回热门
      final result = (list.isEmpty && _selectedCategory != '全部')
          ? await _tagService.fetchHotIpTags(topN: 50)
          : list;

      setState(() {
        _ipTags
          ..clear()
          ..addAll(result);
        // 切换类型后重置 IP 选择为"全部"
        _selectedIp = '全部';
      });
    } catch (e) {
      // 出错兜底热门
      try {
        final hot = await _tagService.fetchHotIpTags(topN: 50);
        setState(() {
          _ipTags
            ..clear()
            ..addAll(hot);
          _selectedIp = '全部';
        });
      } catch (_) {}
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTags = false;
        });
      }
    }
  }

  // 打开筛选面板（仅全部标签可用）
  void _openFilterPanel(FilterType type) {
    if (_selectedTopTab != 0) return; // 仅全部标签可用

    setState(() {
      _showFilterPanel = true;
      _currentFilterType = type;
    });
  }

  // 关闭筛选面板
  void _closeFilterPanel() {
    setState(() {
      _showFilterPanel = false;
      _currentFilterType = FilterType.none;
    });
  }

  // 应用筛选
  void _applyFilters() {
    _closeFilterPanel();
    _loadPosts(isRefresh: true);
  }

  // 清除所有筛选
  void _clearFilters() {
    setState(() {
      _selectedCategory = '全部';
      _selectedIp = '全部';
    });
    _closeFilterPanel();
    _loadPosts(isRefresh: true);
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

  // 构建顶部导航栏 - 返回 PreferredSizeWidget
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
      bottom: TabBar(
        controller: _tabController,
        tabs: _topTabs.map((tab) => Tab(text: tab)).toList(),
        indicatorColor: Theme.of(context).colorScheme.primary,
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: Colors.grey[600],
        labelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // 构建筛选面板（仅全部标签显示）
  Widget _buildFilterPanel() {
    if (_selectedTopTab != 0 || !_showFilterPanel)
      return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 面板标题
          Row(
            children: [
              Text(
                _currentFilterType == FilterType.category ? '选择类型' : '选择IP',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // 关闭按钮
              IconButton(
                onPressed: _closeFilterPanel,
                icon: const Icon(Icons.close, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 筛选内容
          _buildFilterOptions(),
          const SizedBox(height: 16),
          // 应用按钮
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _applyFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '应用筛选',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建筛选选项
  Widget _buildFilterOptions() {
    if (_currentFilterType == FilterType.category) {
      return _buildCategoryOptions();
    } else {
      return _buildIpOptions();
    }
  }

  // 构建类型选项
  Widget _buildCategoryOptions() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _cosCategories.map((category) {
        final isSelected = _selectedCategory == category;
        return GestureDetector(
          onTap: () {
            if (_selectedCategory == category) return;
            setState(() {
              _selectedCategory = category;
            });
            _loadIpTags();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[300]!,
              ),
            ),
            child: Text(
              category,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // 构建 IP 选项
  Widget _buildIpOptions() {
    return _isLoadingTags
        ? const Center(child: CircularProgressIndicator())
        : Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              // "全部"选项
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedIp = '全部';
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color:
                        _selectedIp == '全部' ? Colors.purple : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _selectedIp == '全部'
                          ? Colors.purple
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: Text(
                    '全部',
                    style: TextStyle(
                      color:
                          _selectedIp == '全部' ? Colors.white : Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              // IP 标签选项
              ..._ipTags.map((tag) {
                final tagName = tag['name'] as String;
                final isSelected = _selectedIp == tagName;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIp = tagName;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.purple : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? Colors.purple : Colors.grey[300]!,
                      ),
                    ),
                    child: Text(
                      tagName,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
  }

  // 构建筛选按钮（仅全部标签显示）
  Widget _buildFilterButtons() {
    if (_selectedTopTab != 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // 类型筛选按钮
          Expanded(
            child: _buildFilterButton(
              label: _selectedCategory == '全部' ? '类型' : _selectedCategory,
              icon: Icons.category_outlined,
              isActive: _selectedCategory != '全部',
              onTap: () => _openFilterPanel(FilterType.category),
            ),
          ),
          const SizedBox(width: 12),
          // IP筛选按钮
          Expanded(
            child: _buildFilterButton(
              label: _selectedIp == '全部' ? 'IP' : _selectedIp,
              icon: Icons.videogame_asset_outlined,
              isActive: _selectedIp != '全部',
              onTap: () => _openFilterPanel(FilterType.ip),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color:
              isActive ? Theme.of(context).colorScheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.white : Colors.grey[700],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // 构建筛选状态显示（仅全部标签显示）
  Widget _buildFilterStatus() {
    if (_selectedTopTab != 0 ||
        (_selectedCategory == '全部' && _selectedIp == '全部')) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[50],
      child: Row(
        children: [
          const Icon(Icons.filter_alt_outlined, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _buildFilterStatusText(),
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _clearFilters,
            child: const Row(
              children: [
                Icon(Icons.clear, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  '清除',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildFilterStatusText() {
    final parts = <String>[];
    if (_selectedCategory != '全部') parts.add('类型: $_selectedCategory');
    if (_selectedIp != '全部') parts.add('IP: $_selectedIp');
    return '已筛选: ${parts.join(' | ')}';
  }

  // 构建空状态
  Widget _buildEmptyState() {
    String message;

    if (_selectedTopTab == 0) {
      // 全部标签的空状态
      if (_selectedCategory != '全部' && _selectedIp != '全部') {
        message = '暂无$_selectedCategory类型的$_selectedIp COS作品';
      } else if (_selectedCategory != '全部') {
        message = '暂无$_selectedCategory类型的COS作品';
      } else if (_selectedIp != '全部') {
        message = '暂无$_selectedIp相关的COS作品';
      } else {
        message = '暂无COS作品';
      }
    } else {
      // 关注标签的空状态
      if (!_authService.isLoggedIn) {
        message = '请先登录查看关注内容';
      } else {
        message = '还没有关注任何人\n快去发现有趣的创作者吧！';
      }
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _selectedTopTab == 0 ? Icons.image_search : Icons.people_outline,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
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
          // 筛选按钮（仅全部标签）
          _buildFilterButtons(),
          // 筛选面板（仅全部标签）
          _buildFilterPanel(),
          // 筛选状态栏（仅全部标签）
          _buildFilterStatus(),
          // 帖子列表 - 双瀑布流
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
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 8,
                                    padding: const EdgeInsets.all(8),
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    shrinkWrap: true,
                                    itemCount: _posts.length,
                                    itemBuilder: (context, index) {
                                      return PostCard(
                                        post: _posts[index],
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
      ),
    );
  }
}

// 筛选类型枚举
enum FilterType {
  none,
  category,
  ip,
}
