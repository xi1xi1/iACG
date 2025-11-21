// lib/features/profile/user_profile_page.dart
import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../services/profile_service.dart';
import '../../services/message_service.dart';
import '../../widgets/avatar_widget.dart';
import 'my_posts_tab.dart';
import '../messages/chat_page.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;
  const UserProfilePage({Key? key, required this.userId}) : super(key: key);

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final ProfileService _profileService = ProfileService();
  final MessageService _messageService = MessageService();

  UserProfile? _profile;
  Map<String, int>? _stats;
  bool _isFollowing = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
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
            ),
          ];
        },
        body: MyPostsTab(userId: widget.userId),
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
}