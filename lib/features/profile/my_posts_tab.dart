import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/post_card.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/loading_view.dart';

class MyPostsTab extends StatefulWidget {
  final String userId;

<<<<<<< HEAD
  const MyPostsTab({super.key, required this.userId});
=======
  const MyPostsTab({Key? key, required this.userId}) : super(key: key);
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1

  @override
  State<MyPostsTab> createState() => _MyPostsTabState();
}

class _MyPostsTabState extends State<MyPostsTab> {
  final SupabaseClient _client = Supabase.instance.client;

<<<<<<< HEAD
  final List<Map<String, dynamic>> _posts = [];
=======
  List<Map<String, dynamic>> _posts = [];
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
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
    _loadPosts();
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
      _loadPosts();
    }
  }

  Future<void> _loadPosts() async {
    if (!_hasMore || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      print('开始加载COS作品，用户ID: ${widget.userId}, 页码: $_page');

      final end = _page * _pageSize + _pageSize - 1;
      
      final response = await _client
          .from('posts')
          .select('''
            id, title, content, channel, created_at, 
            like_count, favorite_count, comment_count, view_count,
            author:profiles!posts_author_id_fkey(id, nickname, avatar_url),
            post_media(media_url, sort_order)
          ''')
          .eq('author_id', widget.userId)
          .eq('channel', 'cos')
          .eq('is_deleted', false)
          .eq('status', 'normal')
          .order('created_at', ascending: false)
          .range(_page * _pageSize, end);

      print('查询成功，返回数据: ${response.length} 条');

      setState(() {
        _posts.addAll((response as List).cast<Map<String, dynamic>>());
        _page++;
        _hasMore = (response as List).length == _pageSize;
        _isLoading = false;
        _error = null;
      });

      print('数据加载完成，当前共 ${_posts.length} 条');
    } catch (e, stackTrace) {
      print('加载失败: $e');
      print('堆栈: $stackTrace');
      setState(() {
        _error = e.toString();
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
    await _loadPosts();
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