/* import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../services/profile_service.dart';
import '../../services/message_service.dart';
import '../../widgets/avatar_widget.dart';
import 'my_posts_tab.dart';
import 'my_collab_tab.dart';
import 'my_island_tab.dart';
import '../messages/chat_page.dart';
import 'following_list_page.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;
  const UserProfilePage({super.key, required this.userId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage>
    with SingleTickerProviderStateMixin {
  final ProfileService _profileService = ProfileService();
  final MessageService _messageService = MessageService();

  UserProfile? _profile;
  Map<String, int>? _stats;
  bool _isFollowing = false;
  bool _isLoading = true;
  String? _error;

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _currentSearchQuery = '';
  bool _showSearchField = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    print('🔄 开始加载用户数据: ${widget.userId}');

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profile = await _profileService.fetchUserProfile(widget.userId);
      print('✅ 获取到用户资料: ${profile?.nickname}');

      if (profile == null) {
        throw Exception('用户不存在');
      }

      final results = await Future.wait([
        _profileService.fetchUserStats(widget.userId),
        _profileService.isFollowing(widget.userId),
      ]).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('⚠️ 获取数据超时,使用默认值');
          return [
            {'posts': 0, 'following': 0, 'followers': 0},
            false,
          ];
        },
      );

      final stats = results[0] as Map<String, int>;
      final isFollowing = results[1] as bool;

      print('✅ 数据加载完成');

      if (mounted) {
        setState(() {
          _profile = profile;
          _stats = stats;
          _isFollowing = isFollowing;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('❌ 加载数据失败: $e');
      print('堆栈跟踪: $stackTrace');

      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    try {
      if (_isFollowing) {
        await _profileService.unfollowUser(widget.userId);
      } else {
        await _profileService.followUser(widget.userId);
      }

      setState(() {
        _isFollowing = !_isFollowing;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isFollowing ? '已关注' : '已取消关注'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('❌ 关注操作失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  Future<void> _startChat() async {
    try {
      print('🔄 创建会话中...');

      final conversation = await _messageService.getOrCreateConversation(
        widget.userId,
      );

      print('✅ 会话创建成功: ${conversation.id}');

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(conversation: conversation),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ 打开聊天失败: $e');
      print('堆栈跟踪: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开聊天失败: $e')),
        );
      }
    }
  }

  void _performSearch(String query) {
    setState(() {
      _currentSearchQuery = query;
    });

    if (query.isEmpty) {
      return;
    }

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
    _notifyCurrentTabOfSearch('');
    FocusScope.of(context).unfocus();
  }

  void _onSearchSubmitted(String value) {
    if (value.trim().isNotEmpty) {
      _performSearch(value.trim());
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
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          FocusScope.of(context).requestFocus(FocusNode());
          FocusScope.of(context)
              .requestFocus(_searchController.selection.extentOffset == 0
                  ? _searchController.selection.baseOffset == 0
                      ? FocusNode()
                      : null
                  : null);
        }
      });
    }
  }

  String _getSearchHintText() {
    switch (_tabController.index) {
      case 0:
        return '搜索作品...';
      case 1:
        return '搜索群岛...';
      case 2:
        return '搜索共创...';
      default:
        return '搜索...';
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
              const Icon(Icons.error_outline,
                  size: 64, color: Color(0xFFED7099)),
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
              title: AnimatedOpacity(
                opacity: innerBoxIsScrolled ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _profile!.nickname,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
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
            MyPostsTab(userId: widget.userId, searchQuery: _currentSearchQuery),
            MyIslandTab(
                userId: widget.userId, searchQuery: _currentSearchQuery),
            MyCollabTab(
                userId: widget.userId, searchQuery: _currentSearchQuery),
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
                      Tab(text: '共创'),
                    ],
                    isScrollable: true,
                  ),
                ),

                // 搜索图标按钮 - 右侧
                IconButton(
                  icon: Icon(
                    _showSearchField ? Icons.close : Icons.search,
                    color: _showSearchField
                        ? const Color(0xFFED7099)
                        : Colors.grey[600],
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
                    Icon(Icons.search,
                        color: const Color(0xFFED7099), size: 18),
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
                        icon: Icon(Icons.close,
                            size: 18, color: Colors.grey[600]),
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

  Widget _buildProfileHeader() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头像和基本信息行 - 使用个人资料页面的布局
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头像 - 使用 AvatarWidget
                AvatarWidget(
                  imageUrl: _profile!.avatarUrl,
                  size: 80,
                  showBorder: false,
                  semanticsLabel: '${_profile!.nickname}的头像',
                ),
                const SizedBox(width: 16),

                // 昵称、ID和关注/聊天按钮
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 昵称和徽章在一行
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              _profile!.nickname,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 徽章放在昵称右边
                          if (_profile!.isCoser || _profile!.role != 'user')
                            _buildCompactRoleBadges(),
                        ],
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

                      // 关注和聊天按钮在一行
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _toggleFollow,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isFollowing
                                    ? Colors.grey[300]
                                    : const Color(0xFFED7099),
                                foregroundColor: _isFollowing
                                    ? Colors.grey[600]
                                    : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isFollowing ? Icons.check : Icons.add,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isFollowing ? '已关注' : '关注',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 56,
                            child: ElevatedButton(
                              onPressed: _startChat,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFFED7099),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(
                                      color: Color(0xFFED7099)),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                elevation: 0,
                              ),
                              child: const Icon(Icons.message, size: 20),
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
            const SizedBox(height: 16),

            // 个人简介（始终显示，无标题）
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xffF8F9FA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _profile!.bio != null && _profile!.bio!.isNotEmpty
                    ? _profile!.bio!
                    : '这个人很神秘，什么都没有写',
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 地点信息（始终显示）
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 16, color: const Color(0xFFED7099)),
                const SizedBox(width: 6),
                Text(
                  _profile!.city != null && _profile!.city!.isNotEmpty
                      ? _profile!.city!
                      : '未知',
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

  // 紧凑的徽章布局，放在昵称右边
  Widget _buildCompactRoleBadges() {
    List<Widget> badges = [];

    if (_profile!.isCoser) {
      badges.add(_buildCompactRoleBadge(
        'Coser',
        Icons.camera_alt,
        const Color(0xFFED7099),
      ));
      if (_profile!.cosLevel != 'none' &&
          _profile!.displayCosLevel.isNotEmpty) {
        badges.add(const SizedBox(width: 4));
        badges.add(_buildCompactRoleBadge(
          _profile!.displayCosLevel,
          Icons.star,
          const Color(0xFFED7099),
        ));
      }
    } else if (_profile!.role != 'user') {
      badges.add(_buildCompactRoleBadge(
        _profile!.displayRole,
        _getRoleIcon(_profile!.role),
        const Color(0xFFED7099),
      ));
    }

    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: badges,
    );
  }

  // 紧凑的徽章样式
  Widget _buildCompactRoleBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'coser':
        return Icons.camera_alt;
      case 'creator_support':
        return Icons.palette;
      case 'organizer':
        return Icons.event;
      default:
        return Icons.person;
    }
  }
}
 */




import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../services/profile_service.dart';
import '../../services/message_service.dart';
import '../../widgets/avatar_widget.dart';
import 'my_posts_tab.dart';
import 'my_collab_tab.dart';
import 'my_island_tab.dart';
import 'my_events_tab.dart'; // 导入活动tab
import '../messages/chat_page.dart';
import 'following_list_page.dart';
import '../../services/auth_service.dart';
class UserProfilePage extends StatefulWidget {
  final String userId;
  const UserProfilePage({super.key, required this.userId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage>
    with TickerProviderStateMixin {
  final ProfileService _profileService = ProfileService();
  final MessageService _messageService = MessageService();
  final AuthService _authService = AuthService(); 
  UserProfile? _profile;
  Map<String, int>? _stats;
  bool _isFollowing = false;
  bool _isLoading = true;
  String? _error;

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _currentSearchQuery = '';
  bool _showSearchField = false;

  // 判断是否为活动组织者
  bool get _isOrganizer => _profile?.role == 'organizer';
  // 🔥 新增：判断是否是自己的个人主页
  bool get _isMyProfile => _authService.currentUserId == widget.userId;
  // 获取应有的tab数量
  int get _tabCount => _isOrganizer ? 4 : 3;

  @override
  void initState() {
    super.initState();
    // 初始化时先用3个tab
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    print('📄 开始加载用户数据: ${widget.userId}');

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profile = await _profileService.fetchUserProfile(widget.userId);
      print('✅ 获取到用户资料: ${profile?.nickname}, role: ${profile?.role}');

      if (profile == null) {
        throw Exception('用户不存在');
      }

      final results = await Future.wait([
        _profileService.fetchUserStats(widget.userId),
        _profileService.isFollowing(widget.userId),
      ]).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('⚠️ 获取数据超时,使用默认值');
          return [
            {'posts': 0, 'following': 0, 'followers': 0},
            false,
          ];
        },
      );

      final stats = results[0] as Map<String, int>;
      final isFollowing = results[1] as bool;

      print('✅ 数据加载完成');
      print('用户角色: ${profile.role}');
      print('是否为活动组织者: ${profile.role == 'organizer'}');

      // 先保存当前选中的tab索引
      final currentIndex = _tabController.index;
      
      // 检查是否需要更新TabController
      final isOrganizer = profile.role == 'organizer';
      final newLength = isOrganizer ? 4 : 3;
      final needsUpdate = _tabController.length != newLength;
      
      print('当前TabController长度: ${_tabController.length}, 需要的长度: $newLength, 需要更新: $needsUpdate');

      if (mounted) {
        if (needsUpdate) {
          // 需要更新TabController
          final oldController = _tabController;
          _tabController = TabController(
            length: newLength,
            vsync: this,
            initialIndex: currentIndex < newLength ? currentIndex : 0,
          );
          print('✅ TabController已更新，新长度: ${_tabController.length}');
          // 在下一帧dispose旧的controller
          WidgetsBinding.instance.addPostFrameCallback((_) {
            oldController.dispose();
          });
        }
        
        setState(() {
          _profile = profile;
          _stats = stats;
          _isFollowing = isFollowing;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('❌ 加载数据失败: $e');
      print('堆栈跟踪: $stackTrace');

      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    try {
      if (_isFollowing) {
        await _profileService.unfollowUser(widget.userId);
      } else {
        await _profileService.followUser(widget.userId);
      }

      setState(() {
        _isFollowing = !_isFollowing;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isFollowing ? '已关注' : '已取消关注'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('❌ 关注操作失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  Future<void> _startChat() async {
    try {
      print('📄 创建会话中...');

      final conversation = await _messageService.getOrCreateConversation(
        widget.userId,
      );

      print('✅ 会话创建成功: ${conversation.id}');

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(conversation: conversation),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ 打开聊天失败: $e');
      print('堆栈跟踪: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开聊天失败: $e')),
        );
      }
    }
  }

  void _performSearch(String query) {
    setState(() {
      _currentSearchQuery = query;
    });

    if (query.isEmpty) {
      return;
    }

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
    _notifyCurrentTabOfSearch('');
    FocusScope.of(context).unfocus();
  }

  void _onSearchSubmitted(String value) {
    if (value.trim().isNotEmpty) {
      _performSearch(value.trim());
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
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          FocusScope.of(context).requestFocus(FocusNode());
        }
      });
    }
  }

  String _getSearchHintText() {
    switch (_tabController.index) {
      case 0:
        return '搜索作品...';
      case 1:
        return '搜索群岛...';
      case 2:
        return '搜索共创...';
      case 3:
        return '搜索活动...';
      default:
        return '搜索...';
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
              const Icon(Icons.error_outline,
                  size: 64, color: Color(0xFFED7099)),
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
              title: AnimatedOpacity(
                opacity: innerBoxIsScrolled ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _profile!.nickname,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
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
            MyPostsTab(userId: widget.userId, searchQuery: _currentSearchQuery),
            MyIslandTab(
                userId: widget.userId, searchQuery: _currentSearchQuery),
            MyCollabTab(
                userId: widget.userId, searchQuery: _currentSearchQuery),
            // 如果是活动组织者，添加活动tab
            if (_isOrganizer)
              MyEventsTab(userId: widget.userId, searchQuery: _currentSearchQuery),
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
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
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
                    tabs: [
                      const Tab(text: '作品'),
                      const Tab(text: '群岛'),
                      const Tab(text: '共创'),
                      // 如果是活动组织者，显示活动tab
                      if (_isOrganizer) const Tab(text: '活动'),
                    ],
                    isScrollable: true,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _showSearchField ? Icons.close : Icons.search,
                    color: _showSearchField
                        ? const Color(0xFFED7099)
                        : Colors.grey[600],
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
                    Icon(Icons.search,
                        color: const Color(0xFFED7099), size: 18),
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
                        icon: Icon(Icons.close,
                            size: 18, color: Colors.grey[600]),
                        onPressed: _clearSearch,
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                      ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          Container(
            height: 1,
            color: Colors.grey[100],
          ),
        ],
      ),
    );
  }

// 🔥 新增：构建自己个人主页的按钮（只有禁用的私信按钮）
Widget _buildMyProfileButtons() {
  return SizedBox(
    height: 40,
    child: ElevatedButton(
      onPressed: () {
        // 点击时显示提示
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('不能给自己发私信'),
            duration: Duration(seconds: 1),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[200], // 灰色背景表示禁用
        foregroundColor: Colors.grey[500], // 灰色文字
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[300]!),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        elevation: 0,
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.message, size: 20),
          SizedBox(width: 6),
          Text(
            '私信',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

// 🔥 新增：构建他人个人主页的按钮（关注和私信按钮）
Widget _buildOtherProfileButtons() {
  return Row(
    children: [
      Expanded(
        child: ElevatedButton(
          onPressed: _toggleFollow,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isFollowing
                ? Colors.grey[300]
                : const Color(0xFFED7099),
            foregroundColor: _isFollowing
                ? Colors.grey[600]
                : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isFollowing ? Icons.check : Icons.add,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                _isFollowing ? '已关注' : '关注',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 12),
      SizedBox(
        width: 56,
        child: ElevatedButton(
          onPressed: _startChat,
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
          child: const Icon(Icons.message, size: 20),
        ),
      ),
    ],
  );
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AvatarWidget(
                  imageUrl: _profile!.avatarUrl,
                  size: 80,
                  showBorder: false,
                  semanticsLabel: '${_profile!.nickname}的头像',
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              _profile!.nickname,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_profile!.isCoser || _profile!.role != 'user')
                            _buildCompactRoleBadges(),
                        ],
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
                        // 🔥 修改按钮逻辑
                       _isMyProfile 
                      ? _buildMyProfileButtons() // 自己的个人主页
                      : _buildOtherProfileButtons(), // 他人的个人主页
                      // Row(
                      //   children: [
                      //     Expanded(
                      //       child: ElevatedButton(
                      //         onPressed: _toggleFollow,
                      //         style: ElevatedButton.styleFrom(
                      //           backgroundColor: _isFollowing
                      //               ? Colors.grey[300]
                      //               : const Color(0xFFED7099),
                      //           foregroundColor: _isFollowing
                      //               ? Colors.grey[600]
                      //               : Colors.white,
                      //           shape: RoundedRectangleBorder(
                      //             borderRadius: BorderRadius.circular(12),
                      //           ),
                      //           padding:
                      //               const EdgeInsets.symmetric(vertical: 10),
                      //           elevation: 0,
                      //         ),
                      //         child: Row(
                      //           mainAxisAlignment: MainAxisAlignment.center,
                      //           children: [
                      //             Icon(
                      //               _isFollowing ? Icons.check : Icons.add,
                      //               size: 18,
                      //             ),
                      //             const SizedBox(width: 6),
                      //             Text(
                      //               _isFollowing ? '已关注' : '关注',
                      //               style: const TextStyle(
                      //                 fontSize: 14,
                      //                 fontWeight: FontWeight.w600,
                      //               ),
                      //             ),
                      //           ],
                      //         ),
                      //       ),
                      //     ),
                      //     const SizedBox(width: 12),
                      //     SizedBox(
                      //       width: 56,
                      //       child: ElevatedButton(
                      //         onPressed: _startChat,
                      //         style: ElevatedButton.styleFrom(
                      //           backgroundColor: Colors.white,
                      //           foregroundColor: const Color(0xFFED7099),
                      //           shape: RoundedRectangleBorder(
                      //             borderRadius: BorderRadius.circular(12),
                      //             side: const BorderSide(
                      //                 color: Color(0xFFED7099)),
                      //           ),
                      //           padding:
                      //               const EdgeInsets.symmetric(vertical: 10),
                      //           elevation: 0,
                      //         ),
                      //         child: const Icon(Icons.message, size: 20),
                      //       ),
                      //     ),
                      //   ],
                      // ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('作品', _stats?['posts'] ?? 0),
                _buildStatItem('关注', _stats?['following'] ?? 0),
                _buildStatItem('粉丝', _stats?['followers'] ?? 0),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xffF8F9FA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _profile!.bio != null && _profile!.bio!.isNotEmpty
                    ? _profile!.bio!
                    : '这个人很神秘,什么都没有写',
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 16, color: const Color(0xFFED7099)),
                const SizedBox(width: 6),
                Text(
                  _profile!.city != null && _profile!.city!.isNotEmpty
                      ? _profile!.city!
                      : '未知',
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

  Widget _buildCompactRoleBadges() {
    List<Widget> badges = [];

    if (_profile!.isCoser) {
      badges.add(_buildCompactRoleBadge(
        'Coser',
        Icons.camera_alt,
        const Color(0xFFED7099),
      ));
      // if (_profile!.cosLevel != 'none' &&
      //     _profile!.displayCosLevel.isNotEmpty) {
      //   badges.add(const SizedBox(width: 4));
      //   badges.add(_buildCompactRoleBadge(
      //     _profile!.displayCosLevel,
      //     Icons.star,
      //     const Color(0xFFED7099),
      //   ));
      // }
    } else if (_profile!.role != 'user') {
      badges.add(_buildCompactRoleBadge(
        _profile!.displayRole,
        _getRoleIcon(_profile!.role),
        const Color(0xFFED7099),
      ));
    }

    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: badges,
    );
  }

  Widget _buildCompactRoleBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'coser':
        return Icons.camera_alt;
      case 'creator_support':
        return Icons.palette;
      case 'organizer':
        return Icons.event;
      default:
        return Icons.person;
    }
  }
}