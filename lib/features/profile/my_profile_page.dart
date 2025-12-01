<<<<<<< HEAD
import 'package:flutter/material.dart';
=======
/* import 'package:flutter/material.dart';
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
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
<<<<<<< HEAD
  const MyProfilePage({super.key});
=======
  const MyProfilePage({Key? key}) : super(key: key);
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1

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
              style: TextStyle(color: Colors.red),
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
          child: CircularProgressIndicator(),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
<<<<<<< HEAD
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC4899)),
=======
        backgroundColor: Color(0xffFEF7FF),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xff6750A4)),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
          ),
        ),
      );
    }

    if (_error != null || _profile == null) {
      return Scaffold(
<<<<<<< HEAD
        backgroundColor: Colors.white,
=======
        backgroundColor: Color(0xffFEF7FF),
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
=======
              Icon(Icons.error_outline, size: 64, color: Color(0xff6750A4)),
              const SizedBox(height: 16),
              Text(
                '加载失败: $_error',
                style: TextStyle(color: Color(0xff6750A4)),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
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
<<<<<<< HEAD
      backgroundColor: Colors.white,
=======
      backgroundColor: Color(0xffFEF7FF),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              pinned: true,
              floating: false,
              snap: false,
<<<<<<< HEAD
              expandedHeight: 500, // 减少高度以适应紧凑布局
              stretch: true,
              backgroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildProfileHeader(),
                collapseMode: CollapseMode.parallax,
              ),
              title: _buildAppBarTitle(),
              centerTitle: true,
=======
              expandedHeight: 380,
              stretch: true,
              backgroundColor: Color(0xffFEF7FF),
              flexibleSpace: FlexibleSpaceBar(
                background: _buildProfileHeader(),
                collapseMode: CollapseMode.parallax,
                // 移除 title 属性，让标题在初始状态不显示
              ),
              title: _buildAppBarTitle(),
              centerTitle: true,
              // 关键设置：初始状态下标题不显示，只有滚动时才显示
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
              forceElevated: true,
              elevation: 0,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
<<<<<<< HEAD
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFFEC4899),
                    labelColor: const Color(0xFFEC4899),
=======
                  color: Color(0xffFEF7FF),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: Color(0xff6750A4),
                    labelColor: Color(0xff6750A4),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
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
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            MyPostsTab(userId: _profile!.id),
            MyIslandTab(userId: _profile!.id),
            MyFavoritesTab(userId: _profile!.id),
            MyCollabTab(userId: _profile!.id),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarTitle() {
    return AnimatedOpacity(
<<<<<<< HEAD
      opacity: 1.0,
      duration: const Duration(milliseconds: 200),
=======
      opacity: 1.0, // 标题在显示时完全不透明
      duration: Duration(milliseconds: 200),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
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
<<<<<<< HEAD
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 60, 16, 16), // 减少顶部间距
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头像和统计数据行
            _buildAvatarAndStatsRow(),
            const SizedBox(height: 16), // 减少间距

            // 用户信息卡片
            _buildUserInfoCard(),
            const SizedBox(height: 12), // 减少间距

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
          width: 80, // 稍微减小
          height: 80, // 稍微减小
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
                fontSize: 28, // 稍微减小
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            )
                : null,
          ),
        ),
        const SizedBox(width: 16), // 减少间距

        // 统计数据
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12), // 减少padding
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
      padding: const EdgeInsets.all(12), // 减少内边距
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
          // 昵称和认证标识 - 更紧凑
=======
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
      color: Color(0xffFEF7FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行：头像和统计数据
          Row(
            children: [
              // 头像
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: CircleAvatar(
                  radius: 38,
                  backgroundColor: Colors.grey[300],
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
              const SizedBox(width: 20),
              // 统计数据
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('作品', _stats?['posts'] ?? 0),
                    _buildStatItem('关注', _stats?['following'] ?? 0),
                    _buildStatItem('粉丝', _stats?['followers'] ?? 0),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 昵称和认证标识
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
          Row(
            children: [
              Expanded(
                child: Text(
                  _profile!.nickname,
                  style: const TextStyle(
<<<<<<< HEAD
                    fontSize: 18, // 稍微减小字体
=======
                    fontSize: 18,
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_profile!.isCoser) ...[
<<<<<<< HEAD
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // 减小padding
                  decoration: BoxDecoration(
                    color: const Color(0xFFEC4899),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified,
                        size: 12, // 减小图标
                        color: Colors.white,
                      ),
                      SizedBox(width: 3),
                      Text(
                        'Coser',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11, // 减小字体
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
=======
                const SizedBox(width: 8),
                // 使用图标替代文字标签
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.pink,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.verified, // 或者使用您的自定义图标
                    size: 16,
                    color: Colors.white,
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
                  ),
                ),
              ],
            ],
          ),
<<<<<<< HEAD
          const SizedBox(height: 6), // 减少间距
=======
          const SizedBox(height: 8),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1

          // ID
          Text(
            'ID: ${_profile!.id}',
            style: const TextStyle(
<<<<<<< HEAD
              color: Colors.grey,
              fontSize: 12, // 减小字体
              fontFamily: 'monospace',
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8), // 减少间距

          // 角色标签
          _buildRoleBadges(),
          const SizedBox(height: 8), // 减少间距
=======
              color: Colors.black54,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1

          // 简介
          if (_profile!.bio != null && _profile!.bio!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
<<<<<<< HEAD
                Container(
                  padding: const EdgeInsets.all(10), // 减少padding
                  decoration: BoxDecoration(
                    color: const Color(0xffF8F9FA),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _profile!.bio!,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13, // 减小字体
                      height: 1.3, // 减少行高
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8), // 减少间距
              ],
            ),

          // 城市和更多信息 - 更紧凑
          Wrap(
            spacing: 8, // 减少间距
            runSpacing: 6, // 减少行间距
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
=======
                Text(
                  _profile!.bio!,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
              ],
            ),

          // 城市和更多信息
          if (_profile!.city != null)
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Color(0xff6750A4)),
                const SizedBox(width: 4),
                Text(
                  _profile!.city!,
                  style: TextStyle(color: Color(0xff6750A4), fontSize: 12),
                ),
                const SizedBox(width: 16),
                Icon(Icons.school_outlined, size: 14, color: Color(0xff6750A4)),
                const SizedBox(width: 4),
                Text(
                  '暂无',
                  style: TextStyle(color: Color(0xff6750A4), fontSize: 12),
                ),
              ],
            ),

          const SizedBox(height: 16),

          // 按钮区域
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
                    backgroundColor: Color(0xff6750A4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    '编辑资料',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 48,
                child: ElevatedButton(
                  onPressed: _handleSignOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xff6750A4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Icon(Icons.logout, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
        ],
      ),
    );
  }

<<<<<<< HEAD
  Widget _buildCompactInfoItem(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // 更小的padding
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12), // 更小的圆角
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color), // 更小的图标
          const SizedBox(width: 3), // 减少间距
          Text(
            text,
            style: TextStyle(
              fontSize: 11, // 更小的字体
              color: color,
              fontWeight: FontWeight.w500,
=======
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
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black,
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
            ),
          ),
        ],
      ),
    );
  }
<<<<<<< HEAD

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
                backgroundColor: const Color(0xFFEC4899),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                elevation: 0,
              ),
              icon: const Icon(Icons.edit, size: 18),
              label: const Text(
                '编辑资料',
                style: TextStyle(
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
              onPressed: _handleSignOut,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[100],
                foregroundColor: Colors.grey[600],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              child: const Icon(Icons.exit_to_app,color: Colors.red, size: 20),
            ),
          ),
        ],
=======
} */

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
  const MyProfilePage({Key? key}) : super(key: key);

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
              style: TextStyle(color: Colors.red),
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
          child: CircularProgressIndicator(),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xffFEF7FF),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xff6750A4)),
          ),
        ),
      );
    }

    if (_error != null || _profile == null) {
      return Scaffold(
        backgroundColor: Color(0xffFEF7FF),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Color(0xff6750A4)),
              const SizedBox(height: 16),
              Text(
                '加载失败: $_error',
                style: TextStyle(color: Color(0xff6750A4)),
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
      backgroundColor: Color(0xffFEF7FF),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              pinned: true,
              floating: false,
              snap: false,
              expandedHeight: 380,
              stretch: true,
              backgroundColor: Color(0xffFEF7FF),
              flexibleSpace: FlexibleSpaceBar(
                background: _buildProfileHeader(),
                collapseMode: CollapseMode.parallax,
                // 移除 title 属性,让标题在初始状态不显示
              ),
              title: _buildAppBarTitle(),
              centerTitle: true,
              // 关键设置:初始状态下标题不显示,只有滚动时才显示
              forceElevated: true,
              elevation: 0,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: Color(0xffFEF7FF),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: Color(0xff6750A4),
                    labelColor: Color(0xff6750A4),
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
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            MyPostsTab(userId: _profile!.id),
            MyIslandTab(userId: _profile!.id),
            MyFavoritesTab(userId: _profile!.id),
            MyCollabTab(userId: _profile!.id),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarTitle() {
    return AnimatedOpacity(
      opacity: 1.0, // 标题在显示时完全不透明
      duration: Duration(milliseconds: 200),
      child: Text(
        '${_profile!.nickname}的个人主页',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
      ),
    );
  }

<<<<<<< HEAD
  Widget _buildInfoItem(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
=======
  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
      color: Color(0xffFEF7FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行:头像和统计数据
          Row(
            children: [
              // 头像
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: CircleAvatar(
                  radius: 38,
                  backgroundColor: Colors.grey[300],
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
              const SizedBox(width: 20),
              // 统计数据
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('作品', _stats?['posts'] ?? 0),
                    _buildStatItem('关注', _stats?['following'] ?? 0),
                    _buildStatItem('粉丝', _stats?['followers'] ?? 0),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 昵称和认证标识
          Row(
            children: [
              Expanded(
                child: Text(
                  _profile!.nickname,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                    Icons.verified, // 或者使用您的自定义图标
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // ID
          Text(
            'ID: ${_profile!.id}',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),

          // 🔧 新增:角色和等级标签
          _buildRoleBadges(),
          const SizedBox(height: 12),

          // 简介
          if (_profile!.bio != null && _profile!.bio!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _profile!.bio!,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
              ],
            ),

          // 城市和更多信息
          if (_profile!.city != null)
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Color(0xff6750A4)),
                const SizedBox(width: 4),
                Text(
                  _profile!.city!,
                  style: TextStyle(color: Color(0xff6750A4), fontSize: 12),
                ),
                const SizedBox(width: 16),
                Icon(Icons.school_outlined, size: 14, color: Color(0xff6750A4)),
                const SizedBox(width: 4),
                Text(
                  '暂无',
                  style: TextStyle(color: Color(0xff6750A4), fontSize: 12),
                ),
              ],
            ),

          const SizedBox(height: 16),

          // 按钮区域
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
                    backgroundColor: Color(0xff6750A4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    '编辑资料',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 48,
                child: ElevatedButton(
                  onPressed: _handleSignOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xff6750A4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Icon(Icons.logout, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
        ],
      ),
    );
  }

<<<<<<< HEAD
  Widget _buildRoleBadges() {
    List<Widget> badges = [];

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
=======
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
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
    }

    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: badges,
    );
  }

<<<<<<< HEAD
  Widget _buildRoleBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), // 稍微减小
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16), // 稍微减小圆角
=======
  // 🔧 新增:构建单个标签
  Widget _buildBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          Icon(icon, size: 12, color: Colors.white), // 减小图标
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11, // 减小字体
              color: Colors.white,
              fontWeight: FontWeight.bold,
=======
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
            ),
          ),
        ],
      ),
    );
  }

<<<<<<< HEAD
=======
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
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
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
=======
          Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
<<<<<<< HEAD
              color: Colors.grey,
              fontWeight: FontWeight.w500,
=======
              color: Colors.black,
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
            ),
          ),
        ],
      ),
    );
  }
}