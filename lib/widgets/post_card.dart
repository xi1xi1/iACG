import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iacg/widgets/avatar_widget.dart';
import '../features/post/post_detail_page.dart';

// 二次元风格颜色定义
class AnimeColors {
  static const Color primaryPink = Color(0xFFEC719A); // 粉色
  static const Color secondaryPurple = Color(0xFF8B5CF6); // 紫色
  static const Color accentCyan = Color(0xFF06B6D4); // 青色
  static const Color backgroundLight = Color(0xFFF8FAFC); // 浅灰背景
  static const Color textDark = Color(0xFF1F2937); // 深色文字
  static const Color textLight = Color(0xFF6B7280); // 浅色文字
  static const Color cardWhite = Color(0xFFFFFFFF); // 卡片白色
  static const Color gradientStart = Color(0xFFEC4899); // 渐变开始
  static const Color gradientEnd = Color(0xFF8B5CF6); // 渐变结束
}

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

    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据屏幕宽度动态调整布局
        final screenWidth = constraints.maxWidth;
        final isNarrowScreen = screenWidth < 360; // 窄屏幕判断
        
        return Container(
          margin: EdgeInsets.only(
            bottom: 8,
            left: isLeftColumn ? 4 : 2,
            right: isLeftColumn ? 2 : 4,
          ),
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PostDetailPage(postId: postId)),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              constraints: BoxConstraints(
                minHeight: 0, // 允许内容收缩
                maxHeight: double.infinity,
              ),
              decoration: BoxDecoration(
                color: AnimeColors.cardWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.1),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, // 重要：允许内容收缩
                children: [
                  // 封面图片 - 自适应比例
                  if (hasCover)
                    _buildAdaptiveImage(coverUrl!),

                  // 内容区域
                  Padding(
                    padding: EdgeInsets.all(isNarrowScreen ? 12 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min, // 重要：允许内容收缩
                      children: [
                        // 标题
                        if (title.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: isNarrowScreen ? 14 : 16,
                                fontWeight: FontWeight.bold,
                                color: AnimeColors.textDark,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                        // 正文摘要
                        if (summary.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              summary,
                              style: TextStyle(
                                fontSize: isNarrowScreen ? 12 : 14,
                                color: AnimeColors.textLight,
                                height: 1.4,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                        // 作者信息行
                        Row(
                          children: [
                            AvatarWidget(
                              imageUrl: authorAvatar,
                              size: isNarrowScreen ? 16 : 18,
                            ),
                            SizedBox(width: isNarrowScreen ? 6 : 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    authorName,
                                    style: TextStyle(
                                      fontSize: isNarrowScreen ? 11 : 12,
                                      fontWeight: FontWeight.w600,
                                      color: AnimeColors.textDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 1),
                                ],
                              ),
                            ),
                            _ChannelChip(channel: channel, isNarrowScreen: isNarrowScreen),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // 互动栏 - 自适应布局
                        _buildAdaptiveInteractionBar(
                          likeCount: likeCount,
                          favCount: favCount,
                          cmtCount: cmtCount,
                          viewCount: viewCount,
                          isNarrowScreen: isNarrowScreen,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 自适应图片组件
  Widget _buildAdaptiveImage(String imageUrl) {
    return FutureBuilder<ImageInfo>(
      future: _getImageInfo(imageUrl),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          final imageInfo = snapshot.data!;
          final width = imageInfo.image.width.toDouble();
          final height = imageInfo.image.height.toDouble();
          final aspectRatio = width / height;
          
          // 限制宽高比范围，避免极端比例
          final clampedAspectRatio = aspectRatio.clamp(0.5, 2.0);
          
          return AspectRatio(
            aspectRatio: clampedAspectRatio,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => _buildImagePlaceholder(),
              errorWidget: (context, url, error) => _buildImageError(),
            ),
          );
        }
        
        // 加载中或出错时使用默认比例
        return AspectRatio(
          aspectRatio: 3/4,
          child: _buildImagePlaceholder(),
        );
      },
    );
  }

  // 获取图片信息
  Future<ImageInfo> _getImageInfo(String imageUrl) async {
    final completer = Completer<ImageInfo>();
    final imageProvider = CachedNetworkImageProvider(imageUrl);
    
    imageProvider.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        completer.complete(info);
      }),
    );
    
    return completer.future;
  }

  // 图片占位符
  Widget _buildImagePlaceholder() {
    return Container(
      color: AnimeColors.backgroundLight,
      child: Center(
        child: Icon(
          Icons.photo_library_outlined,
          size: 40,
          color: AnimeColors.textLight.withOpacity(0.5),
        ),
      ),
    );
  }

  // 图片错误占位符
  Widget _buildImageError() {
    return Container(
      color: AnimeColors.backgroundLight,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: 40,
          color: AnimeColors.textLight.withOpacity(0.5),
        ),
      ),
    );
  }

  // 自适应互动栏
  Widget _buildAdaptiveInteractionBar({
    required int likeCount,
    required int favCount,
    required int cmtCount,
    required int viewCount,
    required bool isNarrowScreen,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(1, 0, 12, 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CompactIconText(
            icon: Icons.favorite_border, 
            text: _k(likeCount),
            isNarrowScreen: isNarrowScreen,
          ),
          SizedBox(width: isNarrowScreen ? 3 : 5),
          _CompactIconText(
            icon: Icons.bookmark_border, 
            text: _k(favCount),
            isNarrowScreen: isNarrowScreen,
          ),
          SizedBox(width: isNarrowScreen ? 3 : 5),
          _CompactIconText(
            icon: Icons.mode_comment_outlined, 
            text: _k(cmtCount),
            isNarrowScreen: isNarrowScreen,
          ),
          SizedBox(width: isNarrowScreen ? 3 : 5),
          _CompactIconText(
            icon: Icons.visibility_outlined, 
            text: _k(viewCount),
            isNarrowScreen: isNarrowScreen,
          ),
        ],
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
// 二次元风格图标文本组件
class _AnimeIconText extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _AnimeIconText({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// 新的紧凑图标文本组件
class _CompactIconText extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isNarrowScreen;
  const _CompactIconText({
    required this.icon, 
    required this.text,
    this.isNarrowScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min, // 重要：避免占用过多空间
      children: [
        Icon(
          icon, 
          size: isNarrowScreen ? 14 : 16, 
          color: Colors.grey[700]
        ),
        SizedBox(width: isNarrowScreen ? 2 : 4),
        Text(
          text,
          style: TextStyle(
            fontSize: isNarrowScreen ? 10 : 11, 
            color: Colors.grey[700]
          ),
        ),
      ],
    );
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

// 调整频道芯片大小
class _ChannelChip extends StatelessWidget {
  final String channel;
  final bool isNarrowScreen;
  const _ChannelChip({
    required this.channel,
    this.isNarrowScreen = false,
  });

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
      padding: EdgeInsets.symmetric(
        horizontal: isNarrowScreen ? 4 : 6, 
        vertical: isNarrowScreen ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: getColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: getColor().withOpacity(0.25)),
      ),
      child: Text(
        getLabel(),
        style: TextStyle(
          fontSize: isNarrowScreen ? 8 : 10,
          fontWeight: FontWeight.w600,
          color: getColor(),
        ),
      ),
    );
  }
}
