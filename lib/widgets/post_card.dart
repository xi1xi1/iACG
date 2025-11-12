import 'package:flutter/material.dart';

class PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final author = post['author'] as Map<String, dynamic>?;
    final postMedia = post['post_media'] as List<dynamic>?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 作者信息
            if (author != null) _buildAuthorInfo(author),
            const SizedBox(height: 12),
            // 标题
            Text(
              post['title']?.toString() ?? '无标题',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // 图片预览
            if (postMedia != null && postMedia.isNotEmpty)
              _buildImagePreview(postMedia.first),
            const SizedBox(height: 8),
            // 互动数据
            _buildInteractionStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthorInfo(Map<String, dynamic> author) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey[300],
          child: author['avatar_url'] != null
              ? ClipOval(
                  child: Image.network(
                    author['avatar_url'].toString(),
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  ),
                )
              : Text(
                  author['nickname']?.toString().substring(0, 1) ?? 'U',
                  style: const TextStyle(fontSize: 12),
                ),
        ),
        const SizedBox(width: 8),
        Text(
          author['nickname']?.toString() ?? '未知用户',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildImagePreview(dynamic media) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[200],
      ),
      child: media['media_url'] != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                media['media_url'].toString(),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.broken_image);
                },
              ),
            )
          : const Icon(Icons.image),
    );
  }

  Widget _buildInteractionStats() {
    return Row(
      children: [
        const Icon(Icons.favorite_border, size: 16),
        const SizedBox(width: 4),
        Text((post['like_count'] ?? 0).toString()),
        const SizedBox(width: 16),
        const Icon(Icons.chat_bubble_outline, size: 16),
        const SizedBox(width: 4),
        Text((post['comment_count'] ?? 0).toString()),
        const SizedBox(width: 16),
        const Icon(Icons.bookmark_border, size: 16),
        const SizedBox(width: 4),
        Text((post['favorite_count'] ?? 0).toString()),
      ],
    );
  }
}
