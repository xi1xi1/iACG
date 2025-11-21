import 'package:flutter/material.dart';
import '../../services/post_service.dart';
import '../../widgets/post_card.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/empty_view.dart';

class HomeRecommendTab extends StatefulWidget {
  const HomeRecommendTab({super.key});

  @override
  State<HomeRecommendTab> createState() => _HomeRecommendTabState();
}

class _HomeRecommendTabState extends State<HomeRecommendTab> {
  final List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  String? _error;

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

      final result = await PostService().fetchRecommendPosts();
      setState(() {
        _posts.clear();
        _posts.addAll(result);
      });
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingView();
    if (_error != null) return ErrorView(error: _error!);
    if (_posts.isEmpty) return const EmptyView();

    // 将帖子分成左右两列
    List<Map<String, dynamic>> leftPosts = [];
    List<Map<String, dynamic>> rightPosts = [];

    for (int i = 0; i < _posts.length; i++) {
      if (i % 2 == 0) {
        leftPosts.add(_posts[i]);
      } else {
        rightPosts.add(_posts[i]);
      }
    }

    // 在 HomeRecommendTab 的 build 方法中
    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6), // 减少整体水平内边距
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左列
                  Expanded(
                    child: Column(
                      children: leftPosts.map((post) {
                        return PostCard(
                          post: post,
                          isLeftColumn: true,
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(width: 6), // 减少列间距

                  // 右列
                  Expanded(
                    child: Column(
                      children: rightPosts.map((post) {
                        return PostCard(
                          post: post,
                          isLeftColumn: false,
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}