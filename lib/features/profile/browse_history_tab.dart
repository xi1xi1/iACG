<<<<<<< HEAD
=======
// lib/features/profile/browse_history_tab.dart
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../post/post_detail_page.dart';

class BrowseHistoryTab extends StatefulWidget {
<<<<<<< HEAD
  const BrowseHistoryTab({super.key});
=======
  const BrowseHistoryTab({Key? key}) : super(key: key);
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1

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

<<<<<<< HEAD
=======
  /// 从本地加载浏览历史
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
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

<<<<<<< HEAD
=======
  /// 清空浏览历史
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
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
<<<<<<< HEAD
            child: const Text(
              '确定',
              style: TextStyle(color: Color(0xFFEC4899)),
            ),
=======
            child: const Text('确定', style: TextStyle(color: Colors.red)),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
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
<<<<<<< HEAD
            const SnackBar(
              content: Text('已清空浏览记录'),
              backgroundColor: Color(0xFFEC4899),
            ),
=======
            const SnackBar(content: Text('已清空浏览记录')),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
<<<<<<< HEAD
            SnackBar(
              content: Text('清空失败: $e'),
              backgroundColor: Colors.red,
            ),
=======
            SnackBar(content: Text('清空失败: $e')),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
          );
        }
      }
    }
  }

<<<<<<< HEAD
=======
  /// 删除单条记录
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
  Future<void> _deleteHistoryItem(int postId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _historyList.removeWhere((item) => item['postId'] == postId);

      await prefs.setString('browse_history', jsonEncode(_historyList));

      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
<<<<<<< HEAD
          const SnackBar(
            content: Text('已删除'),
            backgroundColor: Color(0xFFEC4899),
          ),
=======
          const SnackBar(content: Text('已删除')),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
<<<<<<< HEAD
          SnackBar(
            content: Text('删除失败: $e'),
            backgroundColor: Colors.red,
          ),
=======
          SnackBar(content: Text('删除失败: $e')),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
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

<<<<<<< HEAD
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PostDetailPage(postId: postId),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
          border: Border.all(
            color: Colors.grey.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // 封面图
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 70,
                height: 70,
                color: Colors.grey[200],
                child: coverUrl != null && coverUrl.isNotEmpty
                    ? Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.image,
                    color: Colors.grey[400],
                    size: 24,
                  ),
                )
                    : Icon(
                  Icons.image,
                  color: Colors.grey[400],
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // 内容区域
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatTime(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // 删除按钮
            IconButton(
              icon: Icon(Icons.close, size: 18, color: Colors.grey[600]),
              onPressed: () => _deleteHistoryItem(postId),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
=======
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
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
        ),
      ),
    );
  }

  Widget _buildLoading() {
<<<<<<< HEAD
    return Container(
      color: Colors.white,
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC4899)),
        ),
      ),
=======
    return const SizedBox(
      height: 300,
      child: Center(child: CircularProgressIndicator()),
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
    );
  }

  Widget _buildEmpty() {
<<<<<<< HEAD
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              '暂无浏览记录',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
=======
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('暂无浏览记录', style: TextStyle(fontSize: 16, color: Colors.grey)),
            SizedBox(height: 8),
            Text(
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
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
<<<<<<< HEAD
    return Container(
      color: Colors.white,
      child: _isLoading
          ? _buildLoading()
          : _historyList.isEmpty
          ? _buildEmpty()
          : Column(
        children: [
          // 清空按钮栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey.withOpacity(0.1)),
              ),
            ),
=======
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
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '共 ${_historyList.length} 条记录',
                  style: TextStyle(
                    fontSize: 14,
<<<<<<< HEAD
                    color: Colors.grey[600],
=======
                    color: Colors.grey.shade600,
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
                  ),
                ),
                TextButton.icon(
                  onPressed: _clearHistory,
<<<<<<< HEAD
                  icon: Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  label: Text(
                    '清空',
                    style: TextStyle(color: Colors.red, fontSize: 14),
=======
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('清空'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
                  ),
                ),
              ],
            ),
          ),
<<<<<<< HEAD

          // 历史记录列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _historyList.length,
              itemBuilder: (context, index) => _buildHistoryCard(_historyList[index]),
            ),
          ),
        ],
      ),
=======
        ),
        // 历史记录列表
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildHistoryCard(_historyList[index]),
            childCount: _historyList.length,
          ),
        ),
      ],
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
    );
  }
}

<<<<<<< HEAD
=======
/// ====================================================================
/// 工具方法：记录浏览历史（在帖子详情页调用）
/// ====================================================================
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
Future<void> saveBrowseHistory({
  required int postId,
  required String title,
  String? coverUrl,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString('browse_history') ?? '[]';
    List<dynamic> history = jsonDecode(historyJson);

<<<<<<< HEAD
    history.removeWhere((item) => item['postId'] == postId);

=======
    // 移除旧记录（如果存在）
    history.removeWhere((item) => item['postId'] == postId);

    // 添加到开头
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
    history.insert(0, {
      'postId': postId,
      'title': title,
      'coverUrl': coverUrl,
      'timestamp': DateTime.now().toIso8601String(),
    });

<<<<<<< HEAD
=======
    // 限制最多保存100条
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
    if (history.length > 100) {
      history = history.sublist(0, 100);
    }

    await prefs.setString('browse_history', jsonEncode(history));
    print('✅ 浏览记录已保存: $title');
  } catch (e) {
    print('❌ 保存浏览历史失败: $e');
  }
}