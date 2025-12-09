import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../services/profile_service.dart';
import '../../widgets/avatar_widget.dart';
import 'user_profile_page.dart';

class FollowingListPage extends StatefulWidget {
  final String userId;
  const FollowingListPage({super.key, required this.userId});

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
      backgroundColor: const Color(0xFFF5F5F8),
      appBar: AppBar(
        title: const Text(
          '我的关注',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFED7099), // 修改为主题色
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<UserProfile>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFED7099)), // 修改为主题色
              ),
            );
          }
          if (snapshot.hasError) {
            return _ErrorRetry(
              message: '加载关注列表失败: ${snapshot.error}',
              onRetry: _reload,
            );
          }
          final list = snapshot.data ?? <UserProfile>[];
          if (list.isEmpty) {
            return _buildEmptyState('你还没有关注任何人');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(0),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              thickness: 0.5,
              color: Color(0xFFE5E5E5),
              indent: 80,
            ),
            itemBuilder: (context, index) {
              final user = list[index];
              return _UserRow(profile: user);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      color: const Color(0xFFF5F5F8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: const Color(0xFFED7099)), // 修改为主题色
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF666666),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FollowersListPage extends StatefulWidget {
  final String userId;
  const FollowersListPage({super.key, required this.userId});

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
      backgroundColor: const Color(0xFFF5F5F8),
      appBar: AppBar(
        title: const Text(
          '我的粉丝',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFED7099), // 修改为主题色
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<UserProfile>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFED7099)), // 修改为主题色
              ),
            );
          }
          if (snapshot.hasError) {
            return _ErrorRetry(
              message: '加载粉丝列表失败: ${snapshot.error}',
              onRetry: _reload,
            );
          }
          final list = snapshot.data ?? <UserProfile>[];
          if (list.isEmpty) {
            return _buildEmptyState('还没有粉丝呢');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(0),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              thickness: 0.5,
              color: Color(0xFFE5E5E5),
              indent: 80,
            ),
            itemBuilder: (context, index) {
              final user = list[index];
              return _UserRow(profile: user);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      color: const Color(0xFFF5F5F8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: const Color(0xFFED7099)), // 修改为主题色
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF666666),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 通用的用户一行展示
class _UserRow extends StatelessWidget {
  final UserProfile profile;
  const _UserRow({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => UserProfilePage(
              userId: profile.id,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.white,
        child: Row(
          children: [
            // 头像
            Stack(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: const [
                        Color(0xFFED7099), // 主色调
                        Color(0xFFF9A8C9), // 次要色调
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFED7099).withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.transparent,
                    backgroundImage: profile.avatarUrl != null
                        ? NetworkImage(profile.avatarUrl!)
                        : null,
                    child: profile.avatarUrl == null
                        ? Center(
                      child: Text(
                        profile.nickname.isNotEmpty ? profile.nickname[0] : '?',
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                        : null,
                  ),
                ),
                if (profile.isCoser)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFFED7099), // 修改为主题色
                        shape: BoxShape.circle,
                        border: const Border.fromBorderSide(
                          BorderSide(color: Colors.white, width: 2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFED7099).withOpacity(0.3),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.verified,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),

            // 用户信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          profile.nickname,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (profile.city != null && profile.city!.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 14, color: const Color(0xFFED7099)), // 修改为主题色
                            const SizedBox(width: 4),
                            Text(
                              profile.city!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF666666),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                        ),
                      if (profile.displayCosLevel.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: const [
                                Color(0xFFED7099), // 主色调
                                Color(0xFFF9A8C9), // 次要色调
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            profile.displayCosLevel,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      profile.bio!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF666666),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRetry({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F5F8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFED7099).withOpacity(0.1), // 修改为主题色
                    const Color(0xFFF9A8C9).withOpacity(0.1), // 修改为次要色调
                  ],
                ),
              ),
              child: Icon(Icons.error_outline,
                  size: 40, color: const Color(0xFFED7099)), // 修改为主题色
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFED7099), // 修改为主题色
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('重新加载'),
            ),
          ],
        ),
      ),
    );
  }
}