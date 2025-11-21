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
                // 移除 title 属性，让标题在初始状态不显示
              ),
              title: _buildAppBarTitle(),
              centerTitle: true,
              // 关键设置：初始状态下标题不显示，只有滚动时才显示
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
      ),
    );
  }

  Widget _buildProfileHeader() {
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
            ),
          ),
        ],
      ),
    );
  }
}