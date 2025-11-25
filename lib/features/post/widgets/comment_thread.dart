import 'package:flutter/material.dart';
import 'package:iacg/services/post_service.dart';
import 'package:iacg/widgets/avatar_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
class CommentThread extends StatefulWidget {
  final int postId;
  final Map<String, dynamic> root;     // 一楼（含 user 信息）
  final ValueChanged<int>? onReplyTo;  // 点击“回复”时，把 commentId 回传给外层
  final VoidCallback? onAnyChanged;    // 点赞/回复后，若需要刷新整区，外层可用

  const CommentThread({
    super.key,
    required this.postId,
    required this.root,
    this.onReplyTo,
    this.onAnyChanged,
  });

  @override
  State<CommentThread> createState() => _CommentThreadState();
}

class _CommentThreadState extends State<CommentThread> {
  final _postService = PostService();

  late Future<void> _loadFuture;                 // 一次性加载整楼
  late Map<String, dynamic> _root;               // 本地持有主楼
  List<Map<String, dynamic>> _replies = [];      // 扁平回复层
  Set<int> _myLiked = <int>{};                   // 我点过赞的评论 id 集合（含主楼）

  @override
  void initState() {
    super.initState();
    _root = widget.root;
    _loadFuture = _loadThread();
  }

  Future<void> _loadThread() async {
    // 拉整楼
    final thread = await _postService.fetchThreadFlat(_root['id'] as int);
    final root = (thread['root'] ?? {}) as Map<String, dynamic>;
    final replies = (thread['replies'] as List).cast<Map<String, dynamic>>();

    // 批量标记我点过赞
    final uid = Supabase.instance.client.auth.currentUser?.id;
    Set<int> mine = <int>{};
    if (uid != null) {
      final allIds = <int>[
        if (root['id'] != null) root['id'] as int,
        ...replies.map<int>((e) => e['id'] as int),
      ];
      mine = await _postService.myLikedInThread(allIds, uid);
    }

    if (!mounted) return;
    setState(() {
      _root = root;
      _replies = replies;
      _myLiked = mine;
    });
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先登录')));
      return;
    }
    final nowLiked = await _postService.toggleCommentLike(commentId, uid);

    // 乐观更新：只改本楼数据，不动别楼、不刷新整区
    setState(() {
      if (nowLiked) {
        _myLiked = {..._myLiked, commentId};
        final idxRoot = (commentId == _root['id']);
        if (idxRoot) {
          _root['like_count'] = (_root['like_count'] ?? 0) + 1;
        } else {
          final i = _replies.indexWhere((e) => e['id'] == commentId);
          if (i >= 0) {
            _replies[i] = {
              ..._replies[i],
              'like_count': (_replies[i]['like_count'] ?? 0) + 1,
            };
          }
        }
      } else {
        _myLiked = _myLiked.where((id) => id != commentId).toSet();
        if (commentId == _root['id']) {
          _root['like_count'] = (_root['like_count'] ?? 1) - 1;
        } else {
          final i = _replies.indexWhere((e) => e['id'] == commentId);
          if (i >= 0) {
            _replies[i] = {
              ..._replies[i],
              'like_count': (_replies[i]['like_count'] ?? 1) - 1,
            };
          }
        }
      }
    });
  }

  Widget _buildOne(Map<String, dynamic> c, {bool isRoot = false}) {
    final cid = c['id'] as int;
    final name = (isRoot ? (c['user']?['nickname'] ?? c['user_nickname']) : c['user_nickname']) as String? ?? '用户';
    final avatar = (isRoot ? (c['user']?['avatar_url'] ?? c['user_avatar_url']) : c['user_avatar_url']) as String?;
    final time = _timeAgo((c['created_at'] as String?) ?? (c['created_at']?.toString()));
    final liked = _myLiked.contains(cid);
    final likeCount = (c['like_count'] ?? 0) as int;

    // 回复对象（仅回复层有意义）
    final replyTo = isRoot ? null : (c['parent_user_nickname'] as String?);

    return Padding(
      padding: EdgeInsets.only(left: isRoot ? 0 : 48, top: isRoot ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvatarWidget(imageUrl: avatar, size: isRoot ? 36 : 28),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 昵称 + 时间
                Row(
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: null, // 需要可点进主页可自行补 navigator
                        child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 4),
                // 内容（回复层：A 回复 B：xxx）
                if (replyTo == null)
                  Text('${c['content'] ?? ''}')
                else
                  RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(text: '$name ', style: const TextStyle(fontWeight: FontWeight.w600)),
                        const TextSpan(text: '回复 '),
                        TextSpan(text: '$replyTo：', style: const TextStyle(fontWeight: FontWeight.w600)),
                        TextSpan(text: '${c['content'] ?? ''}'),
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
                              size: 18, color: liked ? Colors.red : Colors.grey),
                          const SizedBox(width: 4),
                          Text('$likeCount'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    InkWell(
                      onTap: () => widget.onReplyTo?.call(cid), // 把“被回复 commentId”回传给外层
                      child: const Text('回复', style: TextStyle(color: Colors.grey)),
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
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (_root.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 一楼（主楼）
            _buildOne(_root, isRoot: true),
            const SizedBox(height: 4),
            // 扁平回复层（包含所有子孙）
            ..._replies.map((e) => _buildOne(e)),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}
