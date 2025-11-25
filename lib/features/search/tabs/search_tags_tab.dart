// lib/pages/search/tabs/search_tags_tab.dart
import 'package:flutter/material.dart';
import 'package:iacg/features/tag/tag_posts_page.dart';
import 'package:iacg/services/search_service.dart';
import 'package:iacg/services/tag_service.dart';

class SearchTagsTab extends StatefulWidget {
  final SearchService searchService;
  final String keyword;

  const SearchTagsTab({
    Key? key,
    required this.searchService,
    required this.keyword,
  }) : super(key: key);

  @override
  State<SearchTagsTab> createState() => _SearchTagsTabState();
}

class _SearchTagsTabState extends State<SearchTagsTab> with AutomaticKeepAliveClientMixin {
  final TagService _tagService = TagService();
  final List<Map<String, dynamic>> _tags = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _pageSize = 20;
  ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }

  @override
  void didUpdateWidget(SearchTagsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keyword != widget.keyword) {
      _resetSearch();
    }
  }

  void _resetSearch() {
    setState(() {
      _tags.clear();
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
      // 搜索标签
      final newTags = await widget.searchService.searchTags(
        query: widget.keyword,
        limit: _pageSize,
        offset: (reset ? 0 : _tags.length),
      );

      // 为每个标签获取参与度（帖子数量）
      final tagsWithCounts = await Future.wait(
        newTags.map((tag) async {
          final tagId = tag['id'] as int;
          final postCount = await _tagService.countTagPosts(tagId: tagId);
          return {
            ...tag,
            'post_count': postCount,
          };
        }),
      );

      // 按参与度排序
      tagsWithCounts.sort((a, b) {
        final countA = a['post_count'] as int;
        final countB = b['post_count'] as int;
        return countB.compareTo(countA); // 降序排列
      });

      setState(() {
        if (reset) {
          _tags.clear();
        }
        _tags.addAll(tagsWithCounts);
        _hasMore = tagsWithCounts.length == _pageSize;
        _currentPage++;
      });
    } catch (error) {
      print('搜索标签出错: $error');
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

    if (_tags.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '没有找到相关标签',
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
        if (_tags.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            alignment: Alignment.centerLeft,
            child: Text(
              '找到 ${_tags.length} 个标签${_hasMore ? '+' : ''}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),

        // 标签网格
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
            ),
            itemCount: _tags.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= _tags.length) {
                // 加载更多指示器
                return _buildLoadingIndicator();
              }
              return _buildTagCard(_tags[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade50,
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildTagCard(Map<String, dynamic> tag) {
    final String tagName = tag['name'] ?? '';
    final String tagType = tag['type'] ?? '';
    final int postCount = tag['post_count'] ?? 0;
    final int tagId = tag['id'] as int;

    // 根据标签类型设置颜色
    final Color cardColor = _getTagColor(tagType);
    final Color textColor = _getTextColor(tagType);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _navigateToTagPage(context, tagId, tagName);
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: cardColor,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 标签名称
              Text(
                '#$tagName',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              // 标签类型和参与度
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标签类型
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: textColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getTypeDisplayName(tagType),
                      style: TextStyle(
                        fontSize: 10,
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 参与度
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 14,
                        color: textColor.withOpacity(0.8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$postCount 参与',
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTagColor(String tagType) {
    switch (tagType) {
      case 'ip':
        return Colors.blue.shade50;
      case 'style':
        return Colors.purple.shade50;
      case 'theme':
        return Colors.orange.shade50;
      case 'user':
        return Colors.green.shade50;
      case 'system':
        return Colors.grey.shade100;
      default:
        return Colors.grey.shade50;
    }
  }

  Color _getTextColor(String tagType) {
    switch (tagType) {
      case 'ip':
        return Colors.blue.shade800;
      case 'style':
        return Colors.purple.shade800;
      case 'theme':
        return Colors.orange.shade800;
      case 'user':
        return Colors.green.shade800;
      case 'system':
        return Colors.grey.shade800;
      default:
        return Colors.grey.shade800;
    }
  }

  String _getTypeDisplayName(String tagType) {
    switch (tagType) {
      case 'ip':
        return 'IP';
      case 'style':
        return '风格';
      case 'theme':
        return '主题';
      case 'user':
        return '用户';
      case 'system':
        return '系统';
      default:
        return tagType;
    }
  }

  void _navigateToTagPage(BuildContext context, int tagId, String tagName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TagPostsPage(tagName: tagName),
      ),
    );
  }
}