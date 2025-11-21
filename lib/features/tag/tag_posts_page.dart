// import 'package:flutter/material.dart';
// import '../../services/post_service.dart';
// import '../../widgets/post_card.dart';
// import '../post/post_detail_page.dart';

// class TagPostsPage extends StatefulWidget {
//   final String tagName;
//   const TagPostsPage({super.key, required this.tagName});

//   @override
//   State<TagPostsPage> createState() => _TagPostsPageState();
// }

// class _TagPostsPageState extends State<TagPostsPage> {
//   final _postService = PostService();
//   final _posts = <Map<String, dynamic>>[];
//   bool _loading = true;
//   String? _error;

//   @override
//   void initState() {
//     super.initState();
//     _load();
//   }

//   Future<void> _load() async {
//     setState(() { _loading = true; _error = null; });
//     try {
//       final rows = await _postService.fetchPostsByTag(widget.tagName, limit: 50);
//       if (!mounted) return;
//       setState(() {
//         _posts
//           ..clear()
//           ..addAll(rows);
//       });
//     } catch (e) {
//       if (!mounted) return;
//       setState(() => _error = e.toString());
//     } finally {
//       if (mounted) setState(() => _loading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('#${widget.tagName}')),
//       body: _loading
//           ? const Center(child: CircularProgressIndicator())
//           : _error != null
//               ? Center(child: Text('加载失败：$_error'))
//               : _posts.isEmpty
//                   ? const Center(child: Text('暂无相关帖子'))
//                   : ListView.separated(
//                       itemCount: _posts.length,
//                       separatorBuilder: (_, __) => const Divider(height: 1),
//                       itemBuilder: (context, i) {
//                         final p = _posts[i];
//                         return GestureDetector(
//                           onTap: () {
//                             Navigator.of(context).push(
//                               MaterialPageRoute(
//                                 builder: (_) => PostDetailPage(postId: p['id'] as int),
//                               ),
//                             );
//                           },
//                           child: PostCard(post: p), // 你已有 PostCard 就复用；没有就用 ListTile
//                         );
//                       },
//                     ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import '../../services/post_service.dart';
import '../../services/tag_service.dart';
import '../../widgets/post_card.dart';
import '../post/post_detail_page.dart';

class TagPostsPage extends StatefulWidget {
  final String tagName;
  const TagPostsPage({super.key, required this.tagName});

  @override
  State<TagPostsPage> createState() => _TagPostsPageState();
}

class _TagPostsPageState extends State<TagPostsPage> {
  final _postService = PostService();
  final _tagService = TagService();
  final _scroll = ScrollController();

  final _posts = <Map<String, dynamic>>[];
  final _seenIds = <int>{};

  bool _loading = false;
  bool _end = false;
  String? _error;

  static const _pageSize = 20;

  // 新增：参与量（总数），以及“最新/最热”筛选
  int? _totalCount;
  String _sort = 'latest'; // 'latest' | 'hot'

  // 解析出来的 tagId（用于计数）
  int? _tagId;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    // 先查 tagId（以便显示参与量）
    try {
      final r = await _tagService.searchTags(widget.tagName, limit: 1);
      if (!mounted) return;
      if (r.isNotEmpty) {
        _tagId = r.first['id'] as int;
        // 用 RPC 计数
        final n = await _tagService.countTagPosts(tagId: _tagId!, channel: null);
        if (!mounted) return;
        setState(() => _totalCount = n);
      } else {
        // 没找到就显示 0，不影响列表加载（按 name 拉）
        setState(() => _totalCount = 0);
      }
    } catch (_) {
      // 失败也不影响帖子加载
    }

    // 加载列表
    await _load(reset: true);
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200) {
      if (!_loading && !_end) _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) _end = false;
    });

    try {
      final offset = reset ? 0 : _posts.length;

      List<Map<String, dynamic>> rows = const [];

      // 优先尝试带排序参数（与你的 PostService 对接“最热/最新”）
      try {
        rows = await _postService.fetchPostsByTag(
          widget.tagName,
          limit: _pageSize,
          offset: offset,
          // 你可以在 PostService 中按此参数决定 order by：
          // latest -> created_at desc
          // hot    -> like_count/comment_count/view_count 的权重排序
          orderBy: _sort, // 新增的可选参数；若 PostService 尚未支持，将进入下方 catch
        );
      } catch (_) {
        // 兼容：你的 PostService 还没有 orderBy 参数时，退回原有接口
        rows = await _postService.fetchPostsByTag(
          widget.tagName,
          limit: _pageSize,
          offset: offset,
        );
      }

      if (!mounted) return;

      setState(() {
        if (reset) {
          _posts.clear();
          _seenIds.clear();
        }
        for (final r in rows) {
          final id = (r['id'] as num).toInt();
          if (_seenIds.add(id)) {
            _posts.add(r);
          }
        }
        _end = rows.length < _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    // 刷新时也顺便刷新参与量（如果有 tagId）
    if (_tagId != null) {
      try {
        final n = await _tagService.countTagPosts(tagId: _tagId!, channel: null);
        if (mounted) setState(() => _totalCount = n);
      } catch (_) {}
    }
    await _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final title = '#${widget.tagName}'
        '${_totalCount == null ? '' : ' · 参与量 $_totalCount'}';

    final sortToggle = SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'latest', label: Text('最新')),
        ButtonSegment(value: 'hot', label: Text('最热')),
      ],
      selected: {_sort},
      onSelectionChanged: (s) {
        final v = s.first;
        if (v == _sort) return;
        setState(() => _sort = v);
        _load(reset: true);
      },
    );

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          // 顶部筛选栏：最新 / 最热
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                const Text('排序：'),
                const SizedBox(width: 8),
                Expanded(child: sortToggle),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _error != null
                  ? ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(child: Text('加载失败：$_error')),
                        ),
                      ],
                    )
                  : _posts.isEmpty && _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _posts.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 120),
                                Center(child: Text('暂无相关帖子')),
                              ],
                            )
                          : ListView.separated(
                              controller: _scroll,
                              itemCount: _posts.length + 1,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                if (i == _posts.length) {
                                  if (_end) return const SizedBox(height: 48);
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                }
                                final p = _posts[i];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => PostDetailPage(
                                          postId: (p['id'] as num).toInt(),
                                        ),
                                      ),
                                    );
                                  },
                                  child: PostCard(post: p),
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }
}

