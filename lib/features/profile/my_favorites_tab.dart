import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/post_card.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/loading_view.dart';

class MyFavoritesTab extends StatefulWidget {
  final String userId;
  const MyFavoritesTab({Key? key, required this.userId}) : super(key: key);

  @override
  State<MyFavoritesTab> createState() => _MyFavoritesTabState();
}

class _MyFavoritesTabState extends State<MyFavoritesTab> {
  final SupabaseClient _client = Supabase.instance.client;
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = false; // 改为 false
  String? _error;
  int _page = 0;
  final int _pageSize = 10;
  bool _hasMore = true;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadFavorites();
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
      _loadFavorites();
    }
  }

  Future<void> _loadFavorites() async {
    if (!_hasMore || _isLoading) return;
    
    String? currentUserId = widget.userId;
    if (currentUserId.isEmpty) {
      currentUserId = _client.auth.currentUser?.id;
    }

    if (currentUserId == null) {
      setState(() {
        _error = '请先登录';
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      print('开始加载收藏，用户ID: $currentUserId, 页码: $_page');

      final end = _page * _pageSize + _pageSize - 1;
      
      // 使用单次查询，通过关联直接获取帖子数据
      final resp = await _client
          .from('post_favorites')
          .select('''
            id,
            created_at,
            post:posts(
              id, title, content, channel, created_at,
              like_count, favorite_count, comment_count, view_count,
              is_deleted, status,
              author:profiles!posts_author_id_fkey(id, nickname, avatar_url),
              post_media(media_url, sort_order)
            )
          ''')
          .eq('user_id', currentUserId)
          .order('created_at', ascending: false)
          .range(_page * _pageSize, end);

      print('收藏记录查询成功: ${resp.length} 条');

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

      print('过滤后有效帖子: ${newPosts.length} 条');

      setState(() {
        _posts.addAll(newPosts);
        _page++;
        _hasMore = (resp as List).length == _pageSize;
        _isLoading = false;
        _error = null;
      });
      
      print('收藏加载完成，当前共 ${_posts.length} 条');
    } catch (e, stackTrace) {
      print('收藏数据加载失败：$e');
      print('堆栈跟踪：$stackTrace');
      setState(() {
        _error = '加载失败：${e.toString()}';
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
    await _loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _posts.isEmpty) {
      return const LoadingView();
    }

    if (_error != null && _posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('加载失败', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _onRefresh,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_posts.isEmpty) {
      return const EmptyView();
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _posts.length + 1,
      itemBuilder: (context, index) {
        if (index == _posts.length) {
          if (!_hasMore) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text('没有更多了', style: TextStyle(color: Colors.grey)),
              ),
            );
          }
          if (_isLoading) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return const SizedBox.shrink();
        }
        return PostCard(post: _posts[index]);
      },
    );
  }
}