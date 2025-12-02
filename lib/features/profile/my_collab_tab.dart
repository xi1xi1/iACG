import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/post_card.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/loading_view.dart';

class MyCollabTab extends StatefulWidget {
  final String userId;
  const MyCollabTab({super.key, required this.userId});

  @override
  State<MyCollabTab> createState() => _MyCollabTabState();
}

class _MyCollabTabState extends State<MyCollabTab> {
  final SupabaseClient _client = Supabase.instance.client;
  final List<Map<String, dynamic>> _posts = [];
  bool _isLoading = false;
  String? _error;
  int _page = 0;
  final int _pageSize = 10;
  bool _hasMore = true;
  late ScrollController _scrollController;

  // 主色调常量
  static const Color _primaryColor = Color(0xFFED7099);
  static const Color _secondaryColor = Color(0xFFF9A8C9);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _fetchCollabPosts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _fetchCollabPosts();
    }
  }

  Future<void> _fetchCollabPosts() async {
    if (!_hasMore || _isLoading) return;

    setState(() => _isLoading = true);
    try {
      final end = _page * _pageSize + _pageSize - 1;
      final resp = await _client
          .from('post_collaborators')
          .select('''
            id, role, display_name, created_at,
            post:posts(
              id, title, content, channel, created_at,
              like_count, favorite_count, comment_count, view_count,
              is_deleted, status,
              author:profiles!posts_author_id_fkey(id, nickname, avatar_url),
              post_media(media_url, sort_order)
            )
          ''')
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false)
          .range(_page * _pageSize, end);

      final List<Map<String, dynamic>> newPosts = [];
      for (var item in (resp as List)) {
        final postData = item['post'];
        if (postData != null &&
            postData is Map<String, dynamic> &&
            postData['is_deleted'] == false &&
            postData['status'] == 'normal') {
          newPosts.add(postData);
        }
      }

      setState(() {
        _posts.addAll(newPosts);
        _page++;
        _hasMore = (resp as List).length == _pageSize;
        _isLoading = false;
        _error = null;
      });
    } catch (e, stackTrace) {
      setState(() {
        _error = '加载共创作品失败：${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    setState(() {
      _posts.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
    });
    await _fetchCollabPosts();
  }

  @override
  Widget build(BuildContext context) {
    return _buildContent();
  }

  Widget _buildContent() {
    return Container(
      color: const Color(0xFFF5F5F8),
      child: Column(
        children: [

          Expanded(
            child: RefreshIndicator(
              color: _primaryColor,
              onRefresh: _onRefresh,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _posts.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
        ),
      );
    }

    if (_error != null && _posts.isEmpty) {
      return _buildErrorView();
    }

    if (_posts.isEmpty) {
      return _buildEmptyView();
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _posts.length + 1,
      physics: const AlwaysScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        if (index == _posts.length) {
          return _buildLoadMoreIndicator();
        }

        // 添加分隔线和样式
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: PostCard(post: _posts[index]),
            ),
            if (index < _posts.length - 1)
              const Divider(
                height: 1,
                thickness: 0.5,
                color: Color(0xFFF0F0F0),
                indent: 24,
                endIndent: 24,
              ),
          ],
        );
      },
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  _primaryColor.withOpacity(0.1),
                  _secondaryColor.withOpacity(0.1),
                ],
              ),
            ),
            child: Icon(
              Icons.error_outline,
              size: 40,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '加载失败',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _onRefresh,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text(
              '重新加载',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_add_outlined,
            size: 72,
            color: _primaryColor,
          ),
          const SizedBox(height: 20),
          const Text(
            '暂无共创作品',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '还没有参与过共创项目',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    if (!_hasMore) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: const Center(
          child: Text(
            '没有更多共创作品了',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF999999),
            ),
          ),
        ),
      );
    }
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}