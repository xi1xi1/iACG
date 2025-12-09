import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/post_card.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/loading_view.dart';

class MyFavoritesTab extends StatefulWidget {
  final String userId;
  final String searchQuery; // 添加搜索参数

  const MyFavoritesTab({
    super.key,
    required this.userId,
    this.searchQuery = '',
  });

  @override
  State<MyFavoritesTab> createState() => _MyFavoritesTabState();
}

class _MyFavoritesTabState extends State<MyFavoritesTab> {
  final SupabaseClient _client = Supabase.instance.client;
  final List<Map<String, dynamic>> _allFavorites = []; // 存储所有收藏
  final List<Map<String, dynamic>> _displayFavorites = []; // 显示收藏（搜索过滤后）
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
    _loadFavorites();
  }

  @override
  void didUpdateWidget(MyFavoritesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当搜索词变化时，过滤收藏
    if (oldWidget.searchQuery != widget.searchQuery) {
      _filterFavorites();
    }
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
      final end = _page * _pageSize + _pageSize - 1;

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

      final List<Map<String, dynamic>> newFavorites = [];
      for (var item in (resp as List)) {
        final postData = item['post'];
        if (postData != null &&
            postData is Map<String, dynamic> &&
            postData['is_deleted'] == false &&
            postData['status'] == 'normal') {
          newFavorites.add(postData);
        }
      }

      setState(() {
        _allFavorites.addAll(newFavorites);
        _page++;
        _hasMore = (resp as List).length == _pageSize;
        _isLoading = false;
        _error = null;
        // 加载新数据后重新过滤
        _filterFavorites();
      });
    } catch (e, stackTrace) {
      setState(() {
        _error = '加载失败：${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _filterFavorites() {
    final searchQuery = widget.searchQuery.trim().toLowerCase();

    if (searchQuery.isEmpty) {
      // 无搜索词，显示所有收藏
      setState(() {
        _displayFavorites.clear();
        _displayFavorites.addAll(_allFavorites);
      });
    } else {
      // 根据搜索词过滤
      final filtered = _allFavorites.where((post) {
        final title = post['title']?.toString().toLowerCase() ?? '';
        final content = post['content']?.toString().toLowerCase() ?? '';
        final author = post['author']?['nickname']?.toString().toLowerCase() ?? '';

        return title.contains(searchQuery) ||
            content.contains(searchQuery) ||
            author.contains(searchQuery);
      }).toList();

      setState(() {
        _displayFavorites.clear();
        _displayFavorites.addAll(filtered);
      });
    }
  }

  Future<void> _onRefresh() async {
    setState(() {
      _allFavorites.clear();
      _displayFavorites.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
    });
    await _loadFavorites();
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
          // 搜索状态提示
          if (widget.searchQuery.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: Row(
                children: [
                  Icon(Icons.search, size: 16, color: _primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '搜索"${widget.searchQuery}"，找到${_displayFavorites.length}个收藏',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (widget.searchQuery.isNotEmpty)
            const Divider(height: 1, thickness: 0.5),

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
    if (_isLoading && _allFavorites.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
        ),
      );
    }

    if (_error != null && _allFavorites.isEmpty) {
      return _buildErrorView();
    }

    // 有搜索词但没有搜索结果
    if (widget.searchQuery.isNotEmpty && _displayFavorites.isEmpty && !_isLoading) {
      return _buildNoSearchResults();
    }

    if (_displayFavorites.isEmpty) {
      return _buildEmptyView();
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _displayFavorites.length + 1,
      physics: const AlwaysScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        if (index == _displayFavorites.length) {
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
              child: PostCard(post: _displayFavorites[index]),
            ),
            if (index < _displayFavorites.length - 1)
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

  Widget _buildNoSearchResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 72,
            color: _primaryColor,
          ),
          const SizedBox(height: 20),
          Text(
            '没有找到"${widget.searchQuery}"相关的收藏',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            '换个关键词试试吧',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
            ),
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
              '重新搜索',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
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
          Text(
            _error!.startsWith('请先登录') ? '未登录' : '加载失败',
            style: const TextStyle(
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
            child: Text(
              _error!.startsWith('请先登录') ? '去登录' : '重新加载',
              style: const TextStyle(fontSize: 14),
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
            Icons.favorite_outline_rounded,
            size: 72,
            color: _primaryColor,
          ),
          const SizedBox(height: 20),
          Text(
            widget.searchQuery.isNotEmpty ? '暂无相关收藏' : '暂无收藏',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.searchQuery.isNotEmpty
                ? '换个关键词试试吧'
                : '收藏的作品会显示在这里',
            style: const TextStyle(
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
        child: Center(
          child: Text(
            widget.searchQuery.isNotEmpty
                ? '没有更多搜索结果了'
                : '已经到底了',
            style: const TextStyle(
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