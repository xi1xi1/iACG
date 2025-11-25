// lib/features/profile/browse_history_tab.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../post/post_detail_page.dart';

class BrowseHistoryTab extends StatefulWidget {
  const BrowseHistoryTab({super.key});

  @override
  State<BrowseHistoryTab> createState() => _BrowseHistoryTabState();
}

class _BrowseHistoryTabState extends State<BrowseHistoryTab> {
  List<Map<String, dynamic>> _historyList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  /// 从本地加载浏览历史
  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('browse_history') ?? '[]';
      final List<dynamic> decoded = jsonDecode(historyJson);

      setState(() {
        _historyList = decoded.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      print('加载浏览历史失败: $e');
      setState(() {
        _historyList = [];
        _isLoading = false;
      });
    }
  }

  /// 清空浏览历史
  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空浏览记录'),
        content: const Text('确定要清空所有浏览记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('browse_history');

        setState(() {
          _historyList = [];
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已清空浏览记录')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('清空失败: $e')),
          );
        }
      }
    }
  }

  /// 删除单条记录
  Future<void> _deleteHistoryItem(int postId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _historyList.removeWhere((item) => item['postId'] == postId);

      await prefs.setString('browse_history', jsonEncode(_historyList));

      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final int postId = item['postId'] as int;
    final String title = item['title'] as String? ?? '无标题';
    final String? coverUrl = item['coverUrl'] as String?;
    final String timestamp = item['timestamp'] as String? ?? '';

    String formatTime() {
      if (timestamp.isEmpty) return '';
      try {
        final date = DateTime.parse(timestamp);
        final now = DateTime.now();
        final diff = now.difference(date);

        if (diff.inMinutes < 1) return '刚刚';
        if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
        if (diff.inHours < 24) return '${diff.inHours}小时前';
        if (diff.inDays < 7) return '${diff.inDays}天前';
        return '${date.month}月${date.day}日';
      } catch (_) {
        return '';
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PostDetailPage(postId: postId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 封面图或占位符
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: coverUrl != null && coverUrl.isNotEmpty
                      ? Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image, color: Colors.grey),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // 标题和时间
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatTime(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              // 删除按钮
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => _deleteHistoryItem(postId),
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const SizedBox(
      height: 300,
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildEmpty() {
    return const SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('暂无浏览记录', style: TextStyle(fontSize: 16, color: Colors.grey)),
            SizedBox(height: 8),
            Text(
              '你浏览过的帖子会显示在这里',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoading();
    }

    if (_historyList.isEmpty) {
      return _buildEmpty();
    }

    return CustomScrollView(
      slivers: [
        // 清空按钮栏
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '共 ${_historyList.length} 条记录',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                TextButton.icon(
                  onPressed: _clearHistory,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('清空'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
        // 历史记录列表
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildHistoryCard(_historyList[index]),
            childCount: _historyList.length,
          ),
        ),
      ],
    );
  }
}

/// ====================================================================
/// 工具方法：记录浏览历史（在帖子详情页调用）
/// ====================================================================
Future<void> saveBrowseHistory({
  required int postId,
  required String title,
  String? coverUrl,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString('browse_history') ?? '[]';
    List<dynamic> history = jsonDecode(historyJson);

    // 移除旧记录（如果存在）
    history.removeWhere((item) => item['postId'] == postId);

    // 添加到开头
    history.insert(0, {
      'postId': postId,
      'title': title,
      'coverUrl': coverUrl,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // 限制最多保存100条
    if (history.length > 100) {
      history = history.sublist(0, 100);
    }

    await prefs.setString('browse_history', jsonEncode(history));
    print('✅ 浏览记录已保存: $title');
  } catch (e) {
    print('❌ 保存浏览历史失败: $e');
  }
}