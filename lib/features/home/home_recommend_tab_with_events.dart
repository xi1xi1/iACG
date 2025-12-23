import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../services/event_service.dart';
import '../../services/post_service.dart';
import '../../widgets/post_card.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/empty_view.dart';
import 'package:iacg/features/post/post_detail_page.dart';
import 'package:flutter/foundation.dart'; 
class HomeRecommendTabWithEvents extends StatefulWidget {
  const HomeRecommendTabWithEvents({super.key});

  @override
  State<HomeRecommendTabWithEvents> createState() =>
      _HomeRecommendTabWithEventsState();
}

class _HomeRecommendTabWithEventsState
    extends State<HomeRecommendTabWithEvents> {
  final List<Map<String, dynamic>> _posts = [];
  final List<Map<String, dynamic>> _events = [];
  bool _isPostsLoading = true;
  bool _isEventsLoading = true;
  bool _isLoadingMore = false;
  String? _postsError;
  String? _eventsError;
final Set<int> _loadedPostIds = <int>{};
  // 分页相关变量
  int _currentPage = 1;
  bool _hasMore = true;
  final int _pageSize = 10;

  final PageController _eventPageController =
      PageController(viewportFraction: 0.95);
  int _currentEventPage = 0;
  final ScrollController _scrollController = ScrollController();
  final PostService _postService = PostService();
  final EventService _eventService = EventService();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadInitialData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _eventPageController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    // 当滚动到距离底部300像素时开始加载更多
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMorePosts();
    }
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadEvents(),
      _loadPosts(isRefresh: true),
    ]);
  }

  Future<void> _loadEvents() async {
    try {
      setState(() {
        _isEventsLoading = true;
        _eventsError = null;
      });

      final result = await _eventService.fetchHomePageEvents();
      setState(() {
        _events.clear();
        _events.addAll(result);
      });
    } catch (e) {
      setState(() {
        _eventsError = e.toString();
      });
    } finally {
      setState(() {
        _isEventsLoading = false;
      });
    }
  }
  // 修改后的 _loadPosts 方法
  Future<void> _loadPosts({bool isRefresh = false}) async {
    try {
      setState(() {
        if (isRefresh) {
          _currentPage = 1;
          _hasMore = true;
          _posts.clear();
          _loadedPostIds.clear(); // ✅ 刷新时清空已加载的ID
        }
        _isPostsLoading = true;
        _postsError = null;
      });

      // 使用新的热门帖子算法
      final result = await _postService.fetchHotPostsWithTimeDecay(
        limit: _pageSize,
        offset: isRefresh ? 0 : (_currentPage - 1) * _pageSize,
      );

      // ✅ 新增：过滤掉已经加载过的帖子
      final newPosts = <Map<String, dynamic>>[];
      for (final post in result) {
        final postId = post['id'] as int?;
        if (postId != null && !_loadedPostIds.contains(postId)) {
          newPosts.add(post);
          _loadedPostIds.add(postId);
        }
      }

      // ✅ 调试信息（可选）
      if (kDebugMode && result.isNotEmpty && newPosts.length != result.length) {
        print('🔄 过滤了 ${result.length - newPosts.length} 条重复帖子');
      }

      setState(() {
        if (isRefresh) {
          _posts.clear();
        }
        _posts.addAll(newPosts);
        // ✅ 修改：根据去重后的数量判断是否有更多
        _hasMore = newPosts.length >= _pageSize;
        _postsError = null;
      });
    } catch (e) {
      setState(() {
        _postsError = '加载失败: ${e.toString()}';
        if (isRefresh) {
          _posts.clear();
          _loadedPostIds.clear();
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPostsLoading = false;
        });
      }
    }
  }

  // 修改后的 _loadMorePosts 方法
  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMore) return;

    try {
      setState(() {
        _isLoadingMore = true;
      });

      _currentPage++;

      final result = await _postService.fetchHotPostsWithTimeDecay(
        limit: _pageSize,
        offset: (_currentPage - 1) * _pageSize,
      );

      // ✅ 新增：同样的去重逻辑
      final newPosts = <Map<String, dynamic>>[];
      for (final post in result) {
        final postId = post['id'] as int?;
        if (postId != null && !_loadedPostIds.contains(postId)) {
          newPosts.add(post);
          _loadedPostIds.add(postId);
        }
      }

      // ✅ 新增：如果没有新数据，认为没有更多了
      if (newPosts.isEmpty) {
        setState(() {
          _hasMore = false;
        });
        return;
      }

      setState(() {
        _posts.addAll(newPosts);
        // ✅ 修改：根据去重后的数量判断是否有更多
        _hasMore = newPosts.length >= _pageSize;
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

// // 修改后的 _loadPosts 方法
// Future<void> _loadPosts({bool isRefresh = false}) async {
//   try {
//     setState(() {
//       if (isRefresh) {
//         _currentPage = 1;
//         _hasMore = true;
//         _posts.clear();
//         _loadedPostIds.clear(); // ✅ 刷新时清空已加载的ID
//       }
//       _isPostsLoading = true;
//       _postsError = null;
//     });

//     // 使用新的热门帖子算法
//     final result = await _postService.fetchHotPostsWithTimeDecay(
//       limit: _pageSize,
//       offset: isRefresh ? 0 : (_currentPage - 1) * _pageSize,
//     );
    

//     setState(() {
//       if (isRefresh) {
//         _posts.clear();
//       }
//       _posts.addAll(result);
//       _hasMore = result.length >= _pageSize;
//       _postsError = null;
//     });
//   } catch (e) {
//     setState(() {
//       _postsError = '加载失败: ${e.toString()}';
//       if (isRefresh) {
//         _posts.clear();
//       }
//     });
//   } finally {
//     if (mounted) {
//       setState(() {
//         _isPostsLoading = false;
//       });
//     }
//   }
// }

// // 修改后的 _loadMorePosts 方法
// Future<void> _loadMorePosts() async {
//   if (_isLoadingMore || !_hasMore) return;

//   try {
//     setState(() {
//       _isLoadingMore = true;
//     });

//     _currentPage++;

//     final result = await _postService.fetchHotPostsWithTimeDecay(
//       limit: _pageSize,
//       offset: (_currentPage - 1) * _pageSize,
//     );

//     setState(() {
//       _posts.addAll(result);
//       _hasMore = result.length >= _pageSize;
//     });
//   } catch (e) {
//     _currentPage--; // 加载失败，回退页码
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('加载更多失败: ${e.toString()}'),
//           duration: const Duration(seconds: 2),
//         ),
//       );
//     }
//   } finally {
//     if (mounted) {
//       setState(() {
//         _isLoadingMore = false;
//       });
//     }
//   }
// }
  // Future<void> _loadPosts({bool isRefresh = false}) async {
  //   try {
  //     setState(() {
  //       if (isRefresh) {
  //         _currentPage = 1;
  //         _hasMore = true;
  //         _posts.clear();
  //       }
  //       _isPostsLoading = true;
  //       _postsError = null;
  //     });

  //     final result = await _postService.fetchRecommendPosts(
  //       limit: _pageSize,
  //       offset: (isRefresh ? 0 : _currentPage - 1) * _pageSize,
  //     );

  //     setState(() {
  //       if (isRefresh) {
  //         _posts.clear();
  //       }
  //       _posts.addAll(result);
  //       _hasMore = result.length >= _pageSize;
  //       _postsError = null;
  //     });
  //   } catch (e) {
  //     setState(() {
  //       _postsError = '加载失败: ${e.toString()}';
  //       if (isRefresh) {
  //         _posts.clear();
  //       }
  //     });
  //   } finally {
  //     if (mounted) {
  //       setState(() {
  //         _isPostsLoading = false;
  //       });
  //     }
  //   }
  // }

  // Future<void> _loadMorePosts() async {
  //   if (_isLoadingMore || !_hasMore) return;

  //   try {
  //     setState(() {
  //       _isLoadingMore = true;
  //     });

  //     _currentPage++;

  //     final result = await _postService.fetchRecommendPosts(
  //       limit: _pageSize,
  //       offset: (_currentPage - 1) * _pageSize,
  //     );

  //     setState(() {
  //       _posts.addAll(result);
  //       _hasMore = result.length >= _pageSize;
  //     });
  //   } catch (e) {
  //     _currentPage--; // 加载失败，回退页码
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('加载更多失败: ${e.toString()}'),
  //           duration: const Duration(seconds: 2),
  //         ),
  //       );
  //     }
  //   } finally {
  //     if (mounted) {
  //       setState(() {
  //         _isLoadingMore = false;
  //       });
  //     }
  //   }
  // }

  // 构建活动预览部分
  Widget _buildEventsPreview() {
    if (_isEventsLoading) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_eventsError != null) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('加载失败: $_eventsError', style: const TextStyle(fontSize: 12)),
              TextButton(
                onPressed: _loadEvents,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_events.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('暂无活动', style: TextStyle(fontSize: 12)),
              TextButton(
                onPressed: _loadEvents,
                child: const Text('刷新'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: Stack(
            children: [
              PageView.builder(
                controller: _eventPageController,
                itemCount: _events.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentEventPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  return _buildEventCard(_events[index]);
                },
              ),

              // 分页指示器
              if (_events.length > 1)
                Positioned(
                  right: 32,
                  bottom: 16,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: List.generate(_events.length, (index) {
                        return Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentEventPage == index
                                ? Colors.white
                                : Colors.white.withOpacity(0.4),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              height: 180,
              color: Colors.grey[200],
              child: _getEventImage(event),
            ),
            Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 16,
              bottom: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event['name']?.toString() ?? '未知活动',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 4,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (event['event_type'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFED7099).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        event['event_type'].toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    _navigateToEventPostDetail(event);
                  },
                  splashColor: const Color(0xFFED7099).withOpacity(0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getEventImage(Map<String, dynamic> event) {
    if (event['post_media'] != null && event['post_media'] is List) {
      final mediaList = event['post_media'] as List;
      if (mediaList.isNotEmpty) {
        List<dynamic> sortedMedia = List.from(mediaList);
        sortedMedia.sort((a, b) {
          final orderA = (a['sort_order'] as num?)?.toInt() ?? 0;
          final orderB = (b['sort_order'] as num?)?.toInt() ?? 0;
          return orderA.compareTo(orderB);
        });

        final firstMedia = sortedMedia.first;
        if (firstMedia is Map) {
          final imageUrl = firstMedia['media_url'];
          final mediaType = firstMedia['media_type'];

          if (imageUrl != null &&
              imageUrl.toString().isNotEmpty &&
              mediaType == 'image') {
            return Image.network(
              imageUrl.toString(),
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildEventPlaceholder('图片加载失败');
              },
            );
          }
        }
      }
    }

    if (event['cover_image'] != null &&
        event['cover_image'].toString().isNotEmpty) {
      return Image.network(
        event['cover_image'].toString(),
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildEventPlaceholder('图片加载失败');
        },
      );
    }

    return _buildEventPlaceholder('暂无图片');
  }

  Widget _buildEventPlaceholder(String message) {
    return Container(
      color: Colors.grey[300],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event, size: 48, color: Colors.grey[500]),
          const SizedBox(height: 8),
          Text(message,
              style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }

  void _navigateToEventPostDetail(Map<String, dynamic> event) {
    final postId = event['post_id'];
    if (postId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PostDetailPage(postId: postId as int),
        ),
      );
    } else {
      final post = event['post'];
      if (post != null && post is Map && post['id'] != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PostDetailPage(postId: post['id'] as int),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('活动详情暂不可用')),
        );
      }
    }
  }

  // 构建加载更多指示器
  Widget _buildLoadMoreIndicator() {
    if (!_hasMore && _posts.isNotEmpty) {
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

  // 构建内容
  Widget _buildContent() {
    if (_isPostsLoading && _posts.isEmpty) {
      return const LoadingView();
    }

    if (_postsError != null) {
      return ErrorView(
        error: _postsError!,
        onRetry: () => _loadPosts(isRefresh: true),
      );
    }

    return RefreshIndicator(
      onRefresh: () => Future.wait([
        _loadEvents(),
        _loadPosts(isRefresh: true),
      ]),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 活动预览
          SliverToBoxAdapter(
            child: _buildEventsPreview(),
          ),
          // 帖子列表
          SliverToBoxAdapter(
            child: MasonryGridView.builder(
              gridDelegate:
                  const SliverSimpleGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
              ),
              mainAxisSpacing: 1,
              crossAxisSpacing: 1,
              padding: const EdgeInsets.all(1),
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: _posts.length,
              itemBuilder: (context, index) {
                return PostCard(
                  post: _posts[index],
                );
              },
            ),
          ),
          // 加载更多指示器
          SliverToBoxAdapter(
            child: _buildLoadMoreIndicator(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildContent();
  }
}
