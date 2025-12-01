// lib/pages/search/tabs/search_users_tab.dart
import 'package:flutter/material.dart';
import 'package:iacg/features/profile/user_profile_page.dart';
import 'package:iacg/services/search_service.dart';
import 'package:iacg/widgets/avatar_widget.dart';

class SearchUsersTab extends StatefulWidget {
  final SearchService searchService;
  final String keyword;

  const SearchUsersTab({
<<<<<<< HEAD
    super.key,
    required this.searchService,
    required this.keyword,
  });
=======
    Key? key,
    required this.searchService,
    required this.keyword,
  }) : super(key: key);
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1

  @override
  State<SearchUsersTab> createState() => _SearchUsersTabState();
}

class _SearchUsersTabState extends State<SearchUsersTab> with AutomaticKeepAliveClientMixin {
  final List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _pageSize = 20;
<<<<<<< HEAD
  final ScrollController _scrollController = ScrollController();
=======
  ScrollController _scrollController = ScrollController();
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1

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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
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
              // 用户信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nickname,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (userId != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '用户ID: $userId',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 箭头指示
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}