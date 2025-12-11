import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iacg/features/auth/login_page.dart';
import 'package:iacg/features/post/post_compose_page.dart';
import 'package:iacg/features/post/repost_compose_page.dart';
import 'package:iacg/widgets/avatar_widget.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async'; 
import '../../services/post_service.dart';
import '../profile/user_profile_page.dart';
import '../tag/tag_posts_page.dart';
import 'post_image_preview.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:url_launcher/url_launcher.dart';
class PostDetailPage extends StatefulWidget {
  final int postId;
  const PostDetailPage({super.key, required this.postId});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final _postService = PostService();
  Map<String, dynamic>? _post;
  bool _loading = true;
  String? _error;

  bool _isLiked = false;
  bool _isFav = false;
  // 相关帖子
  List<Map<String, dynamic>> _relatedPosts = [];
  bool _loadingRelated = false;
  // 轮播
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  // ✅ 新增1：轮播图比例（基于第一张图）
  double? _carouselAspectRatio;
  
  // ✅ 新增2：标记是否已获取比例
  bool _hasLoadedRatio = false;
  // 评论输入
  final TextEditingController _commentCtrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  bool _sendingComment = false;

  // 顶层评论 Future（缓存，避免频繁刷新）
  late Future<List<Map<String, dynamic>>> _commentsFuture;
  Set<int> _myLikedCommentIds = <int>{}; // 我点赞过的【顶层】评论ID集合（用于首屏红心）
  int? _replyToId; // 正在回复的评论ID
  String? _replyToName; // 被回复者昵称（提示）

  // 新增：是否是作者状态
  bool _isAuthor = false;
  // 在类的顶部，其他状态变量之后添加：
  bool _showEventFab = false;
  String? _eventTagName;
  @override
  void initState() {
    super.initState();
    _loadDetail();
    _refreshComments(); // 初始化顶层评论

    // 延迟加载相关帖子，避免影响主内容加载
    Future.delayed(const Duration(milliseconds: 500), () {
      _loadRelatedPosts();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _commentCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }
  // 获取第一张图的比例
  Future<void> _loadFirstImageAspectRatio(List<String> imageUrls) async {
    if (_hasLoadedRatio || imageUrls.isEmpty) return;
    
    try {
      final firstUrl = imageUrls[0];
      final completer = Completer<double?>();
      
      final imageProvider = NetworkImage(firstUrl);
      final stream = imageProvider.resolve(ImageConfiguration.empty);
      
      final listener = ImageStreamListener(
        (ImageInfo info, bool _) {
          final width = info.image.width.toDouble();
          final height = info.image.height.toDouble();
          final ratio = width / height;
          
          // 限制比例范围，避免极端比例
          final clampedRatio = ratio.clamp(0.5, 2.0);
          completer.complete(clampedRatio);
        },
        onError: (error, stackTrace) {
          completer.complete(null); // 失败返回null
        },
      );
      
      stream.addListener(listener);
      
      // 设置超时
      Future.delayed(const Duration(seconds: 2), () {
        if (!completer.isCompleted) {
          stream.removeListener(listener);
          completer.complete(null);
        }
      });
      
      final ratio = await completer.future;
      
      if (mounted) {
        setState(() {
          _carouselAspectRatio = ratio ?? 3/4; // 失败时用默认3/4
          _hasLoadedRatio = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _carouselAspectRatio = 3/4;
          _hasLoadedRatio = true;
        });
      }
    }
  }
  // 新增：检查是否是作者
  Future<void> _checkIsAuthor() async {
    try {
      final isAuthor = await _postService.isPostAuthor(widget.postId);
      if (mounted) {
        setState(() {
          _isAuthor = isAuthor;
        });
      }
    } catch (e) {
      print('检查作者权限失败: $e');
    }
  }

  // 新增：删除帖子方法
  Future<void> _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除帖子'),
        content: const Text('确定要删除这个帖子吗？删除后其他用户将无法看到。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _postService.softDeletePost(widget.postId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('帖子已删除')),
          );

          // 返回上一页
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }


// ✅ 新增：跳转到发布页面并自动填充活动标签
// ✅ 修改：跳转到发布页面并自动填充活动标签（添加登录检查）
void _navigateToEventPostCompose() async {
  // 1. 首先检查用户是否登录
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) {
    // 用户未登录，显示提示
    if (mounted) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('需要登录'),
          content: const Text('登录后才能发布帖子，去登录吧～'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // 跳转到登录页面
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LoginPage(),
                  ),
                );
              },
              child: const Text('去登录', style: TextStyle(color: Color(0xFFED7099))),
            ),
          ],
        ),
      );
    }
    return;
  }

  if (_eventTagName == null || _eventTagName!.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('活动标签获取失败'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }
  
  print('跳转到发布页面，活动标签: $_eventTagName');
 // ✅ 新增：弹出选择对话框
showDialog(
  context: context,
  builder: (context) => Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFCF1F5), // 顶部浅粉色
            Colors.white,            // 底部白色
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFED7099).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFFED7099),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '选择发布类型',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          
          // COS作品选项
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _goToPostCompose('cos', _eventTagName!);
                },
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // 图标
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFED7099).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Color(0xFFED7099),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // 文字内容
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'COS作品',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '发布COS照片作品',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // 箭头
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: Colors.grey[500],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // 群岛帖子选项
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _goToPostCompose('island', _eventTagName!);
                },
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // 图标 - 也使用粉色
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFED7099).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.forum,
                          color: Color(0xFFED7099), // 同样用粉色
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // 文字内容
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '群岛帖子',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '发布讨论、求助、分享',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // 箭头
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: Colors.grey[500],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 取消按钮 - 不使用整行灰色
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                    child: const Text(
                      '取消',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color.fromARGB(255, 139, 139, 139),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
}

// ✅ 新增：实际跳转到发布页面的方法
void _goToPostCompose(String channel, String eventTag) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PostComposePage(
        initialChannel: channel, // 根据选择传入频道
        autoFillTag: eventTag,
      ),
    ),
  );
}
  // 新增：构建更多操作菜单
  Widget _buildMoreActionsMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        if (value == 'delete') {
          _deletePost();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('删除帖子', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  // 加载相关帖子
  Future<void> _loadRelatedPosts() async {
    print('=== _loadRelatedPosts 开始 ===');

    if (_post == null) {
      print('帖子数据为空');
      return;
    }

    if (_post!['channel'] != 'event') {
      print('不是活动帖子，频道: ${_post!['channel']}');
      return;
    }

    final eventTag = _getEventTagFromPost(_post!);
    if (eventTag == null) {
      print('未找到活动标签，跳过加载相关帖子');
      return;
    }

    print('开始加载相关帖子，标签: $eventTag');
    setState(() => _loadingRelated = true);

    try {
      final related = await _postService.getRelatedPostsByEventTag(
        currentPostId: widget.postId,
        eventTag: eventTag,
        limit: 6,
      );
      print('获取到 ${related.length} 个相关帖子');
      setState(() => _relatedPosts = related);
    } catch (e) {
      print('加载相关帖子失败: $e');
    } finally {
      setState(() => _loadingRelated = false);
      print('=== _loadRelatedPosts 结束 ===');
    }
  }

  // 从帖子数据中提取活动标签
  String? _getEventTagFromPost(Map<String, dynamic> post) {
    try {
      print('=== 开始提取活动标签 ===');
      print('帖子ID: ${post['id']}');
      print('频道: ${post['channel']}');

      // 从 post_tags 中查找 type 为 'theme' 的标签
      final postTags = post['post_tags'] as List?;
      print('post_tags 数量: ${postTags?.length ?? 0}');

      if (postTags != null) {
        for (final tagRelation in postTags) {
          final tag = tagRelation['tag'] as Map<String, dynamic>?;
          print('标签数据: $tag');
          if (tag != null && tag['type'] == 'theme') {
            final tagName = tag['name'] as String?;
            print('找到活动标签: $tagName');
            return tagName;
          }
        }
      }

      print('未找到活动标签');
      return null;
    } catch (e) {
      print('提取活动标签失败: $e');
      return null;
    }
  }

  // ✅ 修改：相关帖子组件（横向滚动）
  Widget _buildRelatedPosts() {
    if (_post == null || _post!['channel'] != 'event') {
      return const SizedBox.shrink();
    }

    if (_loadingRelated) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_relatedPosts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            '相关帖子', // ✅ 修改标题
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),

        // 横向滚动列表
        SizedBox(
          height: 120, // 固定高度
          child: ListView.separated(
            scrollDirection: Axis.horizontal, // ✅ 横向滚动
            itemCount: _relatedPosts.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return _buildRelatedPostCard(_relatedPosts[index]);
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ✅ 修改：单个相关帖子卡片（横向布局）
  Widget _buildRelatedPostCard(Map<String, dynamic> post) {
    final mediaList = (post['post_media'] as List? ?? [])
      ..sort((a, b) => (a['sort_order'] ?? 0).compareTo(b['sort_order'] ?? 0));
    final hasImage = mediaList.isNotEmpty;
    final firstImage =
        hasImage ? mediaList.first['media_url'] as String? : null;
    final title = post['title'] ?? '';
    final content = post['content'] ?? '';
    final previewContent =
        content.length > 25 ? '${content.substring(0, 25)}...' : content;

    return SizedBox(
      width: 280, // 固定卡片宽度
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PostDetailPage(postId: post['id'] as int),
              ),
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 图片区域（只在有图片时显示）
                if (hasImage && firstImage != null) ...[
                  Container(
                    width: 60, // 更小的图片宽度
                    height: 60, // 正方形图片
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.grey[100],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: firstImage,
                        fit: BoxFit.cover,
                        // ✅ 添加图片尺寸限制
                        memCacheWidth: 300, // 相关帖子图片小，用固定值
                        maxWidthDiskCache: 300,
                        
                        placeholder: (_, __) => Container(color: Colors.grey[200]),
                        errorWidget: (_, __, ___) {
                          // ✅ 添加自动重试逻辑
                          Future.delayed(const Duration(milliseconds: 300), () async {
                            try {
                              await DefaultCacheManager().removeFile(firstImage);
                              if (mounted) setState(() {});
                            } catch (_) {}
                          });
                          
                          return Container(
                            color: Colors.grey[200],
                            alignment: Alignment.center,
                            child: const Icon(Icons.image, size: 20, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],

                // 内容区域
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 标题
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 4),

                      // 内容预览
                      if (previewContent.isNotEmpty)
                        Text(
                          previewContent,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                      const Spacer(),

                      // 活动时间（如果有）
                      if (post['event_start_time'] != null)
                        Text(
                          _formatEventDateShort(post['event_start_time']),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ 新增：简短时间格式化
  String _formatEventDateShort(dynamic date) {
    if (date == null) return '';
    try {
      final dateTime =
          date is String ? DateTime.tryParse(date) : date as DateTime?;
      if (dateTime == null) return '';
      return DateFormat('MM/dd').format(dateTime);
    } catch (e) {
      return '';
    }
  }

  Future<String?> _currentUserId() async {
    return Supabase.instance.client.auth.currentUser?.id;
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _postService.getPostDetail(widget.postId);
      if (!mounted) return;
      setState(() {
        _post = data;
        _currentIndex = 0;
      // ✅ 新增：检查是否是活动帖子，并获取活动标签
 if (data != null && data['channel'] == 'event') {
        _showEventFab = true;
        _eventTagName = _getEventTagFromPost(data);
      } else {
        _showEventFab = false;
        _eventTagName = null;
      }
    });

      // 查询已点赞/收藏状态（仅登录用户）
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        final liked = await _postService.hasLiked(widget.postId, uid);
        final faved = await _postService.hasFavorited(widget.postId, uid);
        if (!mounted) return;
        setState(() {
          _isLiked = liked;
          _isFav = faved;
        });
      }

      // 检查是否是作者
      await _checkIsAuthor();

      // 仅登录用户计浏览量
      await _postService.incrementViewCountIfAuthed(widget.postId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 刷新"顶层评论列表"与"我点赞过的顶层评论集合"
  Future<void> _refreshComments() async {
    final top = await _postService.listTopComments(widget.postId, limit: 100);
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
      final ids = top.map<int>((c) => c['id'] as int).toList();
      _myLikedCommentIds = await _postService.myLikedCommentIds(ids, uid);
    } else {
      _myLikedCommentIds = <int>{};
    }
    _commentsFuture = Future.value(top);
    if (mounted) setState(() {});
  }

  /// 单条评论点赞后，本地同步"我点赞过的顶层集合"
  Future<void> _refreshOneCommentLike(int commentId, bool nowLiked) async {
    setState(() {
      if (nowLiked) {
        _myLikedCommentIds = {..._myLikedCommentIds, commentId};
      } else {
        _myLikedCommentIds =
            _myLikedCommentIds.where((id) => id != commentId).toSet();
      }
    });
  }

  // 点赞（帖子层面的）
  Future<void> _handleLike() async {
    final uid = await _currentUserId();
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录再点赞')),
        );
      }
      return;
    }
    try {
      await _postService.likePost(widget.postId, uid);
      await _loadDetail();
    } catch (_) {
      await _postService.unlikePost(widget.postId, uid);
      await _loadDetail();
    }
  }

  // 收藏（帖子层面的）
  Future<void> _handleFavorite() async {
    final uid = await _currentUserId();
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录再收藏')),
        );
      }
      return;
    }
    try {
      await _postService.favoritePost(widget.postId, uid);
      await _loadDetail();
    } catch (_) {
      await _postService.unfavoritePost(widget.postId, uid);
      await _loadDetail();
    }
  }

  // 转发
  Future<void> _handleRepost() async {
    final uid = await _currentUserId();
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录再转发')),
        );
      }
      return;
    }

    // 跳转到转发页面
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RepostComposePage(originalPost: _post!),
      ),
    );

    // 如果转发成功，刷新数据
    if (result == true && mounted) {
      await _loadDetail();
    }
  }

  // 发送评论/回复（仅刷新评论区，不重拉整页）
  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _sendingComment) return;

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录再评论')),
        );
      }
      return;
    }

    setState(() => _sendingComment = true);
    try {
      await _postService.addComment(
        postId: widget.postId,
        userId: uid,
        text: text,
        parentId: _replyToId, // 有 parentId 则为回复
      );
      _commentCtrl.clear();
      _replyToId = null;
      _replyToName = null;
      FocusScope.of(context).unfocus();
      await _refreshComments(); // 只刷新顶层列表（各楼内由子组件自管）
      if (mounted && _post != null) {
        setState(() {
          _post!['comment_count'] = (_post!['comment_count'] ?? 0) + 1;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('评论失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  // 相对时间
  String _timeAgoFrom(dynamic createdAt) {
    if (createdAt == null) return '';
    final dt = createdAt is String
        ? DateTime.tryParse(createdAt)
        : (createdAt as DateTime?);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 30) return '${diff.inDays} 天前';
    final m = (diff.inDays / 30).floor();
    return '$m 个月前';
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'photographer':
        return '摄影';
      case 'makeup':
        return '妆造';
      case 'costume':
        return '服装/造型';
      case 'props':
        return '道具';
      case 'retouch':
        return '修图';
      default:
        return '合作';
    }
  }

  // 构建转发链内容显示（可点击的用户名）
  Widget _buildRepostChain(String content, Map<String, dynamic> currentPost) {
    // 按 '//@' 分割内容
    final parts = content.split('//@');

    if (parts.length == 1) {
      // 没有转发链，直接显示
      return Text(content, style: const TextStyle(fontSize: 16, height: 1.5));
    }

    final List<InlineSpan> textSpans = [];

    // 第一个部分是用户的评论
    if (parts[0].trim().isNotEmpty) {
      textSpans.add(TextSpan(
        text: parts[0].trim(),
        style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black),
      ));
    }

    // 处理每个转发链部分
    for (int i = 1; i < parts.length; i++) {
      final part = parts[i];

      // 添加 "//@" 前缀（除了第一个）
      if (i == 1 && textSpans.isNotEmpty) {
        textSpans.add(const TextSpan(text: ' '));
      }
      textSpans.add(const TextSpan(text: '//@'));

      // 解析用户ID、用户名和内容
      final idMatch = RegExp(r'^\[([^\]]+)\]').firstMatch(part);
      if (idMatch != null) {
        final userId = idMatch.group(1)!;
        final remaining = part.substring(idMatch.end);
        final nameMatch = RegExp(r'^([^：]+)：').firstMatch(remaining);

        if (nameMatch != null) {
          final userName = nameMatch.group(1)!;
          final userContent = remaining.substring(nameMatch.end).trim();

          // 用户ID和名称（可点击）
          textSpans.add(WidgetSpan(
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UserProfilePage(userId: userId),
                  ),
                );
              },
              child: Text(
                '[$userName]',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
          ));

          // 内容部分
          textSpans.add(TextSpan(
            text: '：$userContent',
            style:
                const TextStyle(fontSize: 16, height: 1.5, color: Colors.black),
          ));
        }
      }
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black),
        children: textSpans,
      ),
    );
  }

  // 构建内容显示（区分普通帖子和转发帖子）
  Widget _buildContentWithRepostChain(Map<String, dynamic> post) {
    final content = post['content']?.toString() ?? '';
    final isRepost = post['original_post_id'] != null;

    if (!isRepost) {
      // 普通帖子，直接显示内容
      return Text(content, style: const TextStyle(fontSize: 16, height: 1.5));
    }

    // 转发帖子，显示转发链
    return _buildRepostChain(content, post);
  }

  // 构建原帖信息显示
  Widget _buildOriginalPostInfo(Map<String, dynamic> post) {
    final isRepost = post['original_post_id'] != null;
    final originalPost = post['original_post'] as Map<String, dynamic>?;

    if (!isRepost || originalPost == null) {
      return const SizedBox.shrink();
    }

    final originalAuthor = originalPost['author'] ?? {};
    final originalAuthorName = originalAuthor['nickname'] ?? '佚名';
    final originalContent = originalPost['content'] ?? '';
    final originalTitle = originalPost['title'] ?? '';
    final originalId = originalPost['id'] as int;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.grey[50],
      child: InkWell(
        onTap: () {
          // 跳转到原帖
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PostDetailPage(postId: originalId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 原作者信息
              Row(
                children: [
                  AvatarWidget(
                    imageUrl: originalAuthor['avatar_url'] as String?,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(originalAuthorName,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios,
                      size: 14, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 8),

              // 原帖内容预览
              if (originalTitle.isNotEmpty)
                Text(originalTitle,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              if (originalContent.isNotEmpty) ...[
                if (originalTitle.isNotEmpty) const SizedBox(height: 4),
                Text(
                  originalContent,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 4),
              Text(
                '查看原帖',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 获取最原始的帖子，包装成转发帖格式
  Future<Map<String, dynamic>?> _getOriginalPost(
      Map<String, dynamic> post) async {
    var currentPost = post;
    Map<String, dynamic>? deepestOriginalPost;

    // 一直向上追溯，直到找到最原始的帖子
    while (currentPost['original_post_id'] != null) {
      final originalPostId = currentPost['original_post_id'] as int;
      final originalPost = await PostService().getPostDetail(originalPostId);

      if (originalPost != null) {
        currentPost = originalPost;
        deepestOriginalPost = originalPost; // 保存最原始的帖子
      } else {
        break;
      }
    }

    // 如果找到了原始帖子，创建一个转发帖结构的包装对象
    if (deepestOriginalPost != null &&
        deepestOriginalPost['id'] != post['id']) {
      return {
        'original_post_id': deepestOriginalPost['id'],
        'original_post': deepestOriginalPost, // 这里包含最原始帖子的完整信息
      };
    }

    return null;
  }

  // ✅ 新增：活动信息卡片
  // ✅ 修改：活动信息卡片（删除活动详细描述）
  Widget _buildEventInfoCard(Map<String, dynamic> post) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '活动信息',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (post['event_start_time'] != null &&
                post['event_end_time'] != null)
              _buildEventInfoRow('时间',
                  '${_formatEventDate(post['event_start_time'])} - ${_formatEventDate(post['event_end_time'])}'),
            if (post['event_location'] != null)
              _buildEventInfoRow('地点', post['event_location']),
            if (post['event_city'] != null)
              _buildEventInfoRow('城市', post['event_city']),
            if (post['event_ticket_url'] != null)
              _buildEventInfoRow('购票', post['event_ticket_url']),
          ],
        ),
      ),
    );
  }

  // // ✅ 新增：活动信息行
  // Widget _buildEventInfoRow(String label, String value) {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(vertical: 4),
  //     child: Row(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         SizedBox(
  //           width: 60,
  //           child: Text('$label：',
  //               style: const TextStyle(fontWeight: FontWeight.w500)),
  //         ),
  //         Expanded(child: Text(value)),
  //       ],
  //     ),
  //   );
  // }
  // ✅ 修改：活动信息行（为购票链接添加点击跳转）
Widget _buildEventInfoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text('$label：',
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: label == '购票'
              ? InkWell(
                  onTap: () {
                    _launchTicketUrl(value);
                  },
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                )
              : Text(value),
        ),
      ],
    ),
  );
}

// ✅ 新增：打开购票链接的方法
Future<void> _launchTicketUrl(String url) async {
  try {
    // 确保URL有协议前缀
    String formattedUrl = url;
    if (!formattedUrl.toLowerCase().startsWith('http://') &&
        !formattedUrl.toLowerCase().startsWith('https://')) {
      formattedUrl = 'https://$formattedUrl';
    }

    final canLaunch = await canLaunchUrl(Uri.parse(formattedUrl));
    if (canLaunch) {
      await launchUrl(
        Uri.parse(formattedUrl),
        mode: LaunchMode.externalApplication,
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开链接: $formattedUrl')),
        );
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开链接失败: $e')),
      );
    }
  }
}

  // ✅ 新增：活动时间格式化
  String _formatEventDate(dynamic date) {
    if (date == null) return '';
    try {
      final dateTime =
          date is String ? DateTime.tryParse(date) : date as DateTime?;
      if (dateTime == null) return date.toString();
      return DateFormat('MM/dd HH:mm').format(dateTime);
    } catch (e) {
      return date.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('加载失败：$_error')),
      );
    }

    final p = _post!;
    final media = (p['post_media'] as List? ?? [])
      ..sort((a, b) => (a['sort_order'] ?? 0).compareTo(b['sort_order'] ?? 0));
    final author = p['author'] ?? {};
    final authorId = author['id'] as String?;
    final collaborators = (p['collaborators'] as List? ?? []);
    final createdAt = p['created_at'];

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(p['title'] ?? '详情'),
        // 修改：如果是作者，在右上角显示更多操作菜单
        actions: _isAuthor ? [_buildMoreActionsMenu()] : null,
      ),
      // ✅ 新增：悬浮发布按钮（只在活动帖子显示）
    floatingActionButton: _showEventFab
        ? Container(
            margin: const EdgeInsets.only(bottom: 70, right: 16), // 避免被底部输入栏遮挡
            child: FloatingActionButton(
              onPressed: _navigateToEventPostCompose,
              backgroundColor: const Color(0xFFED7099), // 粉色主题色
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 20),
                  SizedBox(height: 2),
                  Text(
                    '发布',
                    style: TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          )
        : null,
    
    floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_replyToId != null && (_replyToName?.isNotEmpty ?? false))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Text(
                          '回复 $_replyToName',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _replyToId = null;
                              _replyToName = null;
                            });
                          },
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentCtrl,
                        focusNode: _inputFocus,
                        minLines: 1,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: '友善发言，一起变好～',
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _sendingComment ? null : _sendComment,
                      icon: _sendingComment
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadDetail(); // 刷新帖子主体
          await _refreshComments(); // 刷新评论（顶层 Future）
          await _loadRelatedPosts(); // 刷新时也重新加载相关帖子
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            // 作者信息（可点头像/昵称进个人主页）
            InkWell(
              onTap: (authorId == null)
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => UserProfilePage(userId: authorId),
                        ),
                      );
                    },
              child: Row(
                children: [
                  AvatarWidget(
                    imageUrl: author['avatar_url'] as String?,
                    size: 40,
                    onTap: authorId == null
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    UserProfilePage(userId: authorId),
                              ),
                            );
                          },
                  ),
                  const SizedBox(width: 12),
                  Text(author['nickname'] ?? '佚名',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                          p['channel'] == 'cos'
                              ? 'COS'
                              : p['channel'] == 'event'
                                  ? '活动'
                                  : '群岛',
                          style: const TextStyle(color: Colors.grey)),
                      const SizedBox(width: 8),
                      const Text('·', style: TextStyle(color: Colors.grey)),
                      const SizedBox(width: 8),
                      Text(
                        _timeAgoFrom(createdAt),
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 共创协作者（横向头像，可点击）
            if (collaborators.isNotEmpty) ...[
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: collaborators.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final c = collaborators[i] as Map<String, dynamic>;
                    final u = (c['user'] as Map?) ?? {};
                    final String? uid = u['id'] as String?;
                    final String name = (u['nickname'] as String?) ??
                        (c['display_name'] as String?) ??
                        '合作方';
                    final String role =
                        (c['role'] as String? ?? 'other').toString();

                    return InkWell(
                      onTap: uid == null
                          ? null
                          : () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => UserProfilePage(userId: uid),
                              ));
                            },
                      child: Row(
                        children: [
                          AvatarWidget(
                            imageUrl: u['avatar_url'] as String?,
                            size: 36,
                            onTap: uid == null
                                ? null
                                : () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            UserProfilePage(userId: uid),
                                      ),
                                    );
                                  },
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              Text(_roleLabel(role),
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ✅ 新增：如果是活动帖子，显示活动信息卡片
            if (p['channel'] == 'event') _buildEventInfoCard(p),

            // 媒体轮播（小红书式）
            if (media.isNotEmpty) _buildMediaCarousel(media),
            const SizedBox(height: 12),

            // 正文
            if ((p['content'] ?? '').toString().isNotEmpty)
              _buildContentWithRepostChain(p),
            const SizedBox(height: 16),

            // ✅ 新增：相关帖子（只在活动帖显示）
            _buildRelatedPosts(),

            // 标签（点击进标签聚合页）
            if (p['post_tags'] != null &&
                (p['post_tags'] as List).isNotEmpty) ...[
              Wrap(
                spacing: 8,
                children: (p['post_tags'] as List).map((t) {
                  final name = t['tag']?['name'] ?? '';
                  return ActionChip(
                    label: Text('#$name'),
                    backgroundColor: Colors.grey[100],
                    onPressed: () {
                      if (name.isEmpty) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => TagPostsPage(tagName: name)),
                      );
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],

            FutureBuilder<Map<String, dynamic>?>(
              future: _getOriginalPost(p),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox.shrink();
                }
                if (snapshot.hasData && snapshot.data != null) {
                  return _buildOriginalPostInfo(snapshot.data!);
                }
                return const SizedBox.shrink();
              },
            ),

            // 互动条（点赞/收藏 图标 + 数字；乐观更新）
            Row(
              children: [
                // 点赞
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        color: _isLiked ? Colors.red : null,
                      ),
                      tooltip: '点赞',
                      onPressed: () async {
                        final uid =
                            Supabase.instance.client.auth.currentUser?.id;
                        if (uid == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('请先登录')));
                          return;
                        }
                        final nowLiked =
                            await _postService.toggleLike(widget.postId, uid);
                        final old = (_post?['like_count'] ?? 0) as int;
                        setState(() {
                          _isLiked = nowLiked;
                          _post!['like_count'] =
                              (old + (nowLiked ? 1 : -1)).clamp(0, 1 << 30);
                        });
                      },
                    ),
                    const SizedBox(width: 2),
                    Text('${p['like_count'] ?? 0}'),
                  ],
                ),

                const SizedBox(width: 16),

                // 收藏
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isFav ? Icons.bookmark : Icons.bookmark_border,
                        color: _isFav ? Colors.amber : null,
                      ),
                      tooltip: '收藏',
                      onPressed: () async {
                        final uid =
                            Supabase.instance.client.auth.currentUser?.id;
                        if (uid == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('请先登录')));
                          return;
                        }
                        final nowFav = await _postService.toggleFavorite(
                            widget.postId, uid);
                        final old = (_post?['favorite_count'] ?? 0) as int;
                        setState(() {
                          _isFav = nowFav;
                          _post!['favorite_count'] =
                              (old + (nowFav ? 1 : -1)).clamp(0, 1 << 30);
                        });
                      },
                    ),
                    const SizedBox(width: 2),
                    Text('${p['favorite_count'] ?? 0}'),
                  ],
                ),

                // 转发按钮
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.repeat),
                      tooltip: '转发',
                      onPressed: _handleRepost,
                    ),
                    const SizedBox(width: 2),
                    Text('${p['repost_count'] ?? 0}'),
                  ],
                ),

                const Spacer(),
                const Icon(Icons.visibility_outlined,
                    size: 20, color: Colors.grey),
                const SizedBox(width: 4),
                Text('${p['view_count'] ?? 0}',
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),

            const Divider(height: 24),

            // 评论区（顶层）
            const Text('评论',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _commentsFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text('评论加载失败：${snap.error}'),
                  );
                }
                final comments = snap.data ?? [];
                if (comments.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('还没有评论，快来抢沙发～'),
                  );
                }

                return Column(
                  children: comments.map((root) {
                    final u = root['user'] ?? {};
                    return CommentThread(
                      postId: widget.postId,
                      root: root,
                      meLiked: _myLikedCommentIds.contains(root['id'] as int),
                      onReply: (int parentId, String replyToName) {
                        setState(() {
                          _replyToId = parentId;
                          _replyToName = replyToName;
                        });
                        _inputFocus.requestFocus();
                      },
                      onLikeChanged: (int commentId, bool nowLiked) {
                        _refreshOneCommentLike(commentId, nowLiked);
                      },
                      postService: _postService,
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 80), // 给底部输入条留空
          ],
        ),
      ),
    );
  }

Widget _buildMediaCarousel(List media) {
  final urls = media
      .map<String>((m) => (m['media_url'] as String?) ?? '')
      .where((u) => u.isNotEmpty)
      .toList();
  if (urls.isEmpty) return const SizedBox.shrink();

  // ✅ 加载第一张图比例
  if (!_hasLoadedRatio) {
    _loadFirstImageAspectRatio(urls);
  }
  
  // ✅ 根据第一张图方向决定容器类型
  final screenWidth = MediaQuery.of(context).size.width;
  double containerHeight;
  
  if (_carouselAspectRatio != null) {
    final ratio = _carouselAspectRatio!;
    
    if (ratio > 1) {
      // 🟡 横图：固定 3:2 容器
      containerHeight = screenWidth * (2/3); // 3:2 的高度
    } else {
      // 🟢 竖图：固定 2:3 容器  
      containerHeight = screenWidth * (3/2); // 2:3 的高度
    }
  } else {
    // 🔵 默认：3:2 横图容器
    containerHeight = screenWidth * (1/1);
  }

  // 🔧 确保高度在合理范围内
  final safeHeight = containerHeight.clamp(screenWidth * 0.5, screenWidth * 2);

  return Column(
    children: [
      SizedBox(
        height: safeHeight,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: urls.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (_, i) {
                final url = urls[i];
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PostImagePreview(
                          images: urls,
                          initialIndex: i,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    color: Colors.white, // 白色背景作为空白
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.contain, // ✅ 保持比例，等比例缩放
                      width: double.infinity,
                      height: double.infinity,
                      alignment: Alignment.center,
                      // ❌ 去掉缓存尺寸限制，看看是否解决问题
                      // memCacheWidth: isHorizontalContainer ? 1200 : 800,
                      // memCacheHeight: isHorizontalContainer ? 800 : 1200,
                      placeholder: (_, __) => Container(color: Colors.grey[100]),
                      errorWidget: (_, url, ___) {
                        // Future.delayed(const Duration(milliseconds: 300), () {
                        //   if (mounted) setState(() {});
                        // });
                          Future.delayed(const Duration(milliseconds: 500), () {
                            // 使用 CachedNetworkImage 的内置缓存失效功能
                            if (mounted) {
                              // 只清除当前图片的缓存，不刷新整个组件
                              CachedNetworkImage.evictFromCache(url);
                            }
                          });
                        
                        return Container(
                          color: Colors.grey[100],
                          alignment: Alignment.center,
                          child: Icon(Icons.broken_image_outlined, color: Colors.grey[400]),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            if (urls.length > 1) ...[
              _arrowBtn(
                left: true,
                onTap: () {
                  final prev = (_currentIndex - 1).clamp(0, urls.length - 1);
                  _pageController.animateToPage(prev,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut);
                },
              ),
              _arrowBtn(
                left: false,
                onTap: () {
                  final next = (_currentIndex + 1).clamp(0, urls.length - 1);
                  _pageController.animateToPage(next,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut);
                },
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 8),
      if (urls.length > 1)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(urls.length, (i) {
            final active = i == _currentIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              width: active ? 18 : 6,
              decoration: BoxDecoration(
                color: active ? Colors.black87 : Colors.black26,
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
    ],
  );
}
  Widget _arrowBtn({required bool left, required VoidCallback onTap}) {
    return Positioned(
      top: 0,
      bottom: 0,
      left: left ? 8 : null,
      right: left ? null : 8,
      child: Center(
        child: Material(
          color: Colors.black45,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.chevron_right, color: Colors.white, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

/* ============================
 * 楼中楼组件（B站风格：主楼 + 扁平所有子孙）
 * 头像 & 名字可点击进入个人主页
 * ============================ */
class CommentThread extends StatefulWidget {
  final int postId;
  final Map<String, dynamic> root; // 顶层一楼（含 user）
  final bool meLiked; // 我是否给顶层点过赞
  final void Function(int parentId, String replyToName) onReply;
  final void Function(int commentId, bool nowLiked) onLikeChanged;
  final PostService postService;

  const CommentThread({
    super.key,
    required this.postId,
    required this.root,
    required this.meLiked,
    required this.onReply,
    required this.onLikeChanged,
    required this.postService,
  });

  @override
  State<CommentThread> createState() => _CommentThreadState();
}

class _CommentThreadState extends State<CommentThread> {
  late Map<String, dynamic> _root; // 一楼
  List<Map<String, dynamic>> _replies = []; // 扁平子孙
  Set<int> _myLiked = <int>{}; // 我在整楼里点过赞的评论ID
  bool _loading = true;
  // ✅ 新增：控制展开状态的变量
  int _visibleCount = 1; // 默认显示3条
  static const int _pageSize = 5; // 每次展开显示5条
  
  @override
  void initState() {
    super.initState();
    _root = Map<String, dynamic>.from(widget.root);
    _loadThread();
  }
  // @override
  // void initState() {
  //   super.initState();
  //   _root = Map<String, dynamic>.from(widget.root);
  //   _loadThread(); // 独立拉整楼，不影响其他楼
  // }

  Future<void> _loadThread() async {
    setState(() => _loading = true);
    final thread = await widget.postService.fetchThreadFlat(_root['id'] as int);
    final root = (thread['root'] ?? {}) as Map<String, dynamic>;
    final replies = (thread['replies'] as List).cast<Map<String, dynamic>>();

    final uid = Supabase.instance.client.auth.currentUser?.id;
    Set<int> mine = <int>{};
    if (uid != null) {
      final allIds = <int>[
        if (root['id'] != null) root['id'] as int,
        ...replies.map<int>((e) => e['id'] as int),
      ];
      mine = await widget.postService.myLikedInThread(allIds, uid);
    }

    if (!mounted) return;
    setState(() {
      _root = root.isNotEmpty ? root : _root; // 容错：没取到root就沿用原来
      _replies = replies;
      _myLiked = mine;
      _loading = false;
    });
  }

  String _timeAgo(dynamic createdAt) {
    if (createdAt == null) return '';
    final dt = createdAt is String
        ? DateTime.tryParse(createdAt)
        : (createdAt as DateTime?);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 30) return '${diff.inDays} 天前';
    final m = (diff.inDays / 30).floor();
    return '$m 个月前';
  }

  Future<void> _toggleLike(int commentId) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先登录')));
      return;
    }
    final nowLiked = await widget.postService.toggleCommentLike(commentId, uid);

    setState(() {
      if (nowLiked) {
        _myLiked = {..._myLiked, commentId};
      } else {
        _myLiked = _myLiked.where((id) => id != commentId).toSet();
      }
      // 乐观改 like_count
      if (commentId == _root['id']) {
        final old = (_root['like_count'] ?? 0) as int;
        _root['like_count'] = (old + (nowLiked ? 1 : -1)).clamp(0, 1 << 30);
      } else {
        final i = _replies.indexWhere((e) => e['id'] == commentId);
        if (i >= 0) {
          final old = (_replies[i]['like_count'] ?? 0) as int;
          _replies[i] = {
            ..._replies[i],
            'like_count': (old + (nowLiked ? 1 : -1)).clamp(0, 1 << 30),
          };
        }
      }
    });

    // 通知外层（外层用于更新"顶层我的点赞集合"，不会刷新整区）
    widget.onLikeChanged(commentId, nowLiked);
  }

  // /// 单条评论（主楼/楼内）渲染；头像/昵称可点击进入个人主页
  // Widget _buildOne(Map<String, dynamic> c, {required bool isRoot}) {
  //   // root 数据来源可能是 select 格式（有 user:{}），也可能是 RPC 格式（展开后的 user_* 字段）
  //   final cid = c['id'] as int;
  //   final isRpc =
  //       c.containsKey('user_nickname') || c.containsKey('parent_user_nickname');

  //   final String nickname = isRpc
  //       ? (c['user_nickname'] as String? ?? '用户')
  //       : ((c['user']?['nickname'] as String?) ?? '用户');

  //   final String? avatar = isRpc
  //       ? (c['user_avatar_url'] as String?)
  //       : (c['user']?['avatar_url'] as String?);

  //   final String? userId =
  //       isRpc ? (c['user_id'] as String?) : (c['user']?['id'] as String?);

  //   final String? parentNickname =
  //       isRoot ? null : (isRpc ? (c['parent_user_nickname'] as String?) : null);

  //   final String? parentUserId =
  //       isRoot ? null : (isRpc ? (c['parent_user_id'] as String?) : null);

  //   final timeLabel = _timeAgo(c['created_at']);
  //   final liked = _myLiked.contains(cid);
  //   final likeCount = (c['like_count'] ?? 0) as int;

  //   void goUser(String? uid) {
  //     if (uid == null || uid.isEmpty) return;
  //     Navigator.of(context).push(
  //       MaterialPageRoute(builder: (_) => UserProfilePage(userId: uid)),
  //     );
  //   }

  //   return Padding(
  //     padding: EdgeInsets.only(left: isRoot ? 0 : 46, top: isRoot ? 0 : 8),
  //     child: Row(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         // 头像可点
  //         InkWell(
  //           onTap: () => goUser(userId),
  //           child: AvatarWidget(imageUrl: avatar, size: isRoot ? 36 : 28),
  //         ),
  //         const SizedBox(width: 8),
  //         Expanded(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               // 昵称（可点击） + 时间
  //               Row(
  //                 children: [
  //                   Flexible(
  //                     child: InkWell(
  //                       onTap: () => goUser(userId),
  //                       child: Text(
  //                         nickname,
  //                         style: const TextStyle(
  //                           fontWeight: FontWeight.w600,
  //                           fontSize: 14,
  //                         ),
  //                       ),
  //                     ),
  //                   ),
  //                   const SizedBox(width: 8),
  //                   Text(timeLabel,
  //                       style:
  //                           const TextStyle(color: Colors.grey, fontSize: 12)),
  //                 ],
  //               ),
  //               const SizedBox(height: 4),

  //               // 内容（回复层：A 回复 B：xxx）—— 这里只让"作者昵称"可点击；B 也可点击的话再包一层 InkWell
  //               if (parentNickname == null)
  //                 Text('${c['content'] ?? ''}')
  //               else
  //                 Wrap(
  //                   crossAxisAlignment: WrapCrossAlignment.center,
  //                   children: [
  //                     InkWell(
  //                       onTap: () => goUser(userId),
  //                       child: Text(
  //                         nickname,
  //                         style: const TextStyle(fontWeight: FontWeight.w600),
  //                       ),
  //                     ),
  //                     const Text(' 回复 '),
  //                     if (parentNickname != null)
  //                       (parentUserId != null && parentUserId.isNotEmpty)
  //                           ? InkWell(
  //                               onTap: () => goUser(parentUserId),
  //                               child: Text(
  //                                 parentNickname,
  //                                 style: const TextStyle(
  //                                     fontWeight: FontWeight.w600),
  //                               ),
  //                             )
  //                           : Text(
  //                               parentNickname,
  //                               style: const TextStyle(
  //                                   fontWeight: FontWeight.w600),
  //                             ),
  //                     const Text('：'),
  //                     Text('${c['content'] ?? ''}'),
  //                   ],
  //                 ),

  //               const SizedBox(height: 6),
  //               // 操作区：点赞 / 回复
  //               Row(
  //                 children: [
  //                   InkWell(
  //                     onTap: () => _toggleLike(cid),
  //                     child: Row(
  //                       children: [
  //                         Icon(liked ? Icons.favorite : Icons.favorite_border,
  //                             size: 16,
  //                             color: liked ? Colors.red : Colors.grey),
  //                         const SizedBox(width: 4),
  //                         Text('$likeCount',
  //                             style: const TextStyle(fontSize: 12)),
  //                       ],
  //                     ),
  //                   ),
  //                   const SizedBox(width: 16),
  //                   InkWell(
  //                     onTap: () => widget.onReply(cid, nickname),
  //                     child: const Text('回复',
  //                         style: TextStyle(color: Colors.grey, fontSize: 12)),
  //                   ),
  //                 ],
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }
Widget _buildOne(Map<String, dynamic> c, {required bool isRoot}) {
  final cid = c['id'] as int;
  final isRpc =
      c.containsKey('user_nickname') || c.containsKey('parent_user_nickname');

  final String nickname = isRpc
      ? (c['user_nickname'] as String? ?? '用户')
      : ((c['user']?['nickname'] as String?) ?? '用户');

  final String? avatar = isRpc
      ? (c['user_avatar_url'] as String?)
      : (c['user']?['avatar_url'] as String?);

  final String? userId =
      isRpc ? (c['user_id'] as String?) : (c['user']?['id'] as String?);

  final String? parentNickname =
      isRoot ? null : (isRpc ? (c['parent_user_nickname'] as String?) : null);

  final String? parentUserId =
      isRoot ? null : (isRpc ? (c['parent_user_id'] as String?) : null);

  final timeLabel = _timeAgo(c['created_at']);
  final liked = _myLiked.contains(cid);
  final likeCount = (c['like_count'] ?? 0) as int;
  final content = c['content']?.toString() ?? '';

  void goUser(String? uid) {
    if (uid == null || uid.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserProfilePage(userId: uid)),
    );
  }

  return Padding(
    padding: EdgeInsets.only(left: isRoot ? 0 : 46, top: isRoot ? 0 : 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 头像可点
        InkWell(
          onTap: () => goUser(userId),
          child: AvatarWidget(imageUrl: avatar, size: isRoot ? 36 : 28),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 昵称（可点击） + 时间
              Row(
                children: [
                  Flexible(
                    child: InkWell(
                      onTap: () => goUser(userId),
                      child: Text(
                        nickname,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(timeLabel,
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 4),

              // 内容显示 - 简化版本
              if (parentNickname == null)
                // 主楼或直接回复帖子
                Text(content, style: const TextStyle(fontSize: 14))
              else
                // 子评论回复：只显示 "回复 @用户名：内容"
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    children: [
                      const TextSpan(text: '回复 '),
                      // 被回复的用户名（可点击）
                      WidgetSpan(
                        child: InkWell(
                          onTap: ()  {
                print('点击被回复者 parentUserId: $parentUserId'); // 调试
                print('点击被回复者 parentNickname: $parentNickname'); // 调试
                goUser(parentUserId);
              },
                          child: Text(
                            '@${parentNickname ?? ''}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ),
                      const TextSpan(text: '：'),
                      TextSpan(text: content),
                    ],
                  ),
                ),

              const SizedBox(height: 6),
              // 操作区：点赞 / 回复
              Row(
                children: [
                  InkWell(
                    onTap: () => _toggleLike(cid),
                    child: Row(
                      children: [
                        Icon(liked ? Icons.favorite : Icons.favorite_border,
                            size: 16,
                            color: liked ? Colors.red : Colors.grey),
                        const SizedBox(width: 4),
                        Text('$likeCount',
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  InkWell(
                    onTap: () => widget.onReply(cid, nickname),
                    child: const Text('回复',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
  // @override
  // Widget build(BuildContext context) {
  //   if (_loading) {
  //     return const Padding(
  //       padding: EdgeInsets.symmetric(vertical: 12),
  //       child: Center(child: CircularProgressIndicator()),
  //     );
  //   }
  //   // ✅ 计算要显示的子评论
  //   final visibleReplies = _replies.take(_visibleCount).toList();
  //   final hasMore = _replies.length > _visibleCount;
  //   final hasReplies = _replies.isNotEmpty;
  //   final isExpanded = _visibleCount > 1; // 是否已展开

  //   return Container(
  //     padding: const EdgeInsets.symmetric(vertical: 10),
  //     decoration: const BoxDecoration(
  //       border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         // 一楼
  //         _buildOne(_root, isRoot: true),
  //         const SizedBox(height: 6),
  //         // 扁平所有子孙
  //         ..._replies.map((e) => _buildOne(e, isRoot: false)),
  //         const SizedBox(height: 12),
  //       ],
  //     ),
  //   );
  // }
    @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // ✅ 计算要显示的子评论
    final visibleReplies = _replies.take(_visibleCount).toList();
    final hasMore = _replies.length > _visibleCount;
    final hasReplies = _replies.isNotEmpty;
    final isExpanded = _visibleCount > 1; // 是否已展开

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 一楼
          _buildOne(_root, isRoot: true),
          
          // // 回复总数（可选）
          // if (hasReplies)
          //   Padding(
          //     padding: const EdgeInsets.only(left: 46, top: 4),
          //     child: Text(
          //       '共 ${_replies.length} 条回复',
          //       style: TextStyle(
          //         fontSize: 12,
          //         color: Colors.grey[600],
          //       ),
          //     ),
          //   ),
          
          // const SizedBox(height: 6),

          // 子评论列表
          if (hasReplies) ...[
            ...visibleReplies.map((e) => _buildOne(e, isRoot: false)),
          ],

          // ✅ 展开/收起按钮区域
          if (hasReplies) ...[
            const SizedBox(height: 8),
            
            // 第一行：展开更多 和 收起（左右对齐）
            Padding(
              padding: const EdgeInsets.only(left: 46),
              child: Row(
                children: [
                  // 左侧：展开更多按钮
                  if (hasMore)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          // 增加显示数量，但不能超过总数
                          _visibleCount = (_visibleCount + _pageSize)
                              .clamp(0, _replies.length);
                        });
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 18,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '展开更多评论（${_replies.length - _visibleCount}条）',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  //const Spacer(),
                  
                  // 右侧：收起按钮（只在已展开时显示）
                  if (isExpanded)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _visibleCount = 1; // 收起回3条
                        });
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.keyboard_arrow_up,
                            size: 18,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '收起',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
