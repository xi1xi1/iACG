// lib/pages/search/tabs/search_users_tab.dart
import 'package:flutter/material.dart';
import 'package:iacg/features/profile/user_profile_page.dart';
import 'package:iacg/services/profile_service.dart';
import 'package:iacg/services/search_service.dart';
import 'package:iacg/widgets/avatar_widget.dart';

class SearchUsersTab extends StatefulWidget {
  final SearchService searchService;
  final String keyword;

  const SearchUsersTab({
    super.key,
    required this.searchService,
    required this.keyword,
  });

  @override
  State<SearchUsersTab> createState() => _SearchUsersTabState();
}

class _SearchUsersTabState extends State<SearchUsersTab> with AutomaticKeepAliveClientMixin {
  final List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _pageSize = 20;
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }

  @override
  void didUpdateWidget(SearchUsersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keyword != widget.keyword) {
      _resetSearch();
    }
  }

  void _resetSearch() {
    setState(() {
      _users.clear();
      _currentPage = 1;
      _hasMore = true;
      _isLoading = false;
    });
    _loadInitialData();
  }

  void _loadInitialData() {
    if (widget.keyword.isEmpty) return;
    _loadMoreData(reset: true);
  }

  Future<void> _loadMoreData({bool reset = false}) async {
    if (_isLoading || !_hasMore) return;
    
    if (reset) {
      _currentPage = 1;
      _hasMore = true;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final newUsers = await widget.searchService.searchUsersPaged(
        query: widget.keyword,
        limit: _pageSize,
        offset: reset ? 0 : _users.length,
      );

      setState(() {
        if (reset) {
          _users.clear();
        }
        _users.addAll(newUsers);
        _hasMore = newUsers.length == _pageSize;
        _currentPage++;
      });
    } catch (error) {
      print('搜索用户出错: $error');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreData();
    }
  }

  void _refreshSearch() {
    _resetSearch();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (widget.keyword.isEmpty) {
      return const Center(
        child: Text(
          '请输入搜索关键词',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    if (_users.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '没有找到相关用户',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '尝试使用其他关键词搜索',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 搜索结果统计
        if (_users.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            alignment: Alignment.centerLeft,
            child: Text(
              '找到 ${_users.length} 个用户${_hasMore ? '+' : ''}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),

        // 用户列表
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _users.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= _users.length) {
                // 加载更多指示器
                return _buildLoadingIndicator();
              }
              final user = _users[index];
              return _buildUserItem(user);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildUserItem(Map<String, dynamic> user) {
    final String? userId = user['id']?.toString();
    final String nickname = user['nickname'] ?? '未知用户';
    final String? avatarUrl = user['avatar_url']?.toString();
    final int followerCount = (user['follower_count'] as int?) ?? 0;
    final int postCount = (user['post_count'] as int?) ?? 0;
    final bool isFollowing = (user['is_following'] as bool?) ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 0),
      color: Color(0xFFF8FAFC),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
      ),

      child: InkWell(
        onTap: (userId == null)
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UserProfilePage(userId: userId),
                  ),
                );
              },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 头像（可点击）
              AvatarWidget(
                imageUrl: avatarUrl,
                size: 50,
                onTap: (userId == null)
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => UserProfilePage(userId: userId),
                          ),
                        );
                      },
              ),
              const SizedBox(width: 16),
              // 用户信息 - B站样式
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 用户名
                    Text(
                      nickname,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // 粉丝数和帖子数
                    Row(
                      children: [
                        // 粉丝数
                        Row(
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatCount(followerCount),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        // 帖子数
                        Row(
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatCount(postCount),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 关注按钮
              _buildFollowButton(userId, isFollowing),
            ],
          ),
        ),
      ),
    );
  }

  // 格式化数字显示（如：1000 -> 1k）
  String _formatCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 10000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    } else {
      return '${(count / 10000).toStringAsFixed(1)}w';
    }
  }

  // 构建关注按钮
  Widget _buildFollowButton(String? userId, bool isFollowing) {
    if (userId == null) {
      return const SizedBox(width: 60);
    }

    return SizedBox(
      width: 60,
      height: 28,
      child: _FollowButton(
        userId: userId,
        initialIsFollowing: isFollowing,
      ),
    );
  }
}

// 关注按钮组件
class _FollowButton extends StatefulWidget {
  final String userId;
  final bool initialIsFollowing;

  const _FollowButton({
    required this.userId,
    required this.initialIsFollowing,
  });

  @override
  State<_FollowButton> createState() => __FollowButtonState();
}

class __FollowButtonState extends State<_FollowButton> {
  late bool _isFollowing;
  bool _isLoading = false;
  final ProfileService _profileService = ProfileService();

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.initialIsFollowing;
  }

  Future<void> _toggleFollow() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _toggleFollow,
      style: ElevatedButton.styleFrom(
        backgroundColor: _isFollowing ? Colors.grey[200] : const Color(0xFFED7099),
        foregroundColor: _isFollowing ? Colors.grey[700] : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 0,
      ),
      child: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              _isFollowing ? '已关注' : '关注',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
    );
  }
}
