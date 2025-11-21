import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iacg/widgets/post_card.dart';
import '../../services/post_service.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';


class HomeIslandTab extends StatefulWidget {
  const HomeIslandTab({super.key});

  @override
  State<HomeIslandTab> createState() => _HomeIslandTabState();
}

class _HomeIslandTabState extends State<HomeIslandTab> {
  final List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  String? _error;
  String _selectedType = '全部';

  // 群岛类型选项 - 只显示数据库中实际存在的类型
  final List<String> _islandTypes = ['全部', '求助', '分享', '吐槽', '找搭子', '约拍', '其他'];

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts({String? type}) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
        if (type != null) {
          _selectedType = type;
        }
      });

      if (kDebugMode) {
        debugPrint('开始加载群岛帖子，类型: $_selectedType');
      }

      // 使用真实的群岛帖子数据
      final String? islandType = _selectedType == '全部' ? null : _selectedType;
      final result =
          await PostService().fetchIslandPosts(islandType: islandType);

      if (kDebugMode) {
        debugPrint('成功加载 ${result.length} 条帖子');
      }

      setState(() {
        _posts.clear();
        _posts.addAll(result);
        _error = null; // 清除之前的错误
      });
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('加载群岛帖子出错: $e');
        debugPrint('错误堆栈: $stack');
      }
      setState(() {
        _error = '加载失败: ${e.toString()}';
        _posts.clear(); // 出错时清空列表
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 回到顶部
  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // 构建类型筛选器
  Widget _buildTypeFilter() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _islandTypes.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final type = _islandTypes[index];
          final isSelected = _selectedType == type;

          return GestureDetector(
            onTap: () {
              if (!isSelected) {
                _scrollToTop();
                _loadPosts(type: type);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                type,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 获取类型颜色
  Color _getTypeColor(String type) {
    switch (type) {
      case '求助':
        return Colors.orange;
      case '分享':
        return Colors.green;
      case '吐槽':
        return Colors.red;
      case '找搭子':
        return Colors.blue;
      case '约拍':
        return Colors.purple;
      case '其他':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  // 获取类型背景颜色
  Color _getTypeBackgroundColor(String type) {
    final baseColor = _getTypeColor(type);
    return Color.alphaBlend(baseColor.withAlpha(25), Colors.white);
  }

  // 获取类型边框颜色
  Color _getTypeBorderColor(String type) {
    final baseColor = _getTypeColor(type);
    return Color.alphaBlend(baseColor.withAlpha(75), Colors.white);
  }

  // 构建群岛帖子卡片
  Widget _buildIslandPostCard(Map<String, dynamic> post) {
    final author = post['author'] as Map<String, dynamic>?;
    final islandType = post['island_type'] as String? ?? '讨论';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 作者信息和类型标签
            Row(
              children: [
                if (author != null) ...[
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.grey[300],
                    child: author['avatar_url'] != null
                        ? ClipOval(
                            child: Image.network(
                              author['avatar_url'].toString(),
                              width: 24,
                              height: 24,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Text(
                            author['nickname']?.toString().substring(0, 1) ??
                                'U',
                            style: const TextStyle(fontSize: 10),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    author['nickname']?.toString() ?? '未知用户',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const Spacer(),
                // 类型标签
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getTypeBackgroundColor(islandType),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getTypeBorderColor(islandType),
                    ),
                  ),
                  child: Text(
                    islandType,
                    style: TextStyle(
                      fontSize: 12,
                      color: _getTypeColor(islandType),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 标题
            Text(
              post['title']?.toString() ?? '无标题',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // 正文摘要
            if (post['content'] != null &&
                post['content'].toString().isNotEmpty)
              Text(
                post['content'].toString(),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 12),
            // 互动数据
            Row(
              children: [
                const Icon(Icons.chat_bubble_outline,
                    size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  (post['comment_count'] ?? 0).toString(),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.visibility_outlined,
                    size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  (post['view_count'] ?? 0).toString(),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const Spacer(),
                Text(
                  _formatTime(post['created_at']),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
          const Icon(Icons.forum_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            _selectedType == '全部' ? '暂无群岛帖子' : '暂无$_selectedType类型的帖子',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 类型筛选器
        _buildTypeFilter(),
        const SizedBox(height: 8),
        // 帖子列表
        Expanded(
          child: _isLoading
              ? const LoadingView()
              : _error != null
                  ? ErrorView(error: _error!)
                  : _posts.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: () => _loadPosts(),
                          child: 
                          // ListView.builder(
                          //   controller: _scrollController,
                          //   itemCount: _posts.length,
                          //   itemBuilder: (context, index) {
                          //     final post = _posts[index];
                          //     return _buildIslandPostCard(post);
                          //   },
                          // ),
                          ListView.builder(
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
