import 'package:flutter/material.dart';
import 'package:iacg/features/post/post_detail_page.dart';
import 'package:iacg/services/post_service.dart';
import 'package:iacg/widgets/avatar_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RepostComposePage extends StatefulWidget {
  final Map<String, dynamic> originalPost;
  
  const RepostComposePage({
    super.key,
    required this.originalPost,
  });

  @override
  State<RepostComposePage> createState() => _RepostComposePageState();
}

class _RepostComposePageState extends State<RepostComposePage> {
  final _formKey = GlobalKey<FormState>();
  final _postService = PostService();
  final _client = Supabase.instance.client;

  final _contentCtrl = TextEditingController();
  bool _publishing = false;

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }


Future<void> _publishRepost() async {
  final user = _client.auth.currentUser;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先登录')));
    return;
  }

  setState(() => _publishing = true);

  try {
    final original = widget.originalPost;
    final originalId = original['id'] as int;
    
    // 使用专用转发方法
    final repostId = await _postService.createRepost(
      authorId: user.id,
      originalPostId: originalId,
      comment: _contentCtrl.text.trim().isNotEmpty ? _contentCtrl.text.trim() : null,
      postCommentToOriginal: true, // 在原帖发评论
    );

    if (!mounted) return;

    // 成功后跳转到转发帖子的详情页
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => PostDetailPage(postId: repostId)),
    );

  } catch (e) {
    print('转发失败: $e');
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('转发失败：$e')),
    );
  } finally {
    if (mounted) setState(() => _publishing = false);
  }
}
  // Future<void> _publishRepost() async {
  //   final user = _client.auth.currentUser;
  //   if (user == null) {
  //     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先登录')));
  //     return;
  //   }

  //   setState(() => _publishing = true);

  //   try {
  //     final original = widget.originalPost;
  //     final originalId = original['id'] as int;
      
  //     // 使用专用转发方法
  //     final repostId = await _postService.createRepost(
  //       authorId: user.id,
  //       originalPostId: originalId,
  //       comment: _contentCtrl.text.trim().isNotEmpty ? _contentCtrl.text.trim() : null,
  //     );

  //     if (!mounted) return;

  //     // 成功后跳转到转发帖子的详情页
  //     Navigator.of(context).pushReplacement(
  //       MaterialPageRoute(builder: (_) => PostDetailPage(postId: repostId)),
  //     );

  //   } catch (e) {
  //     print('转发失败: $e');
  //     if (!mounted) return;
      
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('转发失败：$e')),
  //     );
  //   } finally {
  //     if (mounted) setState(() => _publishing = false);
  //   }
  // }
// 仅转发（不在原帖发评论）
Future<void> _repostOnly() async {
  final user = _client.auth.currentUser;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先登录')));
    return;
  }

  setState(() => _publishing = true);

  try {
    final original = widget.originalPost;
    final originalId = original['id'] as int;
    
    // 使用快速转发方法
    final repostId = await _postService.createQuickRepost(
      authorId: user.id,
      originalPostId: originalId,
      comment: _contentCtrl.text.trim().isNotEmpty ? _contentCtrl.text.trim() : null,
    );

    if (!mounted) return;

    Navigator.of(context).pop(true); // 返回成功信号

  } catch (e) {
    print('仅转发失败: $e');
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('转发失败：$e')),
    );
  } finally {
    if (mounted) setState(() => _publishing = false);
  }
}
  // // 仅转发（不带评论）
  // Future<void> _repostOnly() async {
  //   final user = _client.auth.currentUser;
  //   if (user == null) {
  //     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先登录')));
  //     return;
  //   }

  //   setState(() => _publishing = true);

  //   try {
  //     final original = widget.originalPost;
  //     final originalId = original['id'] as int;
      
  //     // 使用快速转发方法
  //     final repostId = await _postService.createQuickRepost(
  //       authorId: user.id,
  //       originalPostId: originalId,
  //     );

  //     if (!mounted) return;

  //     Navigator.of(context).pop(true); // 返回成功信号

  //   } catch (e) {
  //     print('仅转发失败: $e');
  //     if (!mounted) return;
      
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('转发失败：$e')),
  //     );
  //   } finally {
  //     if (mounted) setState(() => _publishing = false);
  //   }
  // }

  // // 构建预览内容
  // String _buildPreviewContent() {
  //   final original = widget.originalPost;
  //   final author = original['author'] ?? {};
  //   final authorName = author['nickname'] ?? '佚名';
  //   final originalContent = original['content'] ?? '';
  //   final originalTitle = original['title'] ?? '';

  //   String content = '';
  //   if (_contentCtrl.text.trim().isNotEmpty) {
  //     content += '${_contentCtrl.text.trim()}\n\n';
  //   }
  //   content += '//@$authorName：';
  //   if (originalTitle.isNotEmpty) {
  //     content += '$originalTitle';
  //   }
  //   if (originalContent.isNotEmpty) {
  //     if (originalTitle.isNotEmpty) content += ' - ';
  //     content += originalContent;
  //   }

  //   return content.trim();
  // }

  // 构建预览内容（显示转发链）
String _buildPreviewContent() {
  final original = widget.originalPost;
  final currentUser = _client.auth.currentUser;
  final currentUserName = currentUser?.email?.split('@').first ?? '我';
  
  final originalAuthor = original['author'] ?? {};
  final originalAuthorName = originalAuthor['nickname'] ?? '佚名';
  final originalContent = original['content'] ?? '';
  final originalTitle = original['title'] ?? '';

  String content = '';
  if (_contentCtrl.text.trim().isNotEmpty) {
    content += '${_contentCtrl.text.trim()}\n\n';
  }
  
  // 检查是否是转发链
  final originalPostIsRepost = original['original_post_id'] != null;
  
  if (originalPostIsRepost && originalContent.isNotEmpty) {
    // 如果原帖已经是转发帖，继续构建转发链
    content += originalContent.replaceFirst(RegExp(r'^'), '//@$currentUserName：');
  } else {
    // 如果是原始帖子，新建转发链
    content += '//@$currentUserName：';
    if (originalTitle.isNotEmpty) {
      content += '$originalTitle';
    }
    if (originalContent.isNotEmpty) {
      if (originalTitle.isNotEmpty) content += ' - ';
      content += originalContent;
    }
  }

  return content.trim();
}

  // @override
  // Widget build(BuildContext context) {
  //   final original = widget.originalPost;
  //   final author = original['author'] ?? {};
  //   final authorName = author['nickname'] ?? '佚名';
  //   final originalContent = original['content'] ?? '';
  //   final originalTitle = original['title'] ?? '';
  //   final originalMedia = (original['post_media'] as List? ?? [])
  //     ..sort((a, b) => (a['sort_order'] ?? 0).compareTo(b['sort_order'] ?? 0));

  //   return Scaffold(
  //     appBar: AppBar(
  //       title: const Text('转发'),
  //       actions: [
  //         // 仅转发按钮
  //         TextButton(
  //           onPressed: _publishing ? null : _repostOnly,
  //           child: _publishing
  //               ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
  //               : const Text('转发'),
  //         ),
  //         const SizedBox(width: 8),
  //         // 发布按钮（转发并评论）
  //         TextButton(
  //           onPressed: _publishing ? null : _publishRepost,
  //           child: _publishing
  //               ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
  //               : const Text('发布'),
  //         ),
  //       ],
  //     ),
  //     body: Form(
  //       key: _formKey,
  //       child: ListView(
  //         padding: const EdgeInsets.all(16),
  //         children: [
  //           // 评论输入
  //           Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               const Text('添加评论（可选）', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
  //               const SizedBox(height: 8),
  //               TextFormField(
  //                 controller: _contentCtrl,
  //                 minLines: 3,
  //                 maxLines: 6,
  //                 decoration: const InputDecoration(
  //                   hintText: '说点什么...',
  //                   border: OutlineInputBorder(),
  //                 ),
  //                 onChanged: (value) {
  //                   setState(() {}); // 刷新预览
  //                 },
  //               ),
  //               const SizedBox(height: 16),
  //             ],
  //           ),

  //           // 原帖预览
  //           Card(
  //             color: Colors.grey[50],
  //             child: Padding(
  //               padding: const EdgeInsets.all(12),
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   // 原作者信息
  //                   Row(
  //                     children: [
  //                       AvatarWidget(
  //                         imageUrl: author['avatar_url'] as String?,
  //                         size: 32,
  //                       ),
  //                       const SizedBox(width: 8),
  //                       Text(authorName, style: const TextStyle(fontWeight: FontWeight.w600)),
  //                     ],
  //                   ),
  //                   const SizedBox(height: 8),

  //                   // 原帖标题和内容
  //                   if (originalTitle.isNotEmpty)
  //                     Text(originalTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
  //                   if (originalContent.isNotEmpty) ...[
  //                     if (originalTitle.isNotEmpty) const SizedBox(height: 4),
  //                     Text(originalContent),
  //                   ],

  //                   // 原帖媒体预览（只显示第一张）
  //                   if (originalMedia.isNotEmpty)
  //                     Padding(
  //                       padding: const EdgeInsets.only(top: 8),
  //                       child: ClipRRect(
  //                         borderRadius: BorderRadius.circular(8),
  //                         child: Image.network(
  //                           originalMedia.first['media_url'] as String,
  //                           width: double.infinity,
  //                           height: 200,
  //                           fit: BoxFit.cover,
  //                           errorBuilder: (context, error, stackTrace) {
  //                             return Container(
  //                               width: double.infinity,
  //                               height: 200,
  //                               color: Colors.grey[200],
  //                               child: const Icon(Icons.broken_image, color: Colors.grey),
  //                             );
  //                           },
  //                         ),
  //                       ),
  //                     ),

  //                   // 原帖标签
  //                   if (original['post_tags'] != null && (original['post_tags'] as List).isNotEmpty)
  //                     Padding(
  //                       padding: const EdgeInsets.only(top: 8),
  //                       child: Wrap(
  //                         spacing: 4,
  //                         children: (original['post_tags'] as List).take(3).map((t) {
  //                           final name = t['tag']?['name'] ?? '';
  //                           return name.isNotEmpty 
  //                               ? Chip(
  //                                   label: Text('#$name', style: const TextStyle(fontSize: 12)),
  //                                   materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  //                                   visualDensity: VisualDensity.compact,
  //                                 )
  //                               : const SizedBox.shrink();
  //                         }).toList(),
  //                       ),
  //                     ),
  //                 ],
  //               ),
  //             ),
  //           ),

  //           const SizedBox(height: 16),

  //           // 预览区域（只有在有评论内容时才显示）
  //           if (_contentCtrl.text.trim().isNotEmpty)
  //             Card(
  //               child: Padding(
  //                 padding: const EdgeInsets.all(12),
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     const Text('预览', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
  //                     const SizedBox(height: 8),
  //                     Text(_buildPreviewContent()),
  //                   ],
  //                 ),
  //               ),
  //             ),

  //           const SizedBox(height: 20),

  //           // 操作说明
  //           Container(
  //             padding: const EdgeInsets.all(12),
  //             decoration: BoxDecoration(
  //               color: Colors.blue[50],
  //               borderRadius: BorderRadius.circular(8),
  //             ),
  //             child: const Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 Text('转发说明', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
  //                 SizedBox(height: 4),
  //                 Text(
  //                   '• 点击"转发"：直接转发原帖\n'
  //                   '• 点击"发布"：添加评论后转发\n'
  //                   '• 转发内容会显示在群岛频道',
  //                   style: TextStyle(fontSize: 12, color: Colors.blueGrey),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  @override
Widget build(BuildContext context) {
  final original = widget.originalPost;
  final author = original['author'] ?? {};
  final authorName = author['nickname'] ?? '佚名';
  final originalContent = original['content'] ?? '';
  final originalTitle = original['title'] ?? '';
  final originalMedia = (original['post_media'] as List? ?? [])
    ..sort((a, b) => (a['sort_order'] ?? 0).compareTo(b['sort_order'] ?? 0));

  return Scaffold(
    appBar: AppBar(
      title: const Text('转发'),
      actions: [
        TextButton(
          onPressed: _publishing ? null : _repostOnly,
          child: _publishing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('转发'),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: _publishing ? null : _publishRepost,
          child: _publishing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('发布'),
        ),
      ],
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 转发内容输入（在上面）
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('转发内容', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _contentCtrl,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: '说点什么...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {}); // 刷新预览
                },
              ),
              const SizedBox(height: 16),
            ],
          ),

          // 预览区域（只有在有评论内容时才显示）
          if (_contentCtrl.text.trim().isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('预览', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text(_buildPreviewContent()),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // 原帖预览（在下面，可点击跳转）
          const Text('原帖', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              // 跳转到原帖详情页
              final originalId = original['id'] as int;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PostDetailPage(postId: originalId),
                ),
              );
            },
            child: Card(
              color: Colors.grey[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 原作者信息
                    Row(
                      children: [
                        AvatarWidget(
                          imageUrl: author['avatar_url'] as String?,
                          size: 32,
                        ),
                        const SizedBox(width: 8),
                        Text(authorName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 原帖标题和内容
                    if (originalTitle.isNotEmpty)
                      Text(originalTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (originalContent.isNotEmpty) ...[
                      if (originalTitle.isNotEmpty) const SizedBox(height: 4),
                      Text(originalContent),
                    ],

                    // 原帖媒体预览（只显示第一张）
                    if (originalMedia.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            originalMedia.first['media_url'] as String,
                            width: double.infinity,
                            height: 150,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: double.infinity,
                                height: 150,
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image, color: Colors.grey),
                              );
                            },
                          ),
                        ),
                      ),

                    // 原帖标签
                    if (original['post_tags'] != null && (original['post_tags'] as List).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 4,
                          children: (original['post_tags'] as List).take(3).map((t) {
                            final name = t['tag']?['name'] ?? '';
                            return name.isNotEmpty 
                                ? Chip(
                                    label: Text('#$name', style: const TextStyle(fontSize: 12)),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  )
                                : const SizedBox.shrink();
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 操作说明
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('转发说明', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text(
                  '• 点击"转发"：直接转发原帖\n'
                  '• 点击"发布"：添加评论后转发\n'
                  '• 多次转发会形成转发链\n'
                  '• 点击原帖可查看详情',
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey),
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