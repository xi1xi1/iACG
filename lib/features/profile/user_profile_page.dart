<<<<<<< HEAD
=======
/* // lib/features/profile/user_profile_page.dart
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../services/profile_service.dart';
import '../../services/message_service.dart';
import '../../widgets/avatar_widget.dart';
import 'my_posts_tab.dart';
import 'my_collab_tab.dart';
import '../messages/chat_page.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;
<<<<<<< HEAD
  const UserProfilePage({super.key, required this.userId});
=======
  const UserProfilePage({Key? key, required this.userId}) : super(key: key);

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

  // 🔧 新增：TabController 用于切换作品和共创
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 🔧 新增：初始化 TabController，2个Tab（作品、共创）
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    // 🔧 新增：释放 TabController
    _tabController.dispose();
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
          print('⚠️ 获取数据超时，使用默认值');
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
        if (_stats != null) {
          _stats;
        }
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('用户主页'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null || _profile == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('用户主页'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                '加载失败: $_error',
                textAlign: TextAlign.center,
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
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              pinned: true,
              expandedHeight: 380,
              flexibleSpace: LayoutBuilder(
                builder: (context, constraints) {
                  final scrollPosition = constraints.biggest.height;
                  final isCollapsed = scrollPosition <= MediaQuery.of(context).padding.top + kToolbarHeight;

                  return FlexibleSpaceBar(
                    background: _buildHeader(),
                    title: isCollapsed ? Text(
                      _profile!.nickname,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ) : null,
                    centerTitle: true,
                  );
                },
              ),
              // 🔧 新增：底部 TabBar
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Theme.of(context).primaryColor,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(text: '作品'),
                  Tab(text: '共创'),
                ],
              ),
            ),
          ];
        },
        // 🔧 修改：使用 TabBarView 替换单独的 MyPostsTab
        body: TabBarView(
          controller: _tabController,
          children: [
            MyPostsTab(userId: widget.userId),
            MyCollabTab(userId: widget.userId),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 60),

          AvatarWidget(
            imageUrl: _profile!.avatarUrl,
            size: 90,
            semanticsLabel: '${_profile!.nickname}的头像',
          ),

          const SizedBox(height: 16),

          // 修改为居中显示的昵称和认证标志
          Container(
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center, // 居中显示
              mainAxisSize: MainAxisSize.min, // 自适应内容宽度
              children: [
                Flexible(
                  child: Text(
                    _profile!.nickname,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                if (_profile!.isCoser) ...[
                  const SizedBox(width: 8),
                  // 使用图标替代文字标签
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.pink,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.verified,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (_profile!.bio != null) ...[
            const SizedBox(height: 8),
            Text(
              _profile!.bio!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          if (_profile!.city != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _profile!.city!,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem('作品', _stats?['posts'] ?? 0),
              _buildStatItem('关注', _stats?['following'] ?? 0),
              _buildStatItem('粉丝', _stats?['followers'] ?? 0),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _toggleFollow,
                icon: Icon(_isFollowing ? Icons.check : Icons.add),
                label: Text(_isFollowing ? '已关注' : '关注'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isFollowing ? Colors.grey : null,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _startChat,
                icon: const Icon(Icons.message),
                label: const Text('私信'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
} */





/* // lib/features/profile/user_profile_page.dart
import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../services/profile_service.dart';
import '../../services/message_service.dart';
import '../../widgets/avatar_widget.dart';
import 'my_posts_tab.dart';
import 'my_collab_tab.dart';
import '../messages/chat_page.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;
  const UserProfilePage({Key? key, required this.userId}) : super(key: key);

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

  // 🔧 新增:TabController 用于切换作品和共创
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 🔧 新增:初始化 TabController,2个Tab(作品、共创)
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    // 🔧 新增:释放 TabController
    _tabController.dispose();
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
        if (_stats != null) {
          _stats;
        }
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('用户主页'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null || _profile == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('用户主页'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                '加载失败: $_error',
                textAlign: TextAlign.center,
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
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              pinned: true,
              expandedHeight: 380,
              flexibleSpace: LayoutBuilder(
                builder: (context, constraints) {
                  final scrollPosition = constraints.biggest.height;
                  final isCollapsed = scrollPosition <= MediaQuery.of(context).padding.top + kToolbarHeight;

                  return FlexibleSpaceBar(
                    background: _buildHeader(),
                    title: isCollapsed ? Text(
                      _profile!.nickname,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ) : null,
                    centerTitle: true,
                  );
                },
              ),
              // 🔧 新增:底部 TabBar
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Theme.of(context).primaryColor,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(text: '作品'),
                  Tab(text: '共创'),
                ],
              ),
            ),
          ];
        },
        // 🔧 修改:使用 TabBarView 替换单独的 MyPostsTab
        body: TabBarView(
          controller: _tabController,
          children: [
            MyPostsTab(userId: widget.userId),
            MyCollabTab(userId: widget.userId),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 60),

          AvatarWidget(
            imageUrl: _profile!.avatarUrl,
            size: 90,
            semanticsLabel: '${_profile!.nickname}的头像',
          ),

          const SizedBox(height: 16),

          // 修改为居中显示的昵称和认证标志
          Container(
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center, // 居中显示
              mainAxisSize: MainAxisSize.min, // 自适应内容宽度
              children: [
                Flexible(
                  child: Text(
                    _profile!.nickname,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                if (_profile!.isCoser) ...[
                  const SizedBox(width: 8),
                  // 使用图标替代文字标签
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.pink,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.verified,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),

          // 🔧 新增:角色和等级标签
          _buildRoleBadges(),

          if (_profile!.bio != null) ...[
            const SizedBox(height: 8),
            Text(
              _profile!.bio!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          if (_profile!.city != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _profile!.city!,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem('作品', _stats?['posts'] ?? 0),
              _buildStatItem('关注', _stats?['following'] ?? 0),
              _buildStatItem('粉丝', _stats?['followers'] ?? 0),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _toggleFollow,
                icon: Icon(_isFollowing ? Icons.check : Icons.add),
                label: Text(_isFollowing ? '已关注' : '关注'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isFollowing ? Colors.grey : null,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _startChat,
                icon: const Icon(Icons.message),
                label: const Text('私信'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🔧 新增:构建角色和等级标签
  Widget _buildRoleBadges() {
    List<Widget> badges = [];

    // 如果不是 Coser,显示 role 标签
    if (!_profile!.isCoser && _profile!.role != 'user') {
      badges.add(_buildBadge(
        _profile!.displayRole,
        _getRoleColor(_profile!.role),
        _getRoleIcon(_profile!.role),
      ));
    }

    // 如果是 Coser,显示 Coser 角色标签和等级标签
    if (_profile!.isCoser) {
      // Coser 角色标签
      badges.add(_buildBadge(
        'Coser',
        Colors.pink,
        Icons.camera_alt,
      ));

      // Coser 等级标签(如果有等级)
      if (_profile!.cosLevel != 'none' && _profile!.displayCosLevel.isNotEmpty) {
        badges.add(const SizedBox(width: 8));
        badges.add(_buildBadge(
          _profile!.displayCosLevel,
          Colors.purple,
          Icons.star,
        ));
      }
    }

    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: badges,
      ),
    );
  }

  // 🔧 新增:构建单个标签
  Widget _buildBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // 🔧 新增:获取角色颜色
  Color _getRoleColor(String role) {
    switch (role) {
      case 'coser':
        return Colors.pink;
      case 'creator_support':
        return Colors.blue;
      case 'organizer':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // 🔧 新增:获取角色图标
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

  Widget _buildStatItem(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
} */





// lib/features/profile/user_profile_page.dart
import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../services/profile_service.dart';
import '../../services/message_service.dart';
import '../../widgets/avatar_widget.dart';
import 'my_posts_tab.dart';
import 'my_collab_tab.dart';
import '../messages/chat_page.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;
  const UserProfilePage({Key? key, required this.userId}) : super(key: key);
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

<<<<<<< HEAD
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC4899)),
          ),
        ),
=======
  // 🔥 新增：动态计算 header 高度
  double _calculateHeaderHeight() {
    double baseHeight = 350; // 基础高度
    
    // 如果有角色标签，增加高度
    if (_profile != null) {
      if (_profile!.isCoser) {
        baseHeight += 40;
      }
      if (_profile!.bio != null && _profile!.bio!.isNotEmpty) {
        baseHeight += 20;
      }
    }
    
    return baseHeight;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('用户主页')),
        body: const Center(child: CircularProgressIndicator()),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
      );
    }

    if (_error != null || _profile == null) {
      return Scaffold(
<<<<<<< HEAD
        backgroundColor: Colors.white,
=======
        appBar: AppBar(title: const Text('用户主页')),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
<<<<<<< HEAD
              const Icon(Icons.error_outline, size: 64, color: Color(0xFFEC4899)),
              const SizedBox(height: 16),
              Text(
                '加载失败: $_error',
                style: const TextStyle(color: Color(0xFFEC4899)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('重试'),
              ),
=======
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('加载失败: $_error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadData, child: const Text('重试')),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
            ],
          ),
        ),
      );
    }

    return Scaffold(
<<<<<<< HEAD
      backgroundColor: Colors.white,
=======
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              pinned: true,
<<<<<<< HEAD
              floating: false,
              snap: false,
              expandedHeight: 460,
              stretch: true,
              backgroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildProfileHeader(),
                collapseMode: CollapseMode.parallax,
              ),
              title: _buildAppBarTitle(),
              centerTitle: true,
              forceElevated: true,
              elevation: 0,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFFEC4899),
                    labelColor: const Color(0xFFEC4899),
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
                      Tab(text: '共创'),
                    ],
                  ),
                ),
=======
              // 🔥 修改：增加 expandedHeight 以容纳所有内容
              expandedHeight: _calculateHeaderHeight(),
              flexibleSpace: LayoutBuilder(
                builder: (context, constraints) {
                  final scrollPosition = constraints.biggest.height;
                  final isCollapsed = scrollPosition <= 
                      MediaQuery.of(context).padding.top + kToolbarHeight;

                  return FlexibleSpaceBar(
                    background: _buildHeader(),
                    title: isCollapsed
                        ? Text(
                            _profile!.nickname,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          )
                        : null,
                    centerTitle: true,
                  );
                },
              ),
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Theme.of(context).primaryColor,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(text: '作品'),
                  Tab(text: '共创'),
                ],
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            MyPostsTab(userId: widget.userId),
            MyCollabTab(userId: widget.userId),
          ],
        ),
      ),
    );
  }

<<<<<<< HEAD
  Widget _buildAppBarTitle() {
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 200),
      child: Text(
        '${_profile!.nickname}的个人主页',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 80, 16, 20),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头像和统计数据行
            _buildAvatarAndStatsRow(),
            const SizedBox(height: 16),

            // 用户信息卡片
            _buildUserInfoCard(),
            const SizedBox(height: 12),

            // 按钮区域
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarAndStatsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 头像
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: const Color(0xFFEC4899),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.pink.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 38,
            backgroundColor: Colors.grey[200],
            backgroundImage: _profile!.avatarUrl != null
                ? NetworkImage(_profile!.avatarUrl!)
                : null,
            child: _profile!.avatarUrl == null
                ? Text(
              _profile!.nickname.isNotEmpty ? _profile!.nickname[0] : '?',
              style: const TextStyle(
                fontSize: 28,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            )
                : null,
          ),
        ),
        const SizedBox(width: 16),

        // 统计数据
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
              border: Border.all(
                color: Colors.grey.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('作品', _stats?['posts'] ?? 0),
                _buildStatItem('关注', _stats?['following'] ?? 0),
                _buildStatItem('粉丝', _stats?['followers'] ?? 0),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 昵称和认证标识
          Row(
            children: [
              Expanded(
=======
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 50),

          // 头像
          AvatarWidget(
            imageUrl: _profile!.avatarUrl,
            size: 80,
            semanticsLabel: '${_profile!.nickname}的头像',
          ),

          const SizedBox(height: 12),

          // 昵称和认证标志
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
                child: Text(
                  _profile!.nickname,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
<<<<<<< HEAD
                ),
              ),
              if (_profile!.isCoser) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEC4899),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified,
                        size: 12,
                        color: Colors.white,
                      ),
                      SizedBox(width: 3),
                      Text(
                        'Coser',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
=======
                  textAlign: TextAlign.center,
                ),
              ),
              if (_profile!.isCoser) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.pink,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.verified, size: 14, color: Colors.white),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
                ),
              ],
            ],
          ),
<<<<<<< HEAD
          const SizedBox(height: 6),

          // ID
          Text(
            'ID: ${_profile!.id}',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // 角色标签
          _buildRoleBadges(),
          const SizedBox(height: 8),

          // 简介
          if (_profile!.bio != null && _profile!.bio!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xffF8F9FA),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _profile!.bio!,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13,
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),

          // 城市和更多信息
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (_profile!.city != null)
                _buildCompactInfoItem(
                  Icons.location_on_outlined,
                  _profile!.city!,
                  const Color(0xFFEC4899),
                ),
              _buildCompactInfoItem(
                Icons.school_outlined,
                '暂无',
                const Color(0xFFEC4899),

              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInfoItem(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _toggleFollow,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isFollowing ? Colors.grey[300] : const Color(0xFFEC4899),
                foregroundColor: _isFollowing ? Colors.grey[600] : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                elevation: 0,
              ),
              icon: Icon(
                _isFollowing ? Icons.check : Icons.add,
                size: 18,
              ),
              label: Text(
                _isFollowing ? '已关注' : '关注',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 56,
            child: ElevatedButton(
              onPressed: _startChat,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[100],
                foregroundColor: Colors.grey[600],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              child: const Icon(Icons.message, size: 20),
            ),
=======

          // 角色和等级标签
          if (_profile!.isCoser || _profile!.role != 'user') ...[
            const SizedBox(height: 8),
            _buildRoleBadges(),
          ],

          // 简介
          if (_profile!.bio != null && _profile!.bio!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _profile!.bio!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // 城市
          if (_profile!.city != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(_profile!.city!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // 统计数据
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem('作品', _stats?['posts'] ?? 0),
              _buildStatItem('关注', _stats?['following'] ?? 0),
              _buildStatItem('粉丝', _stats?['followers'] ?? 0),
            ],
          ),

          const SizedBox(height: 12),

          // 操作按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _toggleFollow,
                icon: Icon(_isFollowing ? Icons.check : Icons.add, size: 18),
                label: Text(_isFollowing ? '已关注' : '关注'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isFollowing ? Colors.grey : null,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _startChat,
                icon: const Icon(Icons.message, size: 18),
                label: const Text('私信'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadges() {
    List<Widget> badges = [];

<<<<<<< HEAD
    if (_profile!.isCoser) {
      badges.add(_buildRoleBadge(
        'Coser',
        Icons.camera_alt,
        const Color(0xFFEC4899),
      ));
      if (_profile!.cosLevel != 'none' && _profile!.displayCosLevel.isNotEmpty) {
        badges.add(const SizedBox(width: 8));
        badges.add(_buildRoleBadge(
          _profile!.displayCosLevel,
          Icons.star,
          const Color(0xFFEC4899),
        ));
      }
    } else if (_profile!.role != 'user') {
      badges.add(_buildRoleBadge(
        _profile!.displayRole,
        _getRoleIcon(_profile!.role),
        const Color(0xFFEC4899),
      ));
    }

    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
=======
    if (!_profile!.isCoser && _profile!.role != 'user') {
      badges.add(_buildBadge(
        _profile!.displayRole,
        _getRoleColor(_profile!.role),
        _getRoleIcon(_profile!.role),
      ));
    }

    if (_profile!.isCoser) {
      badges.add(_buildBadge('Coser', Colors.pink, Icons.camera_alt));

      if (_profile!.cosLevel != 'none' && _profile!.displayCosLevel.isNotEmpty) {
        badges.add(_buildBadge(_profile!.displayCosLevel, Colors.purple, Icons.star));
      }
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      alignment: WrapAlignment.center,
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
      children: badges,
    );
  }

<<<<<<< HEAD
  Widget _buildRoleBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
=======
  Widget _buildBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(12),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
<<<<<<< HEAD
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
=======
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
        ],
      ),
    );
  }

<<<<<<< HEAD
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
=======
  Color _getRoleColor(String role) {
    switch (role) {
      case 'coser': return Colors.pink;
      case 'creator_support': return Colors.blue;
      case 'organizer': return Colors.orange;
      default: return Colors.grey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'coser': return Icons.camera_alt;
      case 'creator_support': return Icons.palette;
      case 'organizer': return Icons.event;
      default: return Icons.person;
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
    }
  }

  Widget _buildStatItem(String label, int count) {
    return Column(
      children: [
<<<<<<< HEAD
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFEC4899).withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFEC4899).withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFEC4899),
              ),
            ),
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
=======
        Text(count.toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
      ],
    );
  }
}