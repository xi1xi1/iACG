import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/post_service.dart';
import '../../widgets/post_card.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/empty_view.dart';


class FollowPage extends StatefulWidget {
  const FollowPage({super.key});

  @override
  State<FollowPage> createState() => _FollowPageState();
}

class _FollowPageState extends State<FollowPage> {
  final List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  String? _error;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // 如果没有登录，显示推荐内容
      if (!_authService.isLoggedIn) {
        final result = await PostService().fetchRecommendPosts();
        setState(() {
          _posts.clear();
          _posts.addAll(result);
        });
        return;
      }

      // 如果已登录，显示关注内容
      final userId = _authService.currentUserId;
      if (userId != null) {
        final result = await PostService().fetchFollowPosts(userId);
        setState(() {
          _posts.clear();
          _posts.addAll(result);
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 显示登录提示
  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('登录提示'),
        content: const Text('登录后可以查看你关注的创作者内容'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushNamed('/login');
            },
            child: const Text('去登录'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingView();
    if (_error != null) return ErrorView(error: _error!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('关注'),
        actions: [
          if (!_authService.isLoggedIn)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showLoginPrompt,
              tooltip: '登录后查看关注内容',
            ),
        ],
      ),
      body: _posts.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadPosts,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _posts.length,
                itemBuilder: (context, index) {
                  final post = _posts[index];
                  return PostCard(post: post);
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    if (!_authService.isLoggedIn) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              '登录后查看关注内容',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushNamed('/login'),
              child: const Text('立即登录'),
            ),
          ],
        ),
      );
    } else {
      return const EmptyView();
    }
  }
}
