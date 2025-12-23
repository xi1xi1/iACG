import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/search_service.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/empty_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iacg/features/post/post_detail_page.dart';

class EventSearchPage extends StatefulWidget {
  const EventSearchPage({super.key});

  @override
  State<EventSearchPage> createState() => _EventSearchPageState();
}

class _EventSearchPageState extends State<EventSearchPage> {
  final SearchService _searchService = SearchService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  List<String> _searchHistory = [];
  bool _showSearchResults = false;
  String _currentQuery = '';

  // 活动搜索结果状态
  final List<Map<String, dynamic>> _events = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  String _orderBy = 'hot';
  final ScrollController _scrollController = ScrollController();
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    _scrollController.addListener(_onScroll);
    // 自动聚焦搜索框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 加载搜索历史
  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('event_search_history') ?? [];
    setState(() {
      _searchHistory = history;
    });
  }

  // 保存搜索历史
  Future<void> _saveSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 去重并限制数量
    if (_currentQuery.isNotEmpty) {
      _searchHistory.remove(_currentQuery);
      _searchHistory.insert(0, _currentQuery);
      
      if (_searchHistory.length > 10) {
        _searchHistory = _searchHistory.sublist(0, 10);
      }
      
      await prefs.setStringList('event_search_history', _searchHistory);
    }
  }

  // 执行搜索
  void _performSearch([String? query]) {
    final searchQuery = query ?? _searchController.text.trim();
    if (searchQuery.isEmpty) return;

    setState(() {
      _currentQuery = searchQuery;
      _showSearchResults = true;
      _events.clear();
      _offset = 0;
      _hasMore = true;
      _isLoading = true;
      _error = null;
    });

    // 保存到历史记录
    _saveSearchHistory();
    
    // 隐藏键盘
    _searchFocusNode.unfocus();

    // 执行搜索
    _loadEvents();
  }

  // 加载活动数据
  Future<void> _loadEvents() async {
    if (_currentQuery.isEmpty) return;

    try {
      final result = await _searchService.searchEvents(
        query: _currentQuery,
        orderBy: _orderBy,
        limit: _limit,
        offset: _offset,
      );
      
      setState(() {
        _events.addAll(result);
        _hasMore = result.length == _limit;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = '搜索失败: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 加载更多
  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _currentQuery.isEmpty) return;
    
    setState(() => _isLoadingMore = true);
    
    try {
      _offset += _limit;
      final result = await _searchService.searchEvents(
        query: _currentQuery,
        orderBy: _orderBy,
        limit: _limit,
        offset: _offset,
      );
      
      setState(() {
        _events.addAll(result);
        _hasMore = result.length == _limit;
      });
    } catch (e) {
      _offset -= _limit; // 加载失败，回退offset
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载更多失败: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore && !_isLoading) {
        _loadMore();
      }
    }
  }

  // 清空搜索历史
  Future<void> _clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('event_search_history');
    setState(() {
      _searchHistory = [];
    });
  }

  // 删除单条历史记录
  Future<void> _deleteHistoryItem(int index) async {
    setState(() {
      _searchHistory.removeAt(index);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('event_search_history', _searchHistory);
  }

  // 改变排序方式
  void _changeOrderBy(String newOrderBy) {
    if (_orderBy != newOrderBy) {
      setState(() {
        _orderBy = newOrderBy;
        _events.clear();
        _offset = 0;
        _hasMore = true;
        _isLoading = true;
      });
      _loadEvents();
    }
  }

  // 获取活动图片URL
  String? _getEventImageUrl(Map<String, dynamic> event) {
    try {
      // 从post_media字段获取图片
      final postMedia = event['post_media'];
      if (postMedia != null && postMedia is List && postMedia.isNotEmpty) {
        // 获取第一张图片
        final firstMedia = postMedia.first;
        if (firstMedia is Map<String, dynamic>) {
          final mediaUrl = firstMedia['media_url'] as String?;
          if (mediaUrl != null && mediaUrl.isNotEmpty) {
            return mediaUrl;
          }
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  // 构建活动卡片 - 使用左图右文布局
  Widget _buildEventCard(Map<String, dynamic> event) {
    final imageUrl = _getEventImageUrl(event);
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    
    // 映射字段名：从帖子字段映射到活动字段
    final title = event['title']?.toString() ?? '未知活动';
    final city = event['event_city']?.toString() ?? '未知城市';
    final location = event['event_location']?.toString() ?? '未知地点';
    final startTime = event['event_start_time']?.toString();
    final endTime = event['event_end_time']?.toString();
    final ticketUrl = event['event_ticket_url']?.toString();
    final postId = event['id'] as int?;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: () {
          if (postId != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PostDetailPage(postId: postId),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('活动详情暂不可用')),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 图片部分 - 左边，固定尺寸（包括占位符）
              Container(
                width: 80, // 1.5cm ≈ 90dp
                height: 120, // 2.5cm ≈ 150dp
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade100,
                  border: hasImage ? null : Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: hasImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.shade100,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey.shade100,
                            child: const Center(
                              child: Icon(
                                Icons.photo_library_outlined,
                                size: 24,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.event_available,
                          size: 24,
                          color: Colors.grey,
                        ),
                      ),
              ),
              
              // 内容部分 - 右边
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 活动标题
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    
                    // 地点信息
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '$city · $location',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    
                    // 时间信息
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _formatEventTime(startTime, endTime),
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    // 如果有票务链接，显示票务信息
                    if (ticketUrl != null && ticketUrl.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Icon(Icons.confirmation_number_outlined, size: 14, color: Colors.orange.shade600),
                            const SizedBox(width: 4),
                            Text(
                              '可购票',
                              style: TextStyle(fontSize: 13, color: Colors.orange.shade600, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatEventTime(String? startTime, String? endTime) {
    try {
      if (startTime == null || endTime == null) {
        return '时间未知';
      }
      final start = DateTime.parse(startTime);
      final end = DateTime.parse(endTime);
      
      // 如果是同一天
      if (start.year == end.year && start.month == end.month && start.day == end.day) {
        return '${start.month}月${start.day}日 ${_formatHour(start.hour)}:${_formatMinute(start.minute)}-${_formatHour(end.hour)}:${_formatMinute(end.minute)}';
      } else {
        return '${start.month}月${start.day}日-${end.month}月${end.day}日';
      }
    } catch (e) {
      return '时间未知';
    }
  }

  String _formatHour(int hour) {
    return hour < 10 ? '0$hour' : '$hour';
  }

  String _formatMinute(int minute) {
    return minute < 10 ? '0$minute' : '$minute';
  }

  // 构建排序选项
  Widget _buildOrderOptions() {
    return Container(
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

  // 构建加载更多指示器
  Widget _buildLoadMoreIndicator() {
    if (!_hasMore && _events.isNotEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            '已经到底了～',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return _isLoadingMore
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          )
        : const SizedBox.shrink();
  }

  // 构建搜索输入框
  Widget _buildSearchField() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 返回按钮
          IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.grey,
              size: 20,
            ),
            onPressed: () {
              if (_showSearchResults) {
                setState(() {
                  _showSearchResults = false;
                  _searchController.clear();
                });
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          // 搜索输入框
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: const InputDecoration(
                hintText: '搜索活动...',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              onSubmitted: (_) => _performSearch(),
              onChanged: (value) {
                setState(() {}); // 重新构建以更新清除按钮
              },
            ),
          ),
          // 清除/搜索按钮
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.clear,
                color: Colors.grey,
                size: 20,
              ),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _showSearchResults = false;
                });
              },
            )
          else
            IconButton(
              icon: const Icon(
                Icons.search,
                color: Color(0xFFED7099),
                size: 20,
              ),
              onPressed: () => _performSearch(),
            ),
        ],
      ),
    );
  }

  // 构建搜索结果界面
  Widget _buildSearchResults() {
    return Column(
      children: [
        // 排序选项
        _buildOrderOptions(),
        
        // 搜索结果列表
        Expanded(
          child: _isLoading
              ? const LoadingView()
              : _error != null
                  ? ErrorView(
                      error: _error!, 
                      onRetry: () {
                        setState(() {
                          _isLoading = true;
                          _error = null;
                        });
                        _loadEvents();
                      })
                  : _events.isEmpty
                      ? const EmptyView()
                      : RefreshIndicator(
                          onRefresh: () async {
                            setState(() {
                              _events.clear();
                              _offset = 0;
                              _hasMore = true;
                              _isLoading = true;
                            });
                            await _loadEvents();
                          },
                          child: ListView.builder(
                            controller: _scrollController,
                            itemCount: _events.length + 1,
                            itemBuilder: (context, index) {
                              if (index == _events.length) {
                                return _buildLoadMoreIndicator();
                              }
                              final event = _events[index];
                              return _buildEventCard(event);
                            },
                          ),
                        ),
        ),
    ],
    );
  }

  // 构建搜索历史界面
  Widget _buildSearchHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 热门搜索推荐
        _buildHotSearches(),
        
        // 搜索历史标题
        if (_searchHistory.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '搜索历史',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                GestureDetector(
                  onTap: _clearSearchHistory,
                  child: Text(
                    '清空',
                    style: TextStyle(
                      color: Color(0xFFED7099),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        // 历史记录列表
        if (_searchHistory.isNotEmpty)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _searchHistory.length,
              itemBuilder: (context, index) {
                final historyItem = _searchHistory[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Colors.grey.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(0xFFED7099).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.history,
                        color: Color(0xFFED7099),
                        size: 18,
                      ),
                    ),
                    title: Text(
                      historyItem,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 15,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.grey,
                      ),
                      onPressed: () => _deleteHistoryItem(index),
                    ),
                    onTap: () {
                      _searchController.text = historyItem;
                      _performSearch(historyItem);
                    },
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                );
              },
            ),
          ),
        
        // 空状态
        if (_searchHistory.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Color(0xFFED7099).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.search,
                      size: 40,
                      color: Color(0xFFED7099),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无搜索历史',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '输入关键词开始搜索吧',
                    style: TextStyle(
                      color: Colors.grey.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // 构建热门搜索推荐
  Widget _buildHotSearches() {
    final hotSearches = [
      '漫展',
      '动漫展',
      'COSPLAY活动',
      '同人展',
      '游戏展',
      '签售会',
      '见面会',
      '演唱会',
      '二次元活动'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            '热门搜索',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: hotSearches.map((keyword) {
              return GestureDetector(
                onTap: () {
                  _searchController.text = keyword;
                  _performSearch(keyword);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    keyword,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: _buildSearchField(),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
      ),
      body: _showSearchResults ? _buildSearchResults() : _buildSearchHistory(),
    );
  }
}
