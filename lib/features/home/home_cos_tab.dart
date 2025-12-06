import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:iacg/services/tag_service.dart';
import 'package:iacg/widgets/post_card.dart';
import '../../services/post_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/loading_view.dart';
import '../../services/profile_service.dart';
import '../../widgets/error_view.dart';
import 'package:iacg/features/post/post_compose_page.dart';
import 'package:iacg/features/search/search_page.dart';
import 'home_page.dart';

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

  // 用户身份状态
  bool _isOrganizer = false;
  bool _loadingUserRole = true;

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
    _checkUserRole();
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

      _loadPosts(isRefresh: true);

      // 如果是"全部"标签，加载IP标签
      if (_tabController.index == 0) {
        _loadIpTags();
      }
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

  Future<void> _loadInitialData() async {
    await _loadPosts(isRefresh: true);
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
        print(isRefresh);
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

  // 构建顶部导航栏 - 二次元风格
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



  // 构建筛选面板（仅全部标签显示）- 增强二次元风格
  Widget _buildFilterPanel() {
    if (_selectedTopTab != 0 || !_showFilterPanel) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F7F7), //背景
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        // boxShadow: [
        //   BoxShadow(
        //     color: AnimeColors.primaryPink.withValues(alpha: 0.15),
        //     blurRadius: 20,
        //     offset: const Offset(0, 4),
        //   ),
        //   BoxShadow(
        //     color: Colors.black.withValues(alpha: 0.1),
        //     blurRadius: 8,
        //     offset: const Offset(0, 2),
        //   ),
        // ],
        // border: Border.all(
        //   color: AnimeColors.primaryPink.withValues(alpha: 0.1),
        //   width: 1,
        // ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 面板标题 - 二次元风格
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AnimeColors.primaryPink,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _currentFilterType == FilterType.category ? '全部类型' : '全部类型',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              // 关闭按钮 - 二次元风格
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AnimeColors.backgroundLight,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AnimeColors.primaryPink.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: IconButton(
                  onPressed: _closeFilterPanel,
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: AnimeColors.primaryPink,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 筛选内容
          _buildFilterOptions(),
          const SizedBox(height: 20),
          // 应用按钮 - 二次元风格
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _applyFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: AnimeColors.primaryPink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                shadowColor: AnimeColors.primaryPink.withValues(alpha: 0.3),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '应用筛选',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
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

  // 构建类型选项 - 增强二次元风格
  Widget _buildCategoryOptions() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
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
              color: isSelected ? AnimeColors.primaryPink : Colors.white,
              borderRadius: BorderRadius.circular(20),
              // border: Border.all(
              //   color: isSelected
              //       ? AnimeColors.primaryPink.withValues(alpha: 0.3)
              //       : AnimeColors.primaryPink.withValues(alpha: 0.2),
              //   width: isSelected ? 0 : 1.5,
              // ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AnimeColors.primaryPink.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: Text(
              category,
              style: TextStyle(
                color: isSelected ? Colors.white : AnimeColors.primaryPink,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                shadows: isSelected
                    ? [
                        const Shadow(
                          blurRadius: 2,
                          color: Colors.black26,
                          offset: Offset(1, 1),
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // 构建 IP 选项 - 增强二次元风格
  Widget _buildIpOptions() {
    return _isLoadingTags
        ? Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AnimeColors.primaryPink.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AnimeColors.primaryPink.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AnimeColors.primaryPink),
                strokeWidth: 2,
              ),
            ),
          )
        : Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              // "全部"选项
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedIp = '全部';
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _selectedIp == '全部' ? AnimeColors.primaryPink : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    // border: Border.all(
                    //   color: _selectedIp == '全部'
                    //       ? AnimeColors.primaryPink.withValues(alpha: 0.3)
                    //       : AnimeColors.primaryPink.withValues(alpha: 0.2),
                    //   width: _selectedIp == '全部' ? 0 : 1.5,
                    // ),
                    boxShadow: _selectedIp == '全部'
                        ? [
                            BoxShadow(
                              color: AnimeColors.primaryPink.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                  ),
                  child: Text(
                    '全部',
                    style: TextStyle(
                      color: _selectedIp == '全部' ? Colors.white : AnimeColors.primaryPink,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      shadows: _selectedIp == '全部'
                          ? [
                              const Shadow(
                                blurRadius: 2,
                                color: Colors.black26,
                                offset: Offset(1, 1),
                              ),
                            ]
                          : null,
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AnimeColors.primaryPink : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      // border: Border.all(
                      //   color: isSelected
                      //       ? AnimeColors.primaryPink.withValues(alpha: 0.3)
                      //       : AnimeColors.primaryPink.withValues(alpha: 0.2),
                      //   width: isSelected ? 0 : 1.5,
                      // ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AnimeColors.primaryPink.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                    ),
                    child: Text(
                      tagName,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AnimeColors.primaryPink,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        shadows: isSelected
                            ? [
                                const Shadow(
                                  blurRadius: 2,
                                  color: Colors.black26,
                                  offset: Offset(1, 1),
                                ),
                              ]
                            : null,
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
      color: Color(0xFFF7F7F7),
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
          color: isActive ? AnimeColors.primaryPink : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? AnimeColors.primaryPink
                : Colors.grey[300]!,
            width: isActive ? 0 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isActive ? 0.2 : 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? Colors.white : AnimeColors.primaryPink,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : AnimeColors.primaryPink,
                shadows: isActive
                    ? [
                        const Shadow(
                          blurRadius: 2,
                          color: Colors.black26,
                          offset: Offset(1, 1),
                        ),
                      ]
                    : null,
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
      backgroundColor: AnimeColors.backgroundLight,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // 筛选按钮
          _buildFilterButtons(),
          // 筛选面板
          _buildFilterPanel(),
          // 筛选状态栏
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
                            onRefresh: () => _loadPosts(isRefresh: true),//下拉刷新
                            child: CustomScrollView(
                              controller: _scrollController,
                              slivers: [
                                // 瀑布流网格 - 优化布局，缩小空隙
                                SliverToBoxAdapter(
                                  child: MasonryGridView.builder(
                                    gridDelegate:
                                        const SliverSimpleGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                    ),
                                    mainAxisSpacing: 4, // 缩小垂直间距
                                    crossAxisSpacing: 4, // 缩小水平间距
                                    padding: const EdgeInsets.all(4), // 缩小整体边距
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    shrinkWrap: true,
                                    itemCount: _posts.length,
                                    itemBuilder: (context, index) {
                                      return PostCard(
                                        post: _posts[index],
                                        isLeftColumn: index.isEven, // 传递列位置信息
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
}

// 筛选类型枚举
enum FilterType {
  none,
  category,
  ip,
}
