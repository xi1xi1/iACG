// lib/features/profile/following_list_page.dart
import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../services/profile_service.dart';
import '../../widgets/avatar_widget.dart';
import 'user_profile_page.dart';

class FollowingListPage extends StatefulWidget {
  final String userId;
  const FollowingListPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<FollowingListPage> createState() => _FollowingListPageState();
}

class _FollowingListPageState extends State<FollowingListPage> {
  final ProfileService _profileService = ProfileService();
  late Future<List<UserProfile>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<UserProfile>> _load() {
    // 调用 ProfileService 中的"获取关注列表"方法
    return _profileService.fetchFollowing(widget.userId);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的关注')),
      body: FutureBuilder<List<UserProfile>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorRetry(
              message: '加载关注列表失败: ${snapshot.error}',
              onRetry: _reload,
            );
          }
          final list = snapshot.data ?? <UserProfile>[];
          if (list.isEmpty) {
            return const Center(child: Text('你还没有关注任何人'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, index) {
              final user = list[index];
              return _UserRow(profile: user);
            },
          );
        },
      ),
    );
  }
}

class FollowersListPage extends StatefulWidget {
  final String userId;
  const FollowersListPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<FollowersListPage> createState() => _FollowersListPageState();
}

class _FollowersListPageState extends State<FollowersListPage> {
  final ProfileService _profileService = ProfileService();
  late Future<List<UserProfile>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<UserProfile>> _load() {
    // 调用 ProfileService 中的"获取粉丝列表"方法
    return _profileService.fetchFollowers(widget.userId);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的粉丝')),
      body: FutureBuilder<List<UserProfile>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorRetry(
              message: '加载粉丝列表失败: ${snapshot.error}',
              onRetry: _reload,
            );
          }
          final list = snapshot.data ?? <UserProfile>[];
          if (list.isEmpty) {
            return const Center(child: Text('还没有粉丝呢'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, index) {
              final user = list[index];
              return _UserRow(profile: user);
            },
          );
        },
      ),
    );
  }
}

/// 通用的用户一行展示
class _UserRow extends StatelessWidget {
  final UserProfile profile;
  const _UserRow({Key? key, required this.profile}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      // 使用头像组件
      leading: AvatarWidget(
        imageUrl: profile.avatarUrl,
        size: 44,
      ),
      title: Text(
        profile.nickname,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          if (profile.city != null && profile.city!.isNotEmpty) ...[
            const Icon(Icons.location_on, size: 12, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              profile.city!,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
          if (profile.isCoser) ...[
            const SizedBox(width: 8),
            // 认证图标
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.pink,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.verified,
                size: 12,
                color: Colors.white,
              ),
            ),
            // 只有当有等级信息时才显示等级标签
            if (profile.displayCosLevel != null && profile.displayCosLevel!.isNotEmpty) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.pink.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  profile.displayCosLevel!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.pink,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
      // 点击整行，跳转到他人的个人主页
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => UserProfilePage(
              userId: profile.id,
            ),
          ),
        );
      },
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRetry({
    Key? key,
    required this.message,
    required this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}