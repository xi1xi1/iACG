import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/event_service.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/empty_view.dart';
import 'package:iacg/features/post/post_detail_page.dart';
import 'package:iacg/features/post/post_compose_page.dart';
import 'package:iacg/features/search/event_search_page.dart';

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

  // 用户身份状态
  bool _isOrganizer = false;
  bool _loadingUserRole = true;
  final AuthService _authService = AuthService();

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
    _checkUserRole();

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

  // 检查用户是否是活动组织者
  Future<void> _checkUserRole() async {
    try {
      // 首先检查用户是否登录
      if (!_authService.isLoggedIn) {
        setState(() {
          _isOrganizer = false;
          _loadingUserRole = false;
        });
        return;
      }

      // 获取用户资料并检查角色
      final profile = await ProfileService().fetchMyProfile();
      if (profile != null) {
        setState(() {
          _isOrganizer = profile.role == 'organizer';
          _loadingUserRole = false;
        });
        print('用户身份检查完成: isOrganizer = $_isOrganizer, role = ${profile.role}');
      } else {
        setState(() => _loadingUserRole = false);
      }
    } catch (e) {
      print('检查用户身份失败: $e');
      setState(() => _loadingUserRole = false);
    }
  }

  // 处理发布按钮点击
  void _handlePublishButtonTap() {
    // 检查用户是否登录
    if (!_authService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先登录才能发布活动'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // 检查用户是否是活动组织者
    if (!_isOrganizer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('只有活动组织者才能发布活动'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // 跳转到活动发布页
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PostComposePage(initialChannel: 'event'),
      ),
    );
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

  // 获取活动图片URL
  String? _getEventImageUrl(Map<String, dynamic> event) {
    try {
      // 从关联的帖子中获取图片数据
      final post = event['post'];
      if (post != null && post is Map<String, dynamic>) {
        final postMedia = post['post_media'];
        if (postMedia != null && postMedia is List && postMedia.isNotEmpty) {
          // 按 sort_order 排序，获取第一张图片
          List<dynamic> sortedMedia = List.from(postMedia);
          sortedMedia.sort((a, b) {
            final orderA = (a['sort_order'] as num?)?.toInt() ?? 0;
            final orderB = (b['sort_order'] as num?)?.toInt() ?? 0;
            return orderA.compareTo(orderB);
          });
          
          final firstMedia = sortedMedia.first;
          if (firstMedia is Map<String, dynamic>) {
            final mediaUrl = firstMedia['media_url'] as String?;
            final mediaType = firstMedia['media_type'] as String?;
            
            // 只返回图片类型的媒体
            if (mediaUrl != null && mediaUrl.isNotEmpty && mediaType == 'image') {
              return mediaUrl;
            }
          }
        }
      }
      
      // 如果没有帖子图片，尝试从 events 表的 cover_image 字段获取
      final coverImage = event['cover_image'] as String?;
      if (coverImage != null && coverImage.isNotEmpty) {
        return coverImage;
      }
      
      return null;
    } catch (e) {
      print('获取活动图片URL失败: $e');
      return null;
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

  // 构建活动卡片 - 使用左图右文布局（与EventSearchPage一致）
  Widget _buildEventCard(Map<String, dynamic> event) {
    final imageUrl = _getEventImageUrl(event);
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    
    // 映射字段名：从帖子字段映射到活动字段
    final title = event['name']?.toString() ?? '未知活动';
    final city = event['city']?.toString() ?? '未知城市';
    final location = event['location']?.toString() ?? '未知地点';
    final startTime = event['start_time']?.toString();
    final endTime = event['end_time']?.toString();
    final ticketUrl = event['ticket_url']?.toString();
    final postId = event['post_id'] as int?;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToEventDetail(event),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 图片部分 - 左边，固定尺寸（包括占位符）
              Container(
                width: 80, // 更合适的宽度
                height: 120, // 更合适的高度
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
                            _formatEventTime(startTime, endTime),//bug
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Image.asset(
            'assets/images/IACG_L.PNG',
            fit: BoxFit.contain,
          ),
        ),
        leadingWidth: 80,
        title: const Text(
          '活动',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          // 搜索按钮
          IconButton(
            icon: Icon(
              Icons.search,
              color: Colors.black,
              size: 24,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EventSearchPage()),
              );
            },
            tooltip: '搜索活动',
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingView()
          : _error != null
              ? ErrorView(
                  error: _error!, 
                  onRetry: () => _loadEvents(isRefresh: true))
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
                    ),
      // 右下角悬浮发布按钮 - 只在用户是活动组织者时显示
      floatingActionButton: _isOrganizer
          ? FloatingActionButton(
              onPressed: _handlePublishButtonTap,
              backgroundColor: const Color(0xFFED7099), // 使用与首页相同的粉色
              foregroundColor: Colors.white,
              elevation: 4,
              mini: true,
              child: const Icon(Icons.add),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
