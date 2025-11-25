import 'package:flutter/material.dart';
import '../../services/event_service.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/empty_view.dart';
import 'package:iacg/features/post/post_detail_page.dart';

class HomeEventsTab extends StatefulWidget {
  final List<Map<String, dynamic>>? events;
  const HomeEventsTab({super.key, this.events});

  @override
  State<HomeEventsTab> createState() => _HomeEventsTabState();
}

class _HomeEventsTabState extends State<HomeEventsTab> {
  final List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;

  // 分页相关变量
  int _currentPage = 1;
  bool _hasMore = true;
  final int _pageSize = 10;

  final ScrollController _scrollController = ScrollController();
  final EventService _eventService = EventService();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);

    // 如果有传入的活动数据，直接使用
    if (widget.events != null && widget.events!.isNotEmpty) {
      setState(() {
        _events.addAll(widget.events!);
        _isLoading = false;
        _hasMore = widget.events!.length >= _pageSize;
      });
    } else {
      _loadEvents();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMore &&
        _hasMore &&
        !_isLoading) {
      _loadMoreEvents();
    }
  }

  Future<void> _loadEvents({bool isRefresh = false}) async {
    try {
      setState(() {
        if (isRefresh) {
          _currentPage = 1;
          _hasMore = true;
          _events.clear();
        }
        _isLoading = true;
        _error = null;
      });

      final result = await _eventService.fetchUpcomingEvents(
        page: isRefresh ? 1 : _currentPage,
        pageSize: _pageSize,
      );

      setState(() {
        if (isRefresh) {
          _events.clear();
        }
        _events.addAll(result);
        _hasMore = result.length >= _pageSize;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = '加载失败: ${e.toString()}';
        if (isRefresh) {
          _events.clear();
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreEvents() async {
    if (_isLoadingMore || !_hasMore) return;

    try {
      setState(() {
        _isLoadingMore = true;
      });

      _currentPage++;

      final result = await _eventService.fetchUpcomingEvents(
        page: _currentPage,
        pageSize: _pageSize,
      );

      setState(() {
        _events.addAll(result);
        _hasMore = result.length >= _pageSize;
      });
    } catch (e) {
      _currentPage--; // 加载失败，回退页码
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载更多失败: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
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

  // 跳转到活动详情页
  void _navigateToEventDetail(Map<String, dynamic> event) {
    final postId = event['post_id'] as int?;
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
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _navigateToEventDetail(event),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event['name']?.toString() ?? '未知活动',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${event['city'] ?? '未知城市'} · ${event['location'] ?? '未知地点'}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    _formatEventTime(event['start_time'], event['end_time']),
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
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
      return '${start.month}月${start.day}日 - ${end.month}月${end.day}日';
    } catch (e) {
      return '时间未知';
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const LoadingView()
        : _error != null
            ? ErrorView(
                error: _error!, onRetry: () => _loadEvents(isRefresh: true))
            : _events.isEmpty
                ? const EmptyView()
                : RefreshIndicator(
                    onRefresh: () => _loadEvents(isRefresh: true),
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
                  );
  }
}
