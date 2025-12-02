import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/post_card.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/loading_view.dart';

class MyIslandTab extends StatefulWidget {
  final String userId;

  const MyIslandTab({super.key, required this.userId});

  @override
  State<MyIslandTab> createState() => _MyIslandTabState();
}

class _MyIslandTabState extends State<MyIslandTab> {
  final SupabaseClient _client = Supabase.instance.client;

  final List<Map<String, dynamic>> _posts = [];
  bool _isLoading = false;
  String? _error;
  int _page = 0;
  final int _pageSize = 10;
  bool _hasMore = true;
  late ScrollController _scrollController;

  final List<String> _types = ['全部', '求助', '分享', '吐槽', '找搭子', '约拍', '其他'];
  String _selectedType = '全部';

  // 主色调常量
  static const Color _primaryColor = Color(0xFFED7099);
  static const Color _secondaryColor = Color(0xFFF9A8C9);

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
      final end = _page * _pageSize + _pageSize - 1;

      var query = _client
          .from('posts')
          .select('''
            id, title, content, channel, island_type, created_at, 
            like_count, favorite_count, comment_count, view_count,
            author:profiles!posts_author_id_fkey(id, nickname, avatar_url),
            post_media(media_url, sort_order)
          ''')
          .eq('author_id', widget.userId)
          .eq('channel', 'island')
          .eq('is_deleted', false)
          .eq('status', 'normal');

      if (_selectedType != '全部') {
        query = query.eq('island_type', _selectedType);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(_page * _pageSize, end);

      setState(() {
        _posts.addAll((response as List).cast<Map<String, dynamic>>());
        _page++;
        _hasMore = (response as List).length == _pageSize;
        _isLoading = false;
        _error = null;
      });
    } catch (e, stackTrace) {
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

  void _onTypeChanged(String type) {
    if (_selectedType == type) return;
    setState(() {
      _selectedType = type;
      _posts.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
    });
    _loadPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F5F8),
      child: Column(
        children: [
          // 类型筛选 - 简化的白色背景布局
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _types.map((type) {
                  final isSelected = _selectedType == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _onTypeChanged(type),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? _primaryColor : const Color(0xFFF5F5F8),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          type,
                          style: TextStyle(
                            fontSize: 14,
                            color: isSelected ? Colors.white : const Color(0xFF666666),
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // 分隔线
          Container(
            height: 1,
            color: const Color(0xFFF0F0F0),
          ),

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
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        if (index == _posts.length) {
          return _buildLoadMoreIndicator();
        }

        // 最简单的白色背景，无阴影无圆角
        return Container(
          color: Colors.white,
          child: Column(
            children: [
              PostCard(post: _posts[index]),
              // 分隔线
              if (index < _posts.length - 1)
                Container(
                  height: 1,
                  color: const Color(0xFFF0F0F0),
                ),
            ],
          ),
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
            Icons.public_outlined,
            size: 72,
            color: _primaryColor,
          ),
          const SizedBox(height: 20),
          const Text(
            '暂无群岛动态',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _selectedType == '全部'
                ? '还没有在群岛发布过内容'
                : '还没有发布过$_selectedType类型的动态',
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
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: const Center(
          child: Text(
            '没有更多群岛动态了',
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
        padding: const EdgeInsets.all(16),
        color: Colors.white,
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