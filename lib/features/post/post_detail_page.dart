
// import 'package:flutter/material.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:iacg/widgets/avatar_widget.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

// import '../../services/post_service.dart';
// import '../profile/user_profile_page.dart';
// import '../tag/tag_posts_page.dart';
// import 'post_image_preview.dart';

// class PostDetailPage extends StatefulWidget {
//   final int postId;
//   const PostDetailPage({super.key, required this.postId});

//   @override
//   State<PostDetailPage> createState() => _PostDetailPageState();
// }

// class _PostDetailPageState extends State<PostDetailPage> {
//   final _postService = PostService();
//   Map<String, dynamic>? _post;
//   bool _loading = true;
//   String? _error;

//   bool _isLiked = false;
//   bool _isFav = false;

//   // 轮播
//   final PageController _pageController = PageController();
//   int _currentIndex = 0;

//   // 评论输入
//   final TextEditingController _commentCtrl = TextEditingController();
//   final FocusNode _inputFocus = FocusNode();
//   bool _sendingComment = false;

//   // 顶层评论 Future（缓存，避免频繁刷新）
//   late Future<List<Map<String, dynamic>>> _commentsFuture;
//   Set<int> _myLikedCommentIds = <int>{}; // 我点赞过的【顶层】评论ID集合（用于首屏红心）
//   int? _replyToId;                        // 正在回复的评论ID
//   String? _replyToName;                   // 被回复者昵称（提示）

//   @override
//   void initState() {
//     super.initState();
//     _loadDetail();
//     _refreshComments(); // 初始化顶层评论
//   }

//   @override
//   void dispose() {
//     _pageController.dispose();
//     _commentCtrl.dispose();
//     _inputFocus.dispose();
//     super.dispose();
//   }

//   Future<String?> _currentUserId() async {
//     return Supabase.instance.client.auth.currentUser?.id;
//   }

//   Future<void> _loadDetail() async {
//     setState(() {
//       _loading = true;
//       _error = null;
//     });
//     try {
//       final data = await _postService.getPostDetail(widget.postId);
//       if (!mounted) return;
//       setState(() {
//         _post = data;
//         _currentIndex = 0;
//       });

//       // 查询已点赞/收藏状态（仅登录用户）
//       final uid = Supabase.instance.client.auth.currentUser?.id;
//       if (uid != null) {
//         final liked = await _postService.hasLiked(widget.postId, uid);
//         final faved = await _postService.hasFavorited(widget.postId, uid);
//         if (!mounted) return;
//         setState(() {
//           _isLiked = liked;
//           _isFav = faved;
//         });
//       }

//       // 仅登录用户计浏览量
//       await _postService.incrementViewCountIfAuthed(widget.postId);
//     } catch (e) {
//       if (!mounted) return;
//       setState(() => _error = e.toString());
//     } finally {
//       if (mounted) setState(() => _loading = false);
//     }
//   }

//   /// 刷新“顶层评论列表”与“我点赞过的顶层评论集合”
//   Future<void> _refreshComments() async {
//     final top = await _postService.listTopComments(widget.postId, limit: 100);
//     final uid = Supabase.instance.client.auth.currentUser?.id;
//     if (uid != null) {
//       final ids = top.map<int>((c) => c['id'] as int).toList();
//       _myLikedCommentIds = await _postService.myLikedCommentIds(ids, uid);
//     } else {
//       _myLikedCommentIds = <int>{};
//     }
//     _commentsFuture = Future.value(top);
//     if (mounted) setState(() {});
//   }

//   /// 单条评论点赞后，本地同步“我点赞过的顶层集合”
//   Future<void> _refreshOneCommentLike(int commentId, bool nowLiked) async {
//     setState(() {
//       if (nowLiked) {
//         _myLikedCommentIds = {..._myLikedCommentIds, commentId};
//       } else {
//         _myLikedCommentIds =
//             _myLikedCommentIds.where((id) => id != commentId).toSet();
//       }
//     });
//   }

//   // 点赞（帖子层面的）
//   Future<void> _handleLike() async {
//     final uid = await _currentUserId();
//     if (uid == null) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('请先登录再点赞')),
//         );
//       }
//       return;
//     }
//     try {
//       await _postService.likePost(widget.postId, uid);
//       await _loadDetail();
//     } catch (_) {
//       await _postService.unlikePost(widget.postId, uid);
//       await _loadDetail();
//     }
//   }

//   // 收藏（帖子层面的）
//   Future<void> _handleFavorite() async {
//     final uid = await _currentUserId();
//     if (uid == null) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('请先登录再收藏')),
//         );
//       }
//       return;
//     }
//     try {
//       await _postService.favoritePost(widget.postId, uid);
//       await _loadDetail();
//     } catch (_) {
//       await _postService.unfavoritePost(widget.postId, uid);
//       await _loadDetail();
//     }
//   }

//   // 发送评论/回复（仅刷新评论区，不重拉整页）
//   Future<void> _sendComment() async {
//     final text = _commentCtrl.text.trim();
//     if (text.isEmpty || _sendingComment) return;

//     final uid = Supabase.instance.client.auth.currentUser?.id;
//     if (uid == null) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('请先登录再评论')),
//         );
//       }
//       return;
//     }

//     setState(() => _sendingComment = true);
//     try {
//       await _postService.addComment(
//         postId: widget.postId,
//         userId: uid,
//         text: text,
//         parentId: _replyToId, // 有 parentId 则为回复
//       );
//       _commentCtrl.clear();
//       _replyToId = null;
//       _replyToName = null;
//       FocusScope.of(context).unfocus();
//       await _refreshComments(); // 只刷新顶层列表（各楼内由子组件自管）
//       if (mounted && _post != null) {
//         setState(() {
//           _post!['comment_count'] = (_post!['comment_count'] ?? 0) + 1;
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('评论失败：$e')),
//         );
//       }
//     } finally {
//       if (mounted) setState(() => _sendingComment = false);
//     }
//   }

//   // 相对时间
//   String _timeAgoFrom(dynamic createdAt) {
//     if (createdAt == null) return '';
//     final dt = createdAt is String
//         ? DateTime.tryParse(createdAt)
//         : (createdAt as DateTime?);
//     if (dt == null) return '';
//     final diff = DateTime.now().difference(dt);
//     if (diff.inMinutes < 1) return '刚刚';
//     if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
//     if (diff.inHours < 24) return '${diff.inHours} 小时前';
//     if (diff.inDays < 30) return '${diff.inDays} 天前';
//     final m = (diff.inDays / 30).floor();
//     return '$m 个月前';
//   }

//   String _roleLabel(String role) {
//     switch (role) {
//       case 'photographer':
//         return '摄影';
//       case 'makeup':
//         return '妆造';
//       case 'costume':
//         return '服装/造型';
//       case 'props':
//         return '道具';
//       case 'retouch':
//         return '修图';
//       default:
//         return '合作';
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_loading) {
//       return const Scaffold(body: Center(child: CircularProgressIndicator()));
//     }
//     if (_error != null) {
//       return Scaffold(
//         appBar: AppBar(),
//         body: Center(child: Text('加载失败：$_error')),
//       );
//     }

//     final p = _post!;
//     final media = (p['post_media'] as List? ?? [])
//       ..sort((a, b) => (a['sort_order'] ?? 0).compareTo(b['sort_order'] ?? 0));
//     final author = p['author'] ?? {};
//     final authorId = author['id'] as String?;
//     final collaborators = (p['collaborators'] as List? ?? []);
//     final createdAt = p['created_at'];

//     return Scaffold(
//       appBar: AppBar(title: Text(p['title'] ?? '详情')),
//       bottomNavigationBar: SafeArea(
//         child: Container(
//           padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             border: Border(top: BorderSide(color: Colors.grey[200]!)),
//           ),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               if (_replyToId != null && (_replyToName?.isNotEmpty ?? false))
//                 Padding(
//                   padding: const EdgeInsets.only(bottom: 6),
//                   child: Row(
//                     children: [
//                       Text('回复 $_replyToName',
//                           style:
//                               const TextStyle(fontSize: 12, color: Colors.grey)),
//                       const SizedBox(width: 8),
//                       GestureDetector(
//                         onTap: () {
//                           setState(() {
//                             _replyToId = null;
//                             _replyToName = null;
//                           });
//                         },
//                         child: const Icon(Icons.close,
//                             size: 16, color: Colors.grey),
//                       ),
//                     ],
//                   ),
//                 ),
//               Row(
//                 children: [
//                   Expanded(
//                     child: TextField(
//                       controller: _commentCtrl,
//                       focusNode: _inputFocus,
//                       minLines: 1,
//                       maxLines: 3,
//                       decoration: InputDecoration(
//                         hintText: '友善发言，一起变好～',
//                         filled: true,
//                         fillColor: Colors.grey[100],
//                         contentPadding: const EdgeInsets.symmetric(
//                             horizontal: 12, vertical: 10),
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(24),
//                           borderSide: BorderSide.none,
//                         ),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   IconButton(
//                     onPressed: _sendingComment ? null : _sendComment,
//                     icon: _sendingComment
//                         ? const SizedBox(
//                             width: 18,
//                             height: 18,
//                             child: CircularProgressIndicator(strokeWidth: 2),
//                           )
//                         : const Icon(Icons.send_rounded),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//       body: RefreshIndicator(
//         onRefresh: () async {
//           await _loadDetail();      // 刷新帖子主体
//           await _refreshComments(); // 刷新评论（顶层 Future）
//         },
//         child: ListView(
//           padding: const EdgeInsets.all(16),
//           children: [
//             // 作者信息（可点头像/昵称进个人主页）
//             InkWell(
//               onTap: (authorId == null)
//                   ? null
//                   : () {
//                       Navigator.of(context).push(
//                         MaterialPageRoute(
//                           builder: (_) => UserProfilePage(userId: authorId),
//                         ),
//                       );
//                     },
//               child: Row(
//                 children: [
//                   AvatarWidget(
//                     imageUrl: author['avatar_url'] as String?,
//                     size: 40,
//                     onTap: authorId == null
//                         ? null
//                         : () {
//                             Navigator.of(context).push(
//                               MaterialPageRoute(
//                                 builder: (_) =>
//                                     UserProfilePage(userId: authorId),
//                               ),
//                             );
//                           },
//                   ),
//                   const SizedBox(width: 12),
//                   Text(author['nickname'] ?? '佚名',
//                       style: const TextStyle(fontWeight: FontWeight.w600)),
//                   const Spacer(),
//                   Row(
//                     children: [
//                       Text(p['channel'] == 'cos' ? 'COS' : '群岛',
//                           style: const TextStyle(color: Colors.grey)),
//                       const SizedBox(width: 8),
//                       const Text('·', style: TextStyle(color: Colors.grey)),
//                       const SizedBox(width: 8),
//                       Text(
//                         _timeAgoFrom(createdAt),
//                         style:
//                             const TextStyle(color: Colors.grey, fontSize: 12),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 12),

//             // 共创协作者（横向头像，可点击）
//             if (collaborators.isNotEmpty) ...[
//               SizedBox(
//                 height: 52,
//                 child: ListView.separated(
//                   scrollDirection: Axis.horizontal,
//                   itemCount: collaborators.length,
//                   separatorBuilder: (_, __) => const SizedBox(width: 12),
//                   itemBuilder: (_, i) {
//                     final c = collaborators[i] as Map<String, dynamic>;
//                     final u = (c['user'] as Map?) ?? {};
//                     final String? uid = u['id'] as String?;
//                     final String name = (u['nickname'] as String?) ??
//                         (c['display_name'] as String?) ??
//                         '合作方';
//                     final String role =
//                         (c['role'] as String? ?? 'other').toString();

//                     return InkWell(
//                       onTap: uid == null
//                           ? null
//                           : () {
//                               Navigator.of(context).push(MaterialPageRoute(
//                                 builder: (_) => UserProfilePage(userId: uid),
//                               ));
//                             },
//                       child: Row(
//                         children: [
//                           AvatarWidget(
//                             imageUrl: u['avatar_url'] as String?,
//                             size: 36,
//                             onTap: uid == null
//                                 ? null
//                                 : () {
//                                     Navigator.of(context).push(
//                                       MaterialPageRoute(
//                                         builder: (_) =>
//                                             UserProfilePage(userId: uid),
//                                       ),
//                                     );
//                                   },
//                           ),
//                           const SizedBox(width: 8),
//                           Column(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(name,
//                                   style: const TextStyle(
//                                       fontSize: 13,
//                                       fontWeight: FontWeight.w600)),
//                               Text(_roleLabel(role),
//                                   style: const TextStyle(
//                                       fontSize: 11, color: Colors.grey)),
//                             ],
//                           ),
//                         ],
//                       ),
//                     );
//                   },
//                 ),
//               ),
//               const SizedBox(height: 12),
//             ],

//             // 媒体轮播（小红书式）
//             if (media.isNotEmpty) _buildMediaCarousel(media),
//             const SizedBox(height: 12),

//             // 正文
//             if ((p['content'] ?? '').toString().isNotEmpty)
//               Text(p['content'],
//                   style: const TextStyle(fontSize: 16, height: 1.5)),
//             const SizedBox(height: 16),

//             // 标签（点击进标签聚合页）
//             if (p['post_tags'] != null && (p['post_tags'] as List).isNotEmpty)
//               ...[
//                 Wrap(
//                   spacing: 8,
//                   children: (p['post_tags'] as List).map((t) {
//                     final name = t['tag']?['name'] ?? '';
//                     return ActionChip(
//                       label: Text('#$name'),
//                       onPressed: () {
//                         if (name.isEmpty) return;
//                         Navigator.of(context).push(
//                           MaterialPageRoute(
//                               builder: (_) => TagPostsPage(tagName: name)),
//                         );
//                       },
//                     );
//                   }).toList(),
//                 ),
//                 const SizedBox(height: 8),
//               ],

//             // 互动条（点赞/收藏 图标 + 数字；乐观更新）
//             Row(
//               children: [
//                 // 点赞
//                 Row(
//                   children: [
//                     IconButton(
//                       icon: Icon(
//                         _isLiked ? Icons.favorite : Icons.favorite_border,
//                         color: _isLiked ? Colors.red : null,
//                       ),
//                       tooltip: '点赞',
//                       onPressed: () async {
//                         final uid = Supabase.instance.client.auth.currentUser?.id;
//                         if (uid == null) {
//                           ScaffoldMessenger.of(context).showSnackBar(
//                               const SnackBar(content: Text('请先登录')));
//                           return;
//                         }
//                         final nowLiked =
//                             await _postService.toggleLike(widget.postId, uid);
//                         final old = (_post?['like_count'] ?? 0) as int;
//                         setState(() {
//                           _isLiked = nowLiked;
//                           _post!['like_count'] =
//                               (old + (nowLiked ? 1 : -1)).clamp(0, 1 << 30);
//                         });
//                       },
//                     ),
//                     const SizedBox(width: 2),
//                     Text('${p['like_count'] ?? 0}'),
//                   ],
//                 ),

//                 const SizedBox(width: 16),

//                 // 收藏
//                 Row(
//                   children: [
//                     IconButton(
//                       icon: Icon(
//                         _isFav ? Icons.bookmark : Icons.bookmark_border,
//                         color: _isFav ? Colors.amber : null,
//                       ),
//                       tooltip: '收藏',
//                       onPressed: () async {
//                         final uid = Supabase.instance.client.auth.currentUser?.id;
//                         if (uid == null) {
//                           ScaffoldMessenger.of(context).showSnackBar(
//                               const SnackBar(content: Text('请先登录')));
//                           return;
//                         }
//                         final nowFav = await _postService.toggleFavorite(
//                             widget.postId, uid);
//                         final old = (_post?['favorite_count'] ?? 0) as int;
//                         setState(() {
//                           _isFav = nowFav;
//                           _post!['favorite_count'] =
//                               (old + (nowFav ? 1 : -1)).clamp(0, 1 << 30);
//                         });
//                       },
//                     ),
//                     const SizedBox(width: 2),
//                     Text('${p['favorite_count'] ?? 0}'),
//                   ],
//                 ),

//                 const Spacer(),
//                 const Icon(Icons.visibility_outlined,
//                     size: 20, color: Colors.grey),
//                 const SizedBox(width: 4),
//                 Text('${p['view_count'] ?? 0}',
//                     style: const TextStyle(color: Colors.grey)),
//               ],
//             ),

//             const Divider(height: 24),

//             // 评论区（顶层）
//             const Text('评论',
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
//             const SizedBox(height: 8),
//             FutureBuilder<List<Map<String, dynamic>>>(
//               future: _commentsFuture,
//               builder: (context, snap) {
//                 if (snap.connectionState == ConnectionState.waiting) {
//                   return const Padding(
//                     padding: EdgeInsets.symmetric(vertical: 24),
//                     child: Center(child: CircularProgressIndicator()),
//                   );
//                 }
//                 if (snap.hasError) {
//                   return Padding(
//                     padding: const EdgeInsets.symmetric(vertical: 24),
//                     child: Text('评论加载失败：${snap.error}'),
//                   );
//                 }
//                 final comments = snap.data ?? [];
//                 if (comments.isEmpty) {
//                   return const Padding(
//                     padding: EdgeInsets.symmetric(vertical: 24),
//                     child: Text('还没有评论，快来抢沙发～'),
//                   );
//                 }

//                 return Column(
//                   children: comments.map((root) {
//                     final u = root['user'] ?? {};
//                     return CommentThread(
//                       postId: widget.postId,
//                       root: root,
//                       meLiked: _myLikedCommentIds.contains(root['id'] as int),
//                       onReply: (int parentId, String replyToName) {
//                         setState(() {
//                           _replyToId = parentId;
//                           _replyToName = replyToName;
//                         });
//                         _inputFocus.requestFocus();
//                       },
//                       onLikeChanged: (int commentId, bool nowLiked) {
//                         _refreshOneCommentLike(commentId, nowLiked);
//                       },
//                       postService: _postService,
//                     );
//                   }).toList(),
//                 );
//               },
//             ),

//             const SizedBox(height: 80), // 给底部输入条留空
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildMediaCarousel(List media) {
//     final urls = media
//         .map<String>((m) => (m['media_url'] as String?) ?? '')
//         .where((u) => u.isNotEmpty)
//         .toList();
//     if (urls.isEmpty) return const SizedBox.shrink();

//     return Column(
//       children: [
//         AspectRatio(
//           aspectRatio: 3 / 4,
//           child: Stack(
//             children: [
//               PageView.builder(
//                 controller: _pageController,
//                 itemCount: urls.length,
//                 onPageChanged: (i) => setState(() => _currentIndex = i),
//                 itemBuilder: (_, i) {
//                   final url = urls[i];
//                   return GestureDetector(
//                     onTap: () {
//                       Navigator.of(context).push(
//                         MaterialPageRoute(
//                           builder: (_) => PostImagePreview(
//                             images: urls,
//                             initialIndex: i,
//                           ),
//                         ),
//                       );
//                     },
//                     child: CachedNetworkImage(
//                       imageUrl: url,
//                       fit: BoxFit.cover,
//                       placeholder: (_, __) =>
//                           Container(color: Colors.grey[100]),
//                       errorWidget: (_, __, ___) => Container(
//                         color: Colors.grey[100],
//                         alignment: Alignment.center,
//                         child: Icon(Icons.broken_image_outlined,
//                             color: Colors.grey[400]),
//                       ),
//                     ),
//                   );
//                 },
//               ),
//               if (urls.length > 1) ...[
//                 _arrowBtn(
//                   left: true,
//                   onTap: () {
//                     final prev =
//                         (_currentIndex - 1).clamp(0, urls.length - 1);
//                     _pageController.animateToPage(prev,
//                         duration: const Duration(milliseconds: 250),
//                         curve: Curves.easeOut);
//                   },
//                 ),
//                 _arrowBtn(
//                   left: false,
//                   onTap: () {
//                     final next =
//                         (_currentIndex + 1).clamp(0, urls.length - 1);
//                     _pageController.animateToPage(next,
//                         duration: const Duration(milliseconds: 250),
//                         curve: Curves.easeOut);
//                   },
//                 ),
//               ],
//             ],
//           ),
//         ),
//         const SizedBox(height: 8),
//         if (urls.length > 1)
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: List.generate(urls.length, (i) {
//               final active = i == _currentIndex;
//               return AnimatedContainer(
//                 duration: const Duration(milliseconds: 180),
//                 margin: const EdgeInsets.symmetric(horizontal: 4),
//                 height: 6,
//                 width: active ? 18 : 6,
//                 decoration: BoxDecoration(
//                   color: active ? Colors.black87 : Colors.black26,
//                   borderRadius: BorderRadius.circular(999),
//                 ),
//               );
//             }),
//           ),
//       ],
//     );
//   }

//   Widget _arrowBtn({required bool left, required VoidCallback onTap}) {
//     return Positioned(
//       top: 0,
//       bottom: 0,
//       left: left ? 8 : null,
//       right: left ? null : 8,
//       child: Center(
//         child: Material(
//           color: Colors.black45,
//           shape: const CircleBorder(),
//           child: InkWell(
//             customBorder: const CircleBorder(),
//             onTap: onTap,
//             child: const Padding(
//               padding: EdgeInsets.all(6),
//               child: Icon(Icons.chevron_right, color: Colors.white, size: 22),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// /* ============================
//  * 楼中楼组件（B站风格：主楼 + 扁平所有子孙）
//  * 依赖：PostService.fetchThreadFlat / myLikedInThread / toggleCommentLike
//  * 后端：RPC get_comment_thread(p_root_id)
//  * ============================ */
// class CommentThread extends StatefulWidget {
//   final int postId;
//   final Map<String, dynamic> root; // 顶层一楼（含 user）
//   final bool meLiked;              // 我是否给顶层点过赞
//   final void Function(int parentId, String replyToName) onReply;
//   final void Function(int commentId, bool nowLiked) onLikeChanged;
//   final PostService postService;

//   const CommentThread({
//     super.key,
//     required this.postId,
//     required this.root,
//     required this.meLiked,
//     required this.onReply,
//     required this.onLikeChanged,
//     required this.postService,
//   });

//   @override
//   State<CommentThread> createState() => _CommentThreadState();
// }

// class _CommentThreadState extends State<CommentThread> {
//   late Map<String, dynamic> _root;               // 一楼
//   List<Map<String, dynamic>> _replies = [];      // 扁平子孙
//   Set<int> _myLiked = <int>{};                   // 我在整楼里点过赞的评论ID
//   bool _loading = true;

//   @override
//   void initState() {
//     super.initState();
//     _root = Map<String, dynamic>.from(widget.root);
//     _loadThread(); // 独立拉整楼，不影响其他楼
//   }

//   Future<void> _loadThread() async {
//     setState(() => _loading = true);
//     final thread = await widget.postService.fetchThreadFlat(_root['id'] as int);
//     final root = (thread['root'] ?? {}) as Map<String, dynamic>;
//     final replies = (thread['replies'] as List).cast<Map<String, dynamic>>();

//     final uid = Supabase.instance.client.auth.currentUser?.id;
//     Set<int> mine = <int>{};
//     if (uid != null) {
//       final allIds = <int>[
//         if (root['id'] != null) root['id'] as int,
//         ...replies.map<int>((e) => e['id'] as int),
//       ];
//       mine = await widget.postService.myLikedInThread(allIds, uid);
//     }

//     if (!mounted) return;
//     setState(() {
//       _root = root.isNotEmpty ? root : _root; // 容错：没取到root就沿用原来
//       _replies = replies;
//       _myLiked = mine;
//       _loading = false;
//     });
//   }

//   String _timeAgo(dynamic createdAt) {
//     if (createdAt == null) return '';
//     final dt = createdAt is String
//         ? DateTime.tryParse(createdAt)
//         : (createdAt as DateTime?);
//     if (dt == null) return '';
//     final diff = DateTime.now().difference(dt);
//     if (diff.inMinutes < 1) return '刚刚';
//     if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
//     if (diff.inHours < 24) return '${diff.inHours} 小时前';
//     if (diff.inDays < 30) return '${diff.inDays} 天前';
//     final m = (diff.inDays / 30).floor();
//     return '$m 个月前';
//   }

//   Future<void> _toggleLike(int commentId) async {
//     final uid = Supabase.instance.client.auth.currentUser?.id;
//     if (uid == null) {
//       ScaffoldMessenger.of(context)
//           .showSnackBar(const SnackBar(content: Text('请先登录')));
//       return;
//     }
//     final nowLiked =
//         await widget.postService.toggleCommentLike(commentId, uid);

//     setState(() {
//       if (nowLiked) {
//         _myLiked = {..._myLiked, commentId};
//       } else {
//         _myLiked = _myLiked.where((id) => id != commentId).toSet();
//       }
//       // 乐观改 like_count
//       if (commentId == _root['id']) {
//         final old = (_root['like_count'] ?? 0) as int;
//         _root['like_count'] = (old + (nowLiked ? 1 : -1)).clamp(0, 1 << 30);
//       } else {
//         final i = _replies.indexWhere((e) => e['id'] == commentId);
//         if (i >= 0) {
//           final old = (_replies[i]['like_count'] ?? 0) as int;
//           _replies[i] = {
//             ..._replies[i],
//             'like_count': (old + (nowLiked ? 1 : -1)).clamp(0, 1 << 30),
//           };
//         }
//       }
//     });

//     // 通知外层（外层用于更新“顶层我的点赞集合”，不会刷新整区）
//     widget.onLikeChanged(commentId, nowLiked);
//   }

//   Widget _buildOne(Map<String, dynamic> c, {required bool isRoot}) {
//     // root 数据来源可能是 select 格式（有 user:{}），也可能是 RPC 格式（展开后的 user_* 字段）
//     final cid = c['id'] as int;
//     final isRpc = c.containsKey('user_nickname') || c.containsKey('parent_user_nickname');

//     final String nickname = isRpc
//         ? (c['user_nickname'] as String? ?? '用户')
//         : ((c['user']?['nickname'] as String?) ?? '用户');

//     final String? avatar = isRpc
//         ? (c['user_avatar_url'] as String?)
//         : (c['user']?['avatar_url'] as String?);

//     final String? parentNickname = isRoot
//         ? null
//         : (isRpc
//             ? (c['parent_user_nickname'] as String?)
//             : null /* select 模式没有 parent 的昵称 */);

//     final timeLabel = _timeAgo(c['created_at']);
//     final liked = _myLiked.contains(cid);
//     final likeCount = (c['like_count'] ?? 0) as int;

//     return Padding(
//       padding: EdgeInsets.only(left: isRoot ? 0 : 46, top: isRoot ? 0 : 8),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           AvatarWidget(imageUrl: avatar, size: isRoot ? 36 : 28),
//           const SizedBox(width: 8),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // 昵称 + 时间
//                 Row(
//                   children: [
//                     Flexible(
//                       child: Text(nickname,
//                           style: const TextStyle(
//                               fontWeight: FontWeight.w600, fontSize: 14)),
//                     ),
//                     const SizedBox(width: 8),
//                     Text(timeLabel,
//                         style:
//                             const TextStyle(color: Colors.grey, fontSize: 12)),
//                   ],
//                 ),
//                 const SizedBox(height: 4),
//                 // 内容（回复层：A 回复 B：xxx）
//                 if (parentNickname == null)
//                   Text('${c['content'] ?? ''}')
//                 else
//                   RichText(
//                     text: TextSpan(
//                       style: DefaultTextStyle.of(context).style,
//                       children: [
//                         TextSpan(
//                             text: '$nickname ',
//                             style:
//                                 const TextStyle(fontWeight: FontWeight.w600)),
//                         const TextSpan(text: '回复 '),
//                         TextSpan(
//                             text: '$parentNickname：',
//                             style:
//                                 const TextStyle(fontWeight: FontWeight.w600)),
//                         TextSpan(text: '${c['content'] ?? ''}'),
//                       ],
//                     ),
//                   ),
//                 const SizedBox(height: 6),
//                 // 操作区：点赞 / 回复
//                 Row(
//                   children: [
//                     InkWell(
//                       onTap: () => _toggleLike(cid),
//                       child: Row(
//                         children: [
//                           Icon(liked ? Icons.favorite : Icons.favorite_border,
//                               size: 16, color: liked ? Colors.red : Colors.grey),
//                           const SizedBox(width: 4),
//                           Text('$likeCount', style: const TextStyle(fontSize: 12)),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(width: 16),
//                     InkWell(
//                       onTap: () => widget.onReply(cid, nickname),
//                       child: const Text('回复',
//                           style: TextStyle(color: Colors.grey, fontSize: 12)),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_loading) {
//       return const Padding(
//         padding: EdgeInsets.symmetric(vertical: 12),
//         child: Center(child: CircularProgressIndicator()),
//       );
//     }

//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 10),
//       decoration: const BoxDecoration(
//         border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // 一楼
//           _buildOne(_root, isRoot: true),
//           const SizedBox(height: 6),
//           // 扁平所有子孙
//           ..._replies.map((e) => _buildOne(e, isRoot: false)),
//           const SizedBox(height: 12),
//         ],
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iacg/widgets/avatar_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/post_service.dart';
import '../profile/user_profile_page.dart';
import '../tag/tag_posts_page.dart';
import 'post_image_preview.dart';

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

  // 轮播
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  // 评论输入
  final TextEditingController _commentCtrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  bool _sendingComment = false;

  // 顶层评论 Future（缓存，避免频繁刷新）
  late Future<List<Map<String, dynamic>>> _commentsFuture;
  Set<int> _myLikedCommentIds = <int>{}; // 我点赞过的【顶层】评论ID集合（用于首屏红心）
  int? _replyToId;                        // 正在回复的评论ID
  String? _replyToName;                   // 被回复者昵称（提示）

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _refreshComments(); // 初始化顶层评论
  }

  @override
  void dispose() {
    _pageController.dispose();
    _commentCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
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

      // 仅登录用户计浏览量
      await _postService.incrementViewCountIfAuthed(widget.postId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 刷新“顶层评论列表”与“我点赞过的顶层评论集合”
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

  /// 单条评论点赞后，本地同步“我点赞过的顶层集合”
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
      appBar: AppBar(title: Text(p['title'] ?? '详情')),
      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        // ② 关键：根据键盘高度往上“垫”一块空白
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
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
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
          await _loadDetail();      // 刷新帖子主体
          await _refreshComments(); // 刷新评论（顶层 Future）
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
                      Text(p['channel'] == 'cos' ? 'COS' : '群岛',
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

            // 媒体轮播（小红书式）
            if (media.isNotEmpty) _buildMediaCarousel(media),
            const SizedBox(height: 12),

            // 正文
            if ((p['content'] ?? '').toString().isNotEmpty)
              Text(p['content'],
                  style: const TextStyle(fontSize: 16, height: 1.5)),
            const SizedBox(height: 16),

            // 标签（点击进标签聚合页）
            if (p['post_tags'] != null && (p['post_tags'] as List).isNotEmpty)
              ...[
                Wrap(
                  spacing: 8,
                  children: (p['post_tags'] as List).map((t) {
                    final name = t['tag']?['name'] ?? '';
                    return ActionChip(
                      label: Text('#$name'),
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
                        final uid = Supabase.instance.client.auth.currentUser?.id;
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
                        final uid = Supabase.instance.client.auth.currentUser?.id;
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

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
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
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: Colors.grey[100]),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey[100],
                        alignment: Alignment.center,
                        child: Icon(Icons.broken_image_outlined,
                            color: Colors.grey[400]),
                      ),
                    ),
                  );
                },
              ),
              if (urls.length > 1) ...[
                _arrowBtn(
                  left: true,
                  onTap: () {
                    final prev =
                        (_currentIndex - 1).clamp(0, urls.length - 1);
                    _pageController.animateToPage(prev,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut);
                  },
                ),
                _arrowBtn(
                  left: false,
                  onTap: () {
                    final next =
                        (_currentIndex + 1).clamp(0, urls.length - 1);
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
  final bool meLiked;              // 我是否给顶层点过赞
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
  late Map<String, dynamic> _root;               // 一楼
  List<Map<String, dynamic>> _replies = [];      // 扁平子孙
  Set<int> _myLiked = <int>{};                   // 我在整楼里点过赞的评论ID
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _root = Map<String, dynamic>.from(widget.root);
    _loadThread(); // 独立拉整楼，不影响其他楼
  }

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
    final nowLiked =
        await widget.postService.toggleCommentLike(commentId, uid);

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

    // 通知外层（外层用于更新“顶层我的点赞集合”，不会刷新整区）
    widget.onLikeChanged(commentId, nowLiked);
  }

  /// 单条评论（主楼/楼内）渲染；头像/昵称可点击进入个人主页
  Widget _buildOne(Map<String, dynamic> c, {required bool isRoot}) {
    // root 数据来源可能是 select 格式（有 user:{}），也可能是 RPC 格式（展开后的 user_* 字段）
    final cid = c['id'] as int;
    final isRpc = c.containsKey('user_nickname') || c.containsKey('parent_user_nickname');

    final String nickname = isRpc
        ? (c['user_nickname'] as String? ?? '用户')
        : ((c['user']?['nickname'] as String?) ?? '用户');

    final String? avatar = isRpc
        ? (c['user_avatar_url'] as String?)
        : (c['user']?['avatar_url'] as String?);

    final String? userId = isRpc
        ? (c['user_id'] as String?)
        : (c['user']?['id'] as String?);

    final String? parentNickname = isRoot
        ? null
        : (isRpc ? (c['parent_user_nickname'] as String?) : null);

    final String? parentUserId = isRoot
        ? null
        : (isRpc ? (c['parent_user_id'] as String?) : null);

    final timeLabel = _timeAgo(c['created_at']);
    final liked = _myLiked.contains(cid);
    final likeCount = (c['like_count'] ?? 0) as int;

    void _goUser(String? uid) {
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
            onTap: () => _goUser(userId),
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
                        onTap: () => _goUser(userId),
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
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),

                // 内容（回复层：A 回复 B：xxx）—— 这里只让“作者昵称”可点击；B 也可点击的话再包一层 InkWell
                if (parentNickname == null)
                  Text('${c['content'] ?? ''}')
                else
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      InkWell(
                        onTap: () => _goUser(userId),
                        child: Text(
                          nickname,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Text(' 回复 '),
                      if (parentNickname != null)
                        (parentUserId != null && parentUserId.isNotEmpty)
                            ? InkWell(
                                onTap: () => _goUser(parentUserId),
                                child: Text(
                                  parentNickname,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              )
                            : Text(
                                parentNickname,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                      const Text('：'),
                      Text('${c['content'] ?? ''}'),
                    ],
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
                              size: 16, color: liked ? Colors.red : Colors.grey),
                          const SizedBox(width: 4),
                          Text('$likeCount', style: const TextStyle(fontSize: 12)),
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

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
          const SizedBox(height: 6),
          // 扁平所有子孙
          ..._replies.map((e) => _buildOne(e, isRoot: false)),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  
}
