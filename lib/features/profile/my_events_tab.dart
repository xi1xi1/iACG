import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/post_card.dart';

class MyEventsTab extends StatefulWidget {
  final String userId;
  final String searchQuery;

  const MyEventsTab({
    super.key,
    required this.userId,
    this.searchQuery = '',
  });

  @override
  State<MyEventsTab> createState() => _MyEventsTabState();
}

class _MyEventsTabState extends State<MyEventsTab> {
  final SupabaseClient _client = Supabase.instance.client;

  final List<Map<String, dynamic>> _allEvents = [];
  final List<Map<String, dynamic>> _displayEvents = [];
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
    _loadEvents();
  }

  @override
  void didUpdateWidget(MyEventsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      _filterEvents();
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
      _loadEvents();
    }
  }

  Future<void> _loadEvents() async {
    if (!_hasMore || _isLoading) return;

    setState(() => _isLoading = true);

    try {
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
          .eq('channel', 'event')
          .eq('is_deleted', false)
          .eq('status', 'normal')
          .order('created_at', ascending: false)
          .range(_page * _pageSize, end);

      final newEvents = (response as List).cast<Map<String, dynamic>>();

      setState(() {
        _allEvents.addAll(newEvents);
        _page++;
        _hasMore = newEvents.length == _pageSize;
        _isLoading = false;
        _error = null;
        _filterEvents();
      });
    } catch (e, stackTrace) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterEvents() {
    final searchQuery = widget.searchQuery.trim().toLowerCase();

    if (searchQuery.isEmpty) {
      setState(() {
        _displayEvents.clear();
        _displayEvents.addAll(_allEvents);
      });
    } else {
      final filtered = _allEvents.where((event) {
        final title = event['title']?.toString().toLowerCase() ?? '';
        final content = event['content']?.toString().toLowerCase() ?? '';

        return title.contains(searchQuery) || content.contains(searchQuery);
      }).toList();

      setState(() {
        _displayEvents.clear();
        _displayEvents.addAll(filtered);
      });
    }
  }

  Future<void> _onRefresh() async {
    setState(() {
      _allEvents.clear();
      _displayEvents.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
    });
    await _loadEvents();
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
                      '搜索"${widget.searchQuery}",找到${_displayEvents.length}个活动',
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
    if (_isLoading && _allEvents.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
        ),
      );
    }

    if (_error != null && _allEvents.isEmpty) {
      return _buildErrorView();
    }

    if (widget.searchQuery.isNotEmpty && _displayEvents.isEmpty && !_isLoading) {
      return _buildNoSearchResults();
    }

    if (_displayEvents.isEmpty) {
      return _buildEmptyView();
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _displayEvents.length + 1,
      physics: const AlwaysScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        if (index == _displayEvents.length) {
          return _buildLoadMoreIndicator();
        }

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
              child: PostCard(post: _displayEvents[index]),
            ),
            if (index < _displayEvents.length - 1)
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
            '没有找到"${widget.searchQuery}"相关的活动',
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
            Icons.event_outlined,
            size: 72,
            color: _primaryColor,
          ),
          const SizedBox(height: 20),
          const Text(
            '暂无活动',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '还没有发布过活动',
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
        child: Center(
          child: Text(
            widget.searchQuery.isNotEmpty
                ? '没有更多搜索结果了'
                : '没有更多活动了',
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