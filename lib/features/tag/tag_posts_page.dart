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

  int? _totalCount;
  String _sort = 'latest';
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
    try {
      final r = await _tagService.searchTags(widget.tagName, limit: 1);
      if (!mounted) return;
      if (r.isNotEmpty) {
        _tagId = r.first['id'] as int;
        final n = await _tagService.countTagPosts(tagId: _tagId!, channel: null);
        if (!mounted) return;
        setState(() => _totalCount = n);
      } else {
        setState(() => _totalCount = 0);
      }
    } catch (_) {}
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

      try {
        rows = await _postService.fetchPostsByTag(
          widget.tagName,
          limit: _pageSize,
          offset: offset,
          orderBy: _sort,
        );
      } catch (_) {
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
    if (_tagId != null) {
      try {
        final n = await _tagService.countTagPosts(tagId: _tagId!, channel: null);
        if (mounted) setState(() => _totalCount = n);
      } catch (_) {}
    }
    await _load(reset: true);
  }

  // 将帖子列表分成两列
  List<List<Map<String, dynamic>>> _splitPostsIntoTwoColumns() {
    final column1 = <Map<String, dynamic>>[];
    final column2 = <Map<String, dynamic>>[];

    for (int i = 0; i < _posts.length; i++) {
      if (i % 2 == 0) {
        column1.add(_posts[i]);
      } else {
        column2.add(_posts[i]);
      }
    }

    return [column1, column2];
  }

  @override
  Widget build(BuildContext context) {
    final title = '#${widget.tagName}'
        '${_totalCount == null ? '' : ' · 参与量 $_totalCount'}';

    // 分割帖子到两列
    final columns = _splitPostsIntoTwoColumns();
    final column1 = columns[0];
    final column2 = columns[1];

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          // 顶部筛选栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                const Text(
                  '排序：',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                // 最新按钮
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      if (_sort != 'latest') {
                        setState(() => _sort = 'latest');
                        _load(reset: true);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _sort == 'latest'
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade700,
                      backgroundColor: _sort == 'latest'
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                          : Colors.transparent,
                      side: BorderSide(
                        color: _sort == 'latest'
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(8),
                          bottomLeft: const Radius.circular(8),
                          topRight: Radius.zero,
                          bottomRight: Radius.zero,
                        ),
                      ),
                    ),
                    child: const Text(
                      '最新',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                // 最热按钮
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      if (_sort != 'hot') {
                        setState(() => _sort = 'hot');
                        _load(reset: true);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _sort == 'hot'
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade700,
                      backgroundColor: _sort == 'hot'
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                          : Colors.transparent,
                      side: BorderSide(
                        color: _sort == 'hot'
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.zero,
                          bottomLeft: Radius.zero,
                          topRight: const Radius.circular(8),
                          bottomRight: const Radius.circular(8),
                        ),
                      ),
                    ),
                    child: const Text(
                      '最热',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
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
                  : SingleChildScrollView(
                controller: _scroll,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 第一列
                      Expanded(
                        child: Column(
                          children: [
                            ...column1.map((post) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 4, horizontal: 4),
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => PostDetailPage(
                                          postId: (post['id'] as num).toInt(),
                                        ),
                                      ),
                                    );
                                  },
                                  child: PostCard(post: post),
                                ),
                              );
                            }).toList(),
                            // 加载状态
                            if (!_end && _loading)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(child: CircularProgressIndicator()),
                              ),
                            if (_end) const SizedBox(height: 48),
                          ],
                        ),
                      ),
                      // 第二列
                      Expanded(
                        child: Column(
                          children: column2.map((post) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 4),
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => PostDetailPage(
                                        postId: (post['id'] as num).toInt(),
                                      ),
                                    ),
                                  );
                                },
                                child: PostCard(post: post),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}