import 'package:flutter/material.dart';
import 'package:iacg/services/search_service.dart';
import 'package:iacg/widgets/post_card.dart';

class SearchEventsTab extends StatefulWidget {
  final SearchService searchService;
  final String keyword;

  const SearchEventsTab({
    super.key,
    required this.searchService,
    required this.keyword,
  });

  @override
  State<SearchEventsTab> createState() => _SearchEventsTabState();
}

class _SearchEventsTabState extends State<SearchEventsTab> with AutomaticKeepAliveClientMixin {
  late Future<List<Map<String, dynamic>>> _searchFuture;
  String _orderBy = 'hot';
  bool _isLoading = false;
  final List<Map<String, dynamic>> _posts = [];
  final ScrollController _scrollController = ScrollController();
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchFuture = _performSearch();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _loadMore();
      }
    }
  }

  // 加载更多
  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    
    setState(() => _isLoading = true);
    
    try {
      final result = await widget.searchService.searchEvents(
        query: widget.keyword,
        limit: _limit,
        offset: _offset + _limit,
        orderBy: _orderBy,
      );
      
      setState(() {
        _posts.addAll(result);
        _offset += _limit;
        _hasMore = result.length == _limit;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void didUpdateWidget(SearchEventsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keyword != widget.keyword) {
      _refreshSearch();
    }
  }

  Future<List<Map<String, dynamic>>> _performSearch() async {
    if (widget.keyword.isEmpty) return [];
    
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await widget.searchService.searchEvents(
        query: widget.keyword,
        orderBy: _orderBy,
        limit: _limit,
      );
      return result;
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _refreshSearch() {
    setState(() {
      _posts.clear(); // 清空现有数据
      _offset = 0;
      _hasMore = true;
      _searchFuture = _performSearch();
    });
  }

  void _changeOrderBy(String newOrderBy) {
    if (_orderBy != newOrderBy) {
      setState(() {
        _orderBy = newOrderBy;
        _posts.clear(); // 清空数据
        _offset = 0;
        _hasMore = true;
        _refreshSearch();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        // 排序选项
        Container(
          color: Colors.grey[50],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                '排序方式:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 16),
              _buildOrderChip('最热', 'hot'),
              const SizedBox(width: 12),
              _buildOrderChip('最新', 'latest'),
            ],
          ),
        ),

        // 搜索结果
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _searchFuture,
            builder: (context, snapshot) {
              if (_isLoading && _posts.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.connectionState == ConnectionState.waiting && _posts.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        '搜索出错',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshSearch,
                        child: const Text('重新搜索'),
                      ),
                    ],
                  ),
                );
              }

              final posts = snapshot.data ?? [];

              // 同步数据到 _posts
              if (_posts.isEmpty && posts.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() {
                    _posts.addAll(posts);
                    _hasMore = posts.length == _limit;
                  });
                });
              }

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

              if (_posts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        '没有找到相关活动',
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

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8),
                itemCount: _posts.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _posts.length) {
                    return _hasMore 
                        ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : const SizedBox();
                  }
                  final post = _posts[index];
                  return PostCard(
                    post: post,
                    compactMode: true, // 使用紧凑模式
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOrderChip(String label, String value) {
    final isSelected = _orderBy == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey[700],
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      selected: isSelected,
      selectedColor: Theme.of(context).primaryColor,
      backgroundColor: Colors.grey[200],
      onSelected: (selected) => _changeOrderBy(value),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
