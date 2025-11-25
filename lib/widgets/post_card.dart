import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iacg/widgets/avatar_widget.dart';
import '../features/post/post_detail_page.dart';

class PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool isLeftColumn; // 新增：标识是左列还是右列

  const PostCard({
    super.key,
    required this.post,
    this.isLeftColumn = true, // 默认左列
  });

  @override
  Widget build(BuildContext context) {
    // 原有的数据提取逻辑保持不变
    final int postId = (post['id'] as num).toInt();
    final String channel = (post['channel'] ?? 'cos') as String;
    final String title = (post['title'] ?? '') as String;
    final String content = (post['content'] ?? '') as String;
    final dynamic createdAtRaw = post['created_at'];

    Map<String, dynamic> author = <String, dynamic>{};
    final authorData = post['author'];
    if (authorData is Map) {
      author = Map<String, dynamic>.from(authorData);
    }

    final String authorName = (author['nickname'] ?? '佚名') as String;
    final String? authorAvatar = (author['avatar_url'] as String?)?.trim();

    final int likeCount = (post['like_count'] as num?)?.toInt() ?? 0;
    final int favCount = (post['favorite_count'] as num?)?.toInt() ?? 0;
    final int cmtCount = (post['comment_count'] as num?)?.toInt() ?? 0;
    final int viewCount = (post['view_count'] as num?)?.toInt() ?? 0;

    List<dynamic> medias = [];
    final mediasData = post['post_media'];
    if (mediasData is List) {
      medias = mediasData;
    }

    String? coverUrl;
    if (medias.isNotEmpty) {
      final firstMedia = medias.first;
      if (firstMedia is Map) {
        coverUrl = firstMedia['media_url'] as String?;
      }
    }

    final bool hasCover = (coverUrl != null && coverUrl.isNotEmpty);
    final String summary = _snippet(content, 20);

    return Container(
      // 修改：移除原有的底部间距，改为在父级控制
      margin: EdgeInsets.only(
        bottom: 16,
        left: isLeftColumn ? 8 : 4,   // 左列左边距大，右边距小
        right: isLeftColumn ? 4 : 8,  // 右列右边距大，左边距小
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PostDetailPage(postId: postId)),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 封面图片
              if (hasCover)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedNetworkImage(
                    imageUrl: coverUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey[100]),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[100],
                      alignment: Alignment.center,
                      child: Icon(Icons.broken_image_outlined, color: Colors.grey[400]),
                    ),
                  ),
                ),

              // 标题
              if (title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    maxLines: 2, // 改为2行，适应更长的标题
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // 正文摘要
              if (summary.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Text(
                    summary,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.4),
                    maxLines: 3, // 改为3行，显示更多内容
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              const SizedBox(height: 8),

              // 作者 + 时间 + 频道
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    AvatarWidget(
                      imageUrl: authorAvatar,
                      size: 32,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        authorName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(createdAtRaw),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 8),
                    _ChannelChip(channel: channel),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // 互动栏
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Row(
                  children: [
                    _IconText(icon: Icons.favorite_border, text: _k(likeCount)),
                    const SizedBox(width: 12),
                    _IconText(icon: Icons.bookmark_border, text: _k(favCount)),
                    const SizedBox(width: 12),
                    _IconText(icon: Icons.mode_comment_outlined, text: _k(cmtCount)),
                    const Spacer(),
                    _IconText(icon: Icons.visibility_outlined, text: _k(viewCount)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 原有的工具方法保持不变
  String _snippet(String raw, int n) {
    final s = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) return '';
    if (s.length <= n) return s;
    return '${s.substring(0, n)}…';
  }

  String _formatTime(dynamic createdAtRaw) {
    if (createdAtRaw == null) return '';
    DateTime? dt;
    if (createdAtRaw is String) {
      dt = DateTime.tryParse(createdAtRaw);
    } else if (createdAtRaw is DateTime) {
      dt = createdAtRaw;
    }
    if (dt == null) return '';

    final y = dt.year;
    final m = _two(dt.month);
    final d = _two(dt.day);
    final hh = _two(dt.hour);
    final mm = _two(dt.minute);
    return '$y-$m-$d $hh:$mm';
  }

  String _two(int v) => v < 10 ? '0$v' : '$v';

  String _k(int n) {
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(n % 10000 == 0 ? 0 : 1)}w';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
    return n.toString();
  }
}

// 原有的 _IconText 和 _ChannelChip 类保持不变
class _IconText extends StatelessWidget {
  final IconData icon;
  final String text;
  const _IconText({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[700]),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }
}

class _ChannelChip extends StatelessWidget {
  final String channel;
  const _ChannelChip({required this.channel});
  @override
  Widget build(BuildContext context) {
    final isCos = channel == 'cos';
    final isEvent = channel == 'event'; // ✅ 新增：活动判断
    Color getColor() {
      if (isCos) return Colors.deepPurple;
      if (isEvent) return Colors.orange; // ✅ 新增：活动用橙色
      return Colors.blueGrey;
    }
        String getLabel() {
      if (isCos) return 'COS';
      if (isEvent) return '活动'; // ✅ 新增：活动标签
      return '群岛';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: getColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: getColor().withOpacity(0.25)),
      ),
      child: Text(
        getLabel(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: getColor(),
        ),
      ),
    );
  // @override
  // Widget build(BuildContext context) {
  //   final isCos = channel == 'cos';
  //   return Container(
  //     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  //     decoration: BoxDecoration(
  //       color: (isCos ? Colors.deepPurple : Colors.blueGrey).withOpacity(0.1),
  //       borderRadius: BorderRadius.circular(999),
  //       border: Border.all(color: (isCos ? Colors.deepPurple : Colors.blueGrey).withOpacity(0.25)),
  //     ),
  //     child: Text(
  //       isCos ? 'COS' : '群岛',
  //       style: TextStyle(
  //         fontSize: 11,
  //         fontWeight: FontWeight.w600,
  //         color: isCos ? Colors.deepPurple : Colors.blueGrey,
  //       ),
  //     ),
  //   );
  }
}