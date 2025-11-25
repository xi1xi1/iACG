// import 'package:flutter/material.dart';
// import 'package:cached_network_image/cached_network_image.dart';

// class AvatarWidget extends StatelessWidget {
//   final String? imageUrl;
//   final double size;
//   final VoidCallback? onTap;
//   final bool showBorder;

//   const AvatarWidget({
//     super.key,
//     this.imageUrl,
//     this.size = 40,
//     this.onTap,
//     this.showBorder = false,
//   });
//   Widget buildAvatar(String? rawUrl, {double radius = 20}) {
//     final url = rawUrl?.trim();
//     final valid = (url != null && url.isNotEmpty && Uri.tryParse(url)?.hasAbsolutePath == true);

//     return CircleAvatar(
//       radius: radius,
//       backgroundColor: Colors.grey[200],
//       // 用 foregroundImage：加载成功就显示图片；失败则显示 child
//       foregroundImage: valid ? NetworkImage(url!) : null,
//       // 只有没有有效头像时才显示占位
//       child: valid
//           ? null
//           : const Icon(Icons.person, color: Colors.grey),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         width: size,
//         height: size,
//         decoration: showBorder
//             ? BoxDecoration(
//                 shape: BoxShape.circle,
//                 border: Border.all(
//                   color: Theme.of(context).colorScheme.primary,
//                   width: 2,
//                 ),
//               )
//             : null,
//         child: ClipOval(
//           child: imageUrl != null && imageUrl!.isNotEmpty
//               ? CachedNetworkImage(
//                   imageUrl: imageUrl!,
//                   fit: BoxFit.cover,
//                   placeholder: (context, url) => Container(
//                     color: Colors.grey[300],
//                     child: const Icon(Icons.person, color: Colors.grey),
//                   ),
//                   errorWidget: (context, url, error) => Container(
//                     color: Colors.grey[300],
//                     child: const Icon(Icons.person, color: Colors.grey),
//                   ),
//                 )
//               : Container(
//                   color: Colors.grey[300],
//                   child: Icon(
//                     Icons.person,
//                     size: size * 0.6,
//                     color: Colors.grey[600],
//                   ),
//                 ),
//         ),
//       ),
//     );
//   }
// }
// lib/widgets/avatar_widget.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AvatarWidget extends StatelessWidget {
  /// 头像图片的网络地址（为空或非法时显示本地默认图）
  final String? imageUrl;

  /// 外层正方形尺寸（宽=高），圆头像半径= size / 2
  final double size;

  /// 点击事件（可选）
  final VoidCallback? onTap;

  /// 是否显示一圈主题色描边
  final bool showBorder;

  /// 无障碍可读名称（可选）
  final String? semanticsLabel;

  const AvatarWidget({
    super.key,
    this.imageUrl,
    this.size = 40,
    this.onTap,
    this.showBorder = false,
    this.semanticsLabel,
  });

  bool _isValidUrl(String? url) {
    final u = url?.trim();
    if (u == null || u.isEmpty) return false;
    final parsed = Uri.tryParse(u);
    // 仅当是完整的 http/https 绝对地址时视为有效
    return parsed != null && parsed.hasScheme && parsed.hasAuthority;
  }

  @override
  Widget build(BuildContext context) {
    final double radius = size / 2;

    // 背景图：本地默认头像（当前景加载失败或无前景时作为兜底）
    const ImageProvider<Object> bgProvider =
        AssetImage('assets/images/default_avatar.PNG');

    // 前景图：只有当 URL 合法时才尝试加载网络图（加载失败会自动回退到 backgroundImage）
    final ImageProvider<Object>? fgProvider = _isValidUrl(imageUrl)
        ? CachedNetworkImageProvider(imageUrl!.trim())
        : null;

    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[200],
      backgroundImage: bgProvider, // ✅ 兜底：本地默认头像
      foregroundImage: fgProvider,  // ✅ 成功时覆盖显示网络头像；失败则回退到 backgroundImage
      child: null, // 不再叠加人形占位，避免“黑色人影”叠加
    );

    final wrapped = Container(
      width: size,
      height: size,
      decoration: showBorder
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            )
          : null,
      child: avatar,
    );

    final tappable = onTap == null
        ? wrapped
        : GestureDetector(onTap: onTap, child: wrapped);

    return Semantics(
      label: semanticsLabel ?? 'avatar',
      button: onTap != null,
      child: tappable,
    );
  }
}
