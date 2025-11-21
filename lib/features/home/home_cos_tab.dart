import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iacg/services/tag_service.dart';
import 'package:iacg/widgets/post_card.dart';
import '../../services/post_service.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';

class HomeCosTab extends StatefulWidget {
  const HomeCosTab({super.key});

  @override
  State<HomeCosTab> createState() => _HomeCosTabState();
}

class _HomeCosTabState extends State<HomeCosTab> {
  final List<Map<String, dynamic>> _posts = [];
  final List<Map<String, dynamic>> _ipTags = [];
  final TagService _tagService = TagService(); // B新增
  bool _isLoading = true;
  bool _isLoadingTags = true;
  String? _error;

  // 筛选状态
  String _selectedCategory = '全部';
  String _selectedIp = '全部';

  // 筛选面板状态
  bool _showFilterPanel = false;
  FilterType _currentFilterType = FilterType.none;

  // COS 分类选项
  final List<String> _cosCategories = ['全部', '动漫', '游戏', '漫画', '小说', '其他'];

  final ScrollController _scrollController = ScrollController();
  final PostService _postService = PostService();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _loadIpTags(); // ← 新增：首次进入先加载 IP 筛选项
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadPosts(),
      _loadIpTags(),
    ]);
  }

  Future<void> _loadPosts() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      if (kDebugMode) {
        debugPrint('开始加载COS帖子，分类: $_selectedCategory, IP: $_selectedIp');
      }

      final String? cosCategory =
          _selectedCategory == '全部' ? null : _selectedCategory;
      final String? ipTag = _selectedIp == '全部' ? null : _selectedIp;

      final result = await _postService.fetchCosPosts(
        category: cosCategory,
        ipTag: ipTag,
      );

      if (kDebugMode) {
        debugPrint('加载完成: ${result.length} 条');
      }

      setState(() {
        _posts.clear();
        _posts.addAll(result);
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = '加载失败: ${e.toString()}';
        _posts.clear();
      });
      if (kDebugMode) {
        debugPrint('COS页面加载错误: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Future<void> _loadIpTags() async {
  //   try {
  //     final result = await _tagService.fetchHotCosIpTags();
  //     setState(() {
  //       _ipTags.clear();
  //       _ipTags.addAll(result);
  //     });
  //   } catch (e) {
  //     if (kDebugMode) {
  //       debugPrint('加载IP标签出错: $e');
  //     }
  //   } finally {
  //     if (mounted) {
  //       setState(() {
  //         _isLoadingTags = false;
  //       });
  //     }
  //   }
  // }
  Future<void> _loadIpTags() async {
    setState(() {
      _isLoadingTags = true;
    });

    try {
      // 按当前所选类型获取 IP；当 _selectedCategory == '全部' 时，
      // TagService 会自动返回“热门 IP”
      final list = await _tagService.fetchIpTagsByCategory(
        categoryZh: _selectedCategory,
        limit: 50,
      );

      // 若该类型暂时没有相关 IP，则退回热门
      final result = (list.isEmpty && _selectedCategory != '全部')
          ? await _tagService.fetchHotIpTags(topN: 50)
          : list;

      setState(() {
        _ipTags
          ..clear()
          ..addAll(result);
        // 切换类型后重置 IP 选择为“全部”
        _selectedIp = '全部';
      });
    } catch (e) {
      // 出错兜底热门
      try {
        final hot = await _tagService.fetchHotIpTags(topN: 50);
        setState(() {
          _ipTags
            ..clear()
            ..addAll(hot);
          _selectedIp = '全部';
        });
      } catch (_) {}
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTags = false;
        });
      }
    }
  }


  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // 打开筛选面板
  void _openFilterPanel(FilterType type) {
    setState(() {
      _showFilterPanel = true;
      _currentFilterType = type;
    });
  }

  // 关闭筛选面板
  void _closeFilterPanel() {
    setState(() {
      _showFilterPanel = false;
      _currentFilterType = FilterType.none;
    });
  }

  // 应用筛选
  void _applyFilters() {
    _closeFilterPanel();
    _scrollToTop();
    _loadPosts();
  }

  // 清除所有筛选
  void _clearFilters() {
    setState(() {
      _selectedCategory = '全部';
      _selectedIp = '全部';
    });
    _closeFilterPanel();
    _scrollToTop();
    _loadPosts();
  }

  // 构建筛选面板
  Widget _buildFilterPanel() {
    if (!_showFilterPanel) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 面板标题
          Row(
            children: [
              Text(
                _currentFilterType == FilterType.category ? '选择类型' : '选择IP',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // 关闭按钮
              IconButton(
                onPressed: _closeFilterPanel,
                icon: const Icon(Icons.close, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 筛选内容
          _buildFilterOptions(),
          const SizedBox(height: 16),
          // 应用按钮
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _applyFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '应用筛选',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建筛选选项
  Widget _buildFilterOptions() {
    if (_currentFilterType == FilterType.category) {
      return _buildCategoryOptions();
    } else {
      return _buildIpOptions();
    }
  }

  // 构建类型选项
  Widget _buildCategoryOptions() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _cosCategories.map((category) {
        final isSelected = _selectedCategory == category;
        return GestureDetector(
          onTap: () {
            // setState(() {
            //   _selectedCategory = category;
            // });
            if (_selectedCategory == category) return; // 同项不重复
            setState(() {
              _selectedCategory = category;
            });
            _loadIpTags(); // ← 新增：类型变更后刷新 IP 选项列表
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[300]!,
              ),
            ),
            child: Text(
              category,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // 构建 IP 选项
  Widget _buildIpOptions() {
    return _isLoadingTags
        ? const Center(child: CircularProgressIndicator())
        : Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              // "全部"选项
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedIp = '全部';
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color:
                        _selectedIp == '全部' ? Colors.purple : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _selectedIp == '全部'
                          ? Colors.purple
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: Text(
                    '全部',
                    style: TextStyle(
                      color:
                          _selectedIp == '全部' ? Colors.white : Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              // IP 标签选项
              ..._ipTags.map((tag) {
                final tagName = tag['name'] as String;
                final isSelected = _selectedIp == tagName;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIp = tagName;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.purple : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? Colors.purple : Colors.grey[300]!,
                      ),
                    ),
                    child: Text(
                      tagName,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
  }

  // 构建筛选状态显示
  Widget _buildFilterStatus() {
    if (_selectedCategory == '全部' && _selectedIp == '全部') {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[50],
      child: Row(
        children: [
          const Icon(Icons.filter_alt_outlined, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _buildFilterStatusText(),
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _clearFilters,
            child: const Row(
              children: [
                Icon(Icons.clear, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  '清除',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildFilterStatusText() {
    final parts = <String>[];
    if (_selectedCategory != '全部') parts.add('类型: $_selectedCategory');
    if (_selectedIp != '全部') parts.add('IP: $_selectedIp');
    return '已筛选: ${parts.join(' | ')}';
  }

  // 构建筛选按钮
  Widget _buildFilterButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // 类型筛选按钮
          Expanded(
            child: _buildFilterButton(
              label: _selectedCategory == '全部' ? '类型' : _selectedCategory,
              icon: Icons.category_outlined,
              isActive: _selectedCategory != '全部',
              onTap: () => _openFilterPanel(FilterType.category),
            ),
          ),
          const SizedBox(width: 12),
          // IP筛选按钮
          Expanded(
            child: _buildFilterButton(
              label: _selectedIp == '全部' ? 'IP' : _selectedIp,
              icon: Icons.videogame_asset_outlined,
              isActive: _selectedIp != '全部',
              onTap: () => _openFilterPanel(FilterType.ip),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color:
              isActive ? Theme.of(context).colorScheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.white : Colors.grey[700],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // 构建 COS 帖子卡片
  // Widget _buildCosPostCard(Map<String, dynamic> post) {
  //   final author = post['author'] as Map<String, dynamic>?;
  //   final postMedia = post['post_media'] as List<dynamic>?;
  //   final tags = post['tags'] as List<dynamic>?;

  //   return Card(
  //     margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  //     child: InkWell(
  //       onTap: _showComingSoonDialog,
  //       child: Padding(
  //         padding: const EdgeInsets.all(16),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             // 作者信息
  //             Row(
  //               children: [
  //                 if (author != null) ...[
  //                   CircleAvatar(
  //                     radius: 12,
  //                     backgroundColor: Colors.grey[300],
  //                     child: author['avatar_url'] != null
  //                         ? ClipOval(
  //                             child: Image.network(
  //                               author['avatar_url'].toString(),
  //                               width: 24,
  //                               height: 24,
  //                               fit: BoxFit.cover,
  //                             ),
  //                           )
  //                         : Text(
  //                             author['nickname']?.toString().substring(0, 1) ??
  //                                 'U',
  //                             style: const TextStyle(fontSize: 10),
  //                           ),
  //                   ),
  //                   const SizedBox(width: 8),
  //                   Text(
  //                     author['nickname']?.toString() ?? '未知用户',
  //                     style: const TextStyle(
  //                       fontSize: 14,
  //                       fontWeight: FontWeight.w500,
  //                     ),
  //                   ),
  //                 ],
  //               ],
  //             ),
  //             const SizedBox(height: 12),
  //             // 标题
  //             Text(
  //               post['title']?.toString() ?? '无标题',
  //               style: const TextStyle(
  //                 fontSize: 16,
  //                 fontWeight: FontWeight.bold,
  //               ),
  //               maxLines: 2,
  //               overflow: TextOverflow.ellipsis,
  //             ),
  //             const SizedBox(height: 8),
  //             // 分类和 IP 标签
  //             Wrap(
  //               spacing: 8,
  //               runSpacing: 4,
  //               children: [
  //                 // 分类标签
  //                 if (post['main_category'] != null)
  //                   Container(
  //                     padding: const EdgeInsets.symmetric(
  //                         horizontal: 8, vertical: 4),
  //                     decoration: BoxDecoration(
  //                       color: Colors.blue[50],
  //                       borderRadius: BorderRadius.circular(12),
  //                       border: Border.all(color: Colors.blue[200]!),
  //                     ),
  //                     child: Text(
  //                       _postService
  //                           .getCategoryDisplayName(post['main_category']),
  //                       style: const TextStyle(
  //                         fontSize: 10,
  //                         color: Colors.blue,
  //                         fontWeight: FontWeight.w500,
  //                       ),
  //                     ),
  //                   ),
  //                 // IP 标签
  //                 if (tags != null) ...[
  //                   ...tags.where((tagRelation) {
  //                     final tag = tagRelation['tag'] as Map<String, dynamic>?;
  //                     return tag != null && tag['type'] == 'ip';
  //                   }).map((tagRelation) {
  //                     final tag = tagRelation['tag'] as Map<String, dynamic>;
  //                     return Container(
  //                       padding: const EdgeInsets.symmetric(
  //                           horizontal: 8, vertical: 4),
  //                       decoration: BoxDecoration(
  //                         color: Colors.purple[50],
  //                         borderRadius: BorderRadius.circular(12),
  //                         border: Border.all(color: Colors.purple[200]!),
  //                       ),
  //                       child: Text(
  //                         tag['name'] as String? ?? '',
  //                         style: const TextStyle(
  //                           fontSize: 10,
  //                           color: Colors.purple,
  //                           fontWeight: FontWeight.w500,
  //                         ),
  //                       ),
  //                     );
  //                   }),
  //                 ],
  //               ],
  //             ),
  //             const SizedBox(height: 8),
  //             // 图片预览
  //             if (postMedia?.isNotEmpty == true)
  //               ClipRRect(
  //                 borderRadius: BorderRadius.circular(8),
  //                 child: Image.network(
  //                   postMedia![0]['media_url'] as String,
  //                   width: double.infinity,
  //                   height: 200,
  //                   fit: BoxFit.cover,
  //                   errorBuilder: (context, error, stackTrace) => Container(
  //                     width: double.infinity,
  //                     height: 200,
  //                     color: Colors.grey[200],
  //                     child: const Icon(Icons.broken_image, color: Colors.grey),
  //                   ),
  //                 ),
  //               ),
  //             const SizedBox(height: 12),
  //             // 互动数据
  //             Row(
  //               children: [
  //                 const Icon(Icons.favorite_border,
  //                     size: 16, color: Colors.grey),
  //                 const SizedBox(width: 4),
  //                 Text(
  //                   (post['like_count'] ?? 0).toString(),
  //                   style: const TextStyle(fontSize: 12, color: Colors.grey),
  //                 ),
  //                 const SizedBox(width: 16),
  //                 const Icon(Icons.chat_bubble_outline,
  //                     size: 16, color: Colors.grey),
  //                 const SizedBox(width: 4),
  //                 Text(
  //                   (post['comment_count'] ?? 0).toString(),
  //                   style: const TextStyle(fontSize: 12, color: Colors.grey),
  //                 ),
  //                 const SizedBox(width: 16),
  //                 const Icon(Icons.bookmark_border,
  //                     size: 16, color: Colors.grey),
  //                 const SizedBox(width: 4),
  //                 Text(
  //                   (post['favorite_count'] ?? 0).toString(),
  //                   style: const TextStyle(fontSize: 12, color: Colors.grey),
  //                 ),
  //                 const Spacer(),
  //                 Text(
  //                   _formatTime(post['created_at']),
  //                   style: const TextStyle(fontSize: 12, color: Colors.grey),
  //                 ),
  //               ],
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  String _formatTime(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return '刚刚';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}分钟前';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}小时前';
      } else if (difference.inDays < 30) {
        return '${difference.inDays}天前';
      } else {
        return '${date.month}-${date.day}';
      }
    } catch (e) {
      return '未知时间';
    }
  }

  // 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_search, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            _buildEmptyStateText(),
            style: const TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loadPosts,
            child: const Text('重新加载'),
          ),
        ],
      ),
    );
  }

  String _buildEmptyStateText() {
    if (_selectedCategory != '全部' && _selectedIp != '全部') {
      return '暂无$_selectedCategory类型的$_selectedIp COS作品';
    } else if (_selectedCategory != '全部') {
      return '暂无$_selectedCategory类型的COS作品';
    } else if (_selectedIp != '全部') {
      return '暂无$_selectedIp相关的COS作品';
    } else {
      return '暂无COS作品';
    }
  }

  void _showComingSoonDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('功能开发中'),
        content: const Text('COS帖子详情功能即将上线，敬请期待！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 筛选按钮
        _buildFilterButtons(),
        // 筛选面板
        _buildFilterPanel(),
        // 筛选状态栏
        _buildFilterStatus(),
        // 帖子列表
        Expanded(
          child: _isLoading
              ? const LoadingView()
              : _error != null
                  ? ErrorView(error: _error!)
                  : _posts.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadPosts,
                          child: ListView.builder(
                            controller: _scrollController,
                            itemCount: _posts.length,
                            itemBuilder: (context, index) => PostCard(post: _posts[index]),
                          ),
                        ),
        ),
      ],
    );
  }
}

// 筛选类型枚举
enum FilterType {
  none,
  category,
  ip,
}
