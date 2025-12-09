import 'package:flutter/material.dart';
import 'package:iacg/features/profile/following_list_page.dart';
import 'package:iacg/features/root/root_shell.dart';
import '../../models/user_profile.dart';
import '../../services/profile_service.dart';
import 'edit_profile_page.dart';
import 'my_posts_tab.dart';
import 'my_island_tab.dart';
import 'my_favorites_tab.dart';
import 'my_collab_tab.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage>
    with SingleTickerProviderStateMixin {
  final ProfileService _profileService = ProfileService();
  UserProfile? _profile;
  Map<String, int>? _stats;
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _currentSearchQuery = '';

  // 新增：控制搜索框显示状态
  bool _showSearchField = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _profile == null) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final profile = await _profileService.fetchMyProfile();
      if (profile == null) {
        throw Exception('无法获取用户信息');
      }
      final stats = await _profileService.fetchUserStats(profile.id);
      setState(() {
        _profile = profile;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出登录吗?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '退出',
              style: TextStyle(color: Color(0xFFED7099)),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFED7099)),
          ),
        ),
      );

      await _profileService.signOut();

      if (!mounted) return;
      Navigator.pop(context);

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const RootShell(),
        ),
            (route) => false,
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('退出失败: $e')),
        );
      }
    }
  }

  void _performSearch(String query) {
    setState(() {
      _currentSearchQuery = query;
    });

    // 根据当前选中的tab类型和搜索词执行搜索
    if (query.isEmpty) {
      // 清空搜索词，显示所有内容
      return;
    }

    // 在这里可以根据需要添加搜索逻辑
    // 例如：可以调用API搜索，或者本地过滤数据
    _notifyCurrentTabOfSearch(query);
  }

  void _notifyCurrentTabOfSearch(String query) {
    // 这里可以通知当前选中的tab进行搜索
    // 实际搜索逻辑在各个tab中实现
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _currentSearchQuery = '';
      _showSearchField = false;
    });
    // 清空搜索后，通知tab显示所有内容
    _notifyCurrentTabOfSearch('');
    // 收起键盘
    FocusScope.of(context).unfocus();
  }

  void _onSearchSubmitted(String value) {
    if (value.trim().isNotEmpty) {
      // 执行搜索
      _performSearch(value.trim());
      // 收起键盘
      FocusScope.of(context).unfocus();
    }
  }

  void _toggleSearchField() {
    setState(() {
      _showSearchField = !_showSearchField;
      if (!_showSearchField) {
        _searchController.clear();
        _currentSearchQuery = '';
        _notifyCurrentTabOfSearch('');
      }
    });

    if (_showSearchField) {
      // 延迟一点让搜索框显示后自动聚焦
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          FocusScope.of(context).requestFocus(FocusNode());
          FocusScope.of(context).requestFocus(_searchController.selection.extentOffset == 0 ? _searchController.selection.baseOffset == 0 ? FocusNode() : null : null);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFED7099)),
          ),
        ),
      );
    }

    if (_error != null || _profile == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Color(0xFFED7099)),
              const SizedBox(height: 16),
              Text(
                '加载失败: $_error',
                style: const TextStyle(color: Color(0xFFED7099)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              pinned: true,
              floating: false,
              snap: false,
              expandedHeight: 400,
              backgroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildProfileHeader(),
                collapseMode: CollapseMode.parallax,
              ),
              title: const SizedBox.shrink(),
              centerTitle: false,
              elevation: 0,
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(_showSearchField ? 96 : 48),
                child: _buildTabBarWithSearch(),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            MyPostsTab(userId: _profile!.id, searchQuery: _currentSearchQuery),
            MyIslandTab(userId: _profile!.id, searchQuery: _currentSearchQuery),
            MyFavoritesTab(userId: _profile!.id, searchQuery: _currentSearchQuery),
            MyCollabTab(userId: _profile!.id, searchQuery: _currentSearchQuery),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBarWithSearch() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // TabBar和搜索图标在一行
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // TabBar部分 - 占据大部分空间
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFFED7099),
                    labelColor: const Color(0xFFED7099),
                    unselectedLabelColor: Colors.grey[600],
                    indicatorSize: TabBarIndicatorSize.label,
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                    tabs: const [
                      Tab(text: '作品'),
                      Tab(text: '群岛'),
                      Tab(text: '收藏'),
                      Tab(text: '共创'),
                    ],
                    isScrollable: true,
                  ),
                ),

                // 搜索图标按钮 - 右侧
                IconButton(
                  icon: Icon(
                    _showSearchField ? Icons.close : Icons.search,
                    color: _showSearchField ? const Color(0xFFED7099) : Colors.grey[600],
                    size: 22,
                  ),
                  onPressed: _toggleSearchField,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
              ],
            ),
          ),

          // 搜索框区域（展开/收起动画）
          if (_showSearchField)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(Icons.search, color: const Color(0xFFED7099), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: _getSearchHintText(),
                          hintStyle: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 13),
                        onChanged: _performSearch,
                        onSubmitted: _onSearchSubmitted,
                      ),
                    ),
                    if (_currentSearchQuery.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.close, size: 18, color: Colors.grey[600]),
                        onPressed: _clearSearch,
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                      ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),

          // 分隔线
          Container(
            height: 1,
            color: Colors.grey[100],
          ),
        ],
      ),
    );
  }

  String _getSearchHintText() {
    switch (_tabController.index) {
      case 0:
        return '搜索作品...';
      case 1:
        return '搜索群岛...';
      case 2:
        return '搜索收藏...';
      case 3:
        return '搜索共创...';
      default:
        return '搜索...';
    }
  }

  Widget _buildProfileHeader() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头像和基本信息行
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头像
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: _profile!.avatarUrl != null
                        ? Image.network(
                      _profile!.avatarUrl!,
                      fit: BoxFit.cover,
                    )
                        : Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: Text(
                          _profile!.nickname.isNotEmpty ? _profile!.nickname[0] : '?',
                          style: const TextStyle(
                            fontSize: 28,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // 昵称、ID和编辑资料按钮
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _profile!.nickname,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${_profile!.id}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 编辑资料和退出按钮在一行
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditProfilePage(profile: _profile!),
                                  ),
                                );
                                if (result == true) {
                                  _loadData();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFFED7099),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: Color(0xFFED7099)),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                elevation: 0,
                              ),
                              child: const Text(
                                '编辑资料',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 56,
                            child: ElevatedButton(
                              onPressed: _handleSignOut,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: Colors.red),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                elevation: 0,
                              ),
                              child: const Icon(Icons.logout, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 统计数据行
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('作品', _stats?['posts'] ?? 0),
                _buildStatItem('关注', _stats?['following'] ?? 0),
                _buildStatItem('粉丝', _stats?['followers'] ?? 0),
              ],
            ),
            const SizedBox(height: 10),

            // 个人简介
            if (_profile!.bio != null && _profile!.bio!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '个人简介',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xffF8F9FA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _profile!.bio!,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),

            // 地标信息
            if (_profile!.city != null)
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: const Color(0xFFED7099)),
                  const SizedBox(width: 6),
                  Text(
                    _profile!.city!,
                    style: const TextStyle(
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count) {
    return GestureDetector(
      onTap: () {
        if (label == '关注') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FollowingListPage(userId: _profile!.id),
            ),
          );
        } else if (label == '粉丝') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FollowersListPage(userId: _profile!.id),
            ),
          );
        }
      },
      child: Column(
        children: [
          Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}