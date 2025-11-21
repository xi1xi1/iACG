
// import 'dart:io';
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:iacg/features/post/post_detail_page.dart';
// import 'package:iacg/services/post_service.dart';
// import 'package:iacg/services/tag_service.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

// class PostComposePage extends StatefulWidget {
//   const PostComposePage({super.key});

//   @override
//   State<PostComposePage> createState() => _PostComposePageState();
// }

// class _PostComposePageState extends State<PostComposePage> {
//   final _formKey = GlobalKey<FormState>();
//   final _postService = PostService();

//   String _channel = 'cos'; // cos | island
//   final _titleCtrl = TextEditingController();
//   final _contentCtrl = TextEditingController();

//   // COS only
//   String? _cosCategory; // anime/game/comic/novel/other
//   final _cosCategories = const ['anime', 'game', 'comic', 'novel', 'other'];

//   // Island only
//   String? _islandType; // 自定：'求助' 等
//   final _islandTypes = const ['求助', '分享', '吐槽', '找搭子', '约拍', '其他'];

//   // 标签（先用简单文本，用逗号分隔）
//   final _tagsCtrl = TextEditingController(); // 例如：原神,崩坏:星穹铁道

//   // 选中的本地图片
//   final List<File> _pickedImages = [];
//   final List<Uint8List> _pickedImageBytes = []; // 用于预览

//   bool _publishing = false;

//   @override
//   void dispose() {
//     _titleCtrl.dispose();
//     _contentCtrl.dispose();
//     _tagsCtrl.dispose();
//     super.dispose();
//   }

//   Future<void> _pickImages() async {
//     final picker = ImagePicker();
//     final files = await picker.pickMultiImage(imageQuality: 92);
//     if (files.isEmpty) return;
    
//     for (final xfile in files) {
//       final bytes = await xfile.readAsBytes();
//       setState(() {
//         _pickedImages.add(File(xfile.path));
//         _pickedImageBytes.add(bytes);
//       });
//     }
//   }

//   Future<void> _publish() async {
//     if (!(_formKey.currentState?.validate() ?? false)) return;

//     final user = Supabase.instance.client.auth.currentUser;
//     if (user == null) {
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先登录')));
//       return;
//     }

//     setState(() => _publishing = true);

//     int? postId; // 修改：改为 int? 类型

//     try {
//       // 1) 创建帖子
//       postId = await _postService.createPost(
//         authorId: user.id,
//         channel: _channel,
//         title: _titleCtrl.text.trim(),
//         content: _contentCtrl.text.trim().isEmpty ? null : _contentCtrl.text.trim(),
//         mainCategory: _channel == 'cos' ? _cosCategory : null,
//         islandType: _channel == 'island' ? _islandType : null,
//       );

//       print('帖子创建成功，ID: $postId');

//       // 2) 上传图片并绑定 post_media
//       if (_pickedImages.isNotEmpty) {
//         print('开始上传 ${_pickedImages.length} 张图片');
//         final mediaEntries = <Map<String, String>>[];
//         for (int i = 0; i < _pickedImages.length; i++) {
//           final file = _pickedImages[i];
//           print('上传第 ${i + 1} 张图片: ${file.path}');
//           try {
//             // 使用 XFile 上传，保持原有 File 对象不变
//             final xFile = XFile(file.path);
//             final url = await _postService.uploadMediaFile(
//               postId: postId, 
//               xFile: xFile, // 使用 XFile 上传
//             );
//             mediaEntries.add({
//               'media_url': url,
//               'media_type': 'image',
//               'sort_order': '$i',
//             });
//             print('第 ${i + 1} 张图片上传成功: $url');
//           } catch (e) {
//             print('第 ${i + 1} 张图片上传失败: $e');
//             throw e;
//           }
//         }
//         if (mediaEntries.isNotEmpty) {
//           await _postService.attachMedia(postId, mediaEntries);
//           print('媒体附件关联成功');
//         }
//       }

//       // 3) 绑定标签（这里用简单做法：用你现有的 tags 表，先假设你已有 name->id 的方法；
//       // 没有的话可以先跳过 attachTags，等你有"选标签/建标签"的页面再接）
//       final raw = _tagsCtrl.text.trim();
//       if (raw.isNotEmpty) {
//         final names = raw.split(RegExp(r'[，,]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
//         // 你可以写一个 TagService.nameToId 批量拿到 tag_id，这里简化为全部跳过
//         final tagIds = await TagService().ensureTagsAndReturnIds(names);
//         await _postService.attachTags(postId, tagIds);
//       }

//       if (!mounted) return;

//       print('发布流程完成，跳转到详情页');
//       // 4) 成功后跳详情页 - 确保 postId 不为 null
//       if (postId != null) {
//         Navigator.of(context).pushReplacement(
//           MaterialPageRoute(builder: (_) => PostDetailPage(postId: postId!)),
//         );
//       } else {
//         throw Exception('帖子ID为空');
//       }
//     } catch (e, stackTrace) {
//       print('发布失败错误详情: $e');
//       print('堆栈跟踪: $stackTrace');
      
//       if (!mounted) return;
      
//       // 如果有帖子ID但其他步骤失败，显示更具体的错误信息
//       String errorMessage = '发布失败：$e';
//       if (postId != null) {
//         errorMessage = '帖子已创建，但媒体上传失败：$e\n帖子ID: $postId';
//       }
      
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(errorMessage),
//           duration: const Duration(seconds: 5),
//         ),
//       );
//     } finally {
//       if (mounted) setState(() => _publishing = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final isCos = _channel == 'cos';

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('发布帖子'),
//         actions: [
//           TextButton(
//             onPressed: _publishing ? null : _publish,
//             child: _publishing
//                 ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
//                 : const Text('发布'),
//           ),
//         ],
//       ),
//       body: Form(
//         key: _formKey,
//         child: ListView(
//           padding: const EdgeInsets.all(16),
//           children: [
//             // 渠道
//             Row(
//               children: [
//                 const Text('频道：'),
//                 const SizedBox(width: 8),
//                 ChoiceChip(
//                   label: const Text('COS'),
//                   selected: _channel == 'cos',
//                   onSelected: (v) => setState(() => _channel = 'cos'),
//                 ),
//                 const SizedBox(width: 8),
//                 ChoiceChip(
//                   label: const Text('群岛'),
//                   selected: _channel == 'island',
//                   onSelected: (v) => setState(() => _channel = 'island'),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 12),

//             // 标题
//             TextFormField(
//               controller: _titleCtrl,
//               decoration: const InputDecoration(labelText: '标题', border: OutlineInputBorder()),
//               validator: (v) => (v == null || v.trim().isEmpty) ? '请输入标题' : null,
//             ),
//             const SizedBox(height: 12),

//             // 正文
//             TextFormField(
//               controller: _contentCtrl,
//               minLines: 5,
//               maxLines: 10,
//               decoration: const InputDecoration(
//                 labelText: '正文（可选）',
//                 border: OutlineInputBorder(),
//               ),
//             ),
//             const SizedBox(height: 12),

//             // COS 分类 或 群岛类型
//             if (isCos)
//               DropdownButtonFormField<String>(
//                 value: _cosCategory,
//                 decoration: const InputDecoration(
//                   labelText: 'COS分类（必选）',
//                   border: OutlineInputBorder(),
//                 ),
//                 items: _cosCategories.map((c) {
//                   final label = {
//                     'anime': '动漫',
//                     'game': '游戏',
//                     'comic': '漫画',
//                     'novel': '小说',
//                     'other': '其他',
//                   }[c]!;
//                   return DropdownMenuItem(value: c, child: Text(label));
//                 }).toList(),
//                 validator: (v) => v == null ? '请选择分类' : null,
//                 onChanged: (v) => setState(() => _cosCategory = v),
//               )
//             else
//               DropdownButtonFormField<String>(
//                 value: _islandType,
//                 decoration: const InputDecoration(
//                   labelText: '群岛类型（必选）',
//                   border: OutlineInputBorder(),
//                 ),
//                 items: _islandTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
//                 validator: (v) => v == null ? '请选择类型' : null,
//                 onChanged: (v) => setState(() => _islandType = v),
//               ),
//             const SizedBox(height: 12),

//             // 标签（简化：手输）
//             TextField(
//               controller: _tagsCtrl,
//               decoration: const InputDecoration(
//                 labelText: '标签（用逗号分隔，可选）',
//                 hintText: '例：原神，崩铁',
//                 border: OutlineInputBorder(),
//               ),
//             ),
//             const SizedBox(height: 12),

//             // 选择图片按钮
//             Row(
//               children: [
//                 ElevatedButton.icon(
//                   onPressed: _pickImages,
//                   icon: const Icon(Icons.add_photo_alternate),
//                   label: const Text('选择图片'),
//                 ),
//                 const SizedBox(width: 12),
//                 Text('已选 ${_pickedImages.length} 张'),
//               ],
//             ),
//             const SizedBox(height: 8),

//             // 已选图片九宫格预览
//             if (_pickedImageBytes.isNotEmpty)
//               Wrap(
//                 spacing: 8,
//                 runSpacing: 8,
//                 children: _pickedImageBytes
//                     .asMap()
//                     .entries
//                     .map((e) => Stack(
//                           children: [
//                             ClipRRect(
//                               borderRadius: BorderRadius.circular(8),
//                               child: Image.memory(
//                                 e.value,
//                                 width: 100,
//                                 height: 100,
//                                 fit: BoxFit.cover,
//                               ),
//                             ),
//                             Positioned(
//                               right: 4,
//                               top: 4,
//                               child: InkWell(
//                                 onTap: () => setState(() {
//                                   _pickedImages.removeAt(e.key);
//                                   _pickedImageBytes.removeAt(e.key);
//                                 }),
//                                 child: Container(
//                                   decoration: BoxDecoration(
//                                     color: Colors.black54,
//                                     borderRadius: BorderRadius.circular(999),
//                                   ),
//                                   padding: const EdgeInsets.all(2),
//                                   child: const Icon(Icons.close, size: 16, color: Colors.white),
//                                 ),
//                               ),
//                             )
//                           ],
//                         ))
//                     .toList(),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:iacg/features/post/post_detail_page.dart';
import 'package:iacg/services/post_service.dart';
import 'package:iacg/services/tag_service.dart';
import 'package:iacg/services/search_service.dart';
import 'package:iacg/widgets/avatar_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostComposePage extends StatefulWidget {
  const PostComposePage({super.key});

  @override
  State<PostComposePage> createState() => _PostComposePageState();
}

class _PostComposePageState extends State<PostComposePage> {
  final _formKey = GlobalKey<FormState>();
  final _postService = PostService();
  final _tagService = TagService();
  final _searchService = SearchService();
  final _client = Supabase.instance.client;

  String _channel = 'cos'; // cos | island
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();

  // COS only
  String? _cosCategory; // anime/game/comic/novel/other
  final _cosCategories = const ['anime', 'game', 'comic', 'novel', 'other'];
  String? _ipTag; // IP标签
  final List<Map<String, dynamic>> _collaborators = []; // 共创者列表

  // Island only
  String? _islandType;
  final _islandTypes = const ['求助', '分享', '吐槽', '找搭子', '约拍', '其他'];

  // 标签
  final _tagsCtrl = TextEditingController();

  // 选中的本地图片
  final List<File> _pickedImages = [];
  final List<Uint8List> _pickedImageBytes = [];

  // 搜索相关
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;

  // 角色选项
  final _roles = const [
    {'value': 'photographer', 'label': '摄影'},
    {'value': 'makeup', 'label': '化妆'},
    {'value': 'costume', 'label': '服装/造型'},
    {'value': 'props', 'label': '道具'},
    {'value': 'retouch', 'label': '修图/后期'},
    {'value': 'other', 'label': '其他合作'},
  ];
 
  bool _publishing = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _tagsCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 92);
    if (files.isEmpty) return;
    
    for (final xfile in files) {
      final bytes = await xfile.readAsBytes();
      setState(() {
        _pickedImages.add(File(xfile.path));
        _pickedImageBytes.add(bytes);
      });
    }
  }

  // 搜索用户
  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _searching = true);
    try {
      final results = await _searchService.searchUsers(query);
      setState(() => _searchResults = results);
    } catch (e) {
      print('搜索用户失败: $e');
      setState(() => _searchResults = []);
    } finally {
      setState(() => _searching = false);
    }
  }

  // 添加共创者（带角色选择）
  void _addCollaborator(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择角色'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _roles.map((role) {
            return ListTile(
              title: Text(role['label'] ?? '其他合作'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _collaborators.add({
                    'user_id': user['id'],
                    'nickname': user['nickname'],
                    'avatar_url': user['avatar_url'],
                    'role': role['value'],
                    'role_label': role['label'],
                  });
                });
                _searchCtrl.clear();
                _searchResults = [];
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  // 移除共创者
  void _removeCollaborator(int index) {
    setState(() => _collaborators.removeAt(index));
  }

  Future<void> _publish() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final user = _client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先登录')));
      return;
    }

    setState(() => _publishing = true);
    int? postId;

    try {
      // 处理 IP 标签
      int? mainIpTagId;
      if (_ipTag != null && _ipTag!.trim().isNotEmpty) {
        final ipTagNames = [_ipTag!.trim()];
        final tagIds = await _tagService.ensureTagsAndReturnIds(ipTagNames);
        if (tagIds.isNotEmpty) {
          mainIpTagId = tagIds.first;
          // 同时添加到普通标签中
          if (_tagsCtrl.text.trim().isEmpty) {
            _tagsCtrl.text = _ipTag!;
          } else {
            _tagsCtrl.text = '${_tagsCtrl.text}, ${_ipTag!}';
          }
        }
      }

      // 1) 创建帖子
      postId = await _postService.createPost(
        authorId: user.id,
        channel: _channel,
        title: _titleCtrl.text.trim(),
        content: _contentCtrl.text.trim().isEmpty ? null : _contentCtrl.text.trim(),
        mainCategory: _channel == 'cos' ? _cosCategory : null,
        mainIpTagId: mainIpTagId,
        islandType: _channel == 'island' ? _islandType : null,
      );

      print('帖子创建成功，ID: $postId');

      // 2) 添加共创者
      if (_collaborators.isNotEmpty) {
        try {
          final collaboratorEntries = _collaborators.map((collab) => {
            'post_id': postId,
            'user_id': collab['user_id'],
            'role': collab['role'],
            'display_name': null, // 留空，用用户名显示
          }).toList();
          
          await _client.from('post_collaborators').insert(collaboratorEntries);
          print('添加了 ${_collaborators.length} 个共创者');
        } catch (e) {
          print('添加共创者失败: $e');
          // 不阻断发布流程
        }
      }

      // 3) 上传图片并绑定 post_media
      if (_pickedImages.isNotEmpty) {
        print('开始上传 ${_pickedImages.length} 张图片');
        final mediaEntries = <Map<String, String>>[];
        for (int i = 0; i < _pickedImages.length; i++) {
          final file = _pickedImages[i];
          print('上传第 ${i + 1} 张图片: ${file.path}');
          try {
            final xFile = XFile(file.path);
            final url = await _postService.uploadMediaFile(
              postId: postId!, 
              xFile: xFile,
            );
            mediaEntries.add({
              'media_url': url,
              'media_type': 'image',
              'sort_order': '$i',
            });
            print('第 ${i + 1} 张图片上传成功: $url');
          } catch (e) {
            print('第 ${i + 1} 张图片上传失败: $e');
            throw e;
          }
        }
        if (mediaEntries.isNotEmpty) {
          await _postService.attachMedia(postId!, mediaEntries);
          print('媒体附件关联成功');
        }
      }

      // 4) 绑定标签
      final raw = _tagsCtrl.text.trim();
      if (raw.isNotEmpty) {
        final names = raw.split(RegExp(r'[，,]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        try {
          final tagIds = await _tagService.ensureTagsAndReturnIds(names);
          if (tagIds.isNotEmpty) {
            await _postService.attachTags(postId!, tagIds);
            print('成功添加 ${tagIds.length} 个标签: $names');
          }
        } catch (e) {
          print('标签处理失败: $e');
          // 不抛出异常，让帖子发布继续
        }
      }

      if (!mounted) return;

      print('发布流程完成，跳转到详情页');
      // 5) 成功后跳详情页
      if (postId != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => PostDetailPage(postId: postId!)),
        );
      } else {
        throw Exception('帖子ID为空');
      }
    } catch (e, stackTrace) {
      print('发布失败错误详情: $e');
      print('堆栈跟踪: $stackTrace');
      
      if (!mounted) return;
      
      String errorMessage = '发布失败：$e';
      if (postId != null) {
        errorMessage = '帖子已创建，但后续处理失败：$e\n帖子ID: $postId';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCos = _channel == 'cos';

    return Scaffold(
      appBar: AppBar(
        title: const Text('发布帖子'),
        actions: [
          TextButton(
            onPressed: _publishing ? null : _publish,
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
            // 渠道
            Row(
              children: [
                const Text('频道：'),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('COS'),
                  selected: _channel == 'cos',
                  onSelected: (v) => setState(() => _channel = 'cos'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('群岛'),
                  selected: _channel == 'island',
                  onSelected: (v) => setState(() => _channel = 'island'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 标题
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: '标题', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? '请输入标题' : null,
            ),
            const SizedBox(height: 12),

            // 正文
            TextFormField(
              controller: _contentCtrl,
              minLines: 5,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: '正文（可选）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // COS 分类 或 群岛类型
            if (isCos)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // COS分类
                  DropdownButtonFormField<String>(
                    value: _cosCategory,
                    decoration: const InputDecoration(
                      labelText: 'COS分类（必选）',
                      border: OutlineInputBorder(),
                    ),
                    items: _cosCategories.map((c) {
                      final label = {
                        'anime': '动漫',
                        'game': '游戏',
                        'comic': '漫画',
                        'novel': '小说',
                        'other': '其他',
                      }[c]!;
                      return DropdownMenuItem(value: c, child: Text(label));
                    }).toList(),
                    validator: (v) => v == null ? '请选择分类' : null,
                    onChanged: (v) => setState(() => _cosCategory = v),
                  ),
                  const SizedBox(height: 12),

                  // IP标签
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'IP标签（可选）',
                      hintText: '例如：原神、崩坏：星穹铁道',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _ipTag = v),
                  ),
                  const SizedBox(height: 12),

                  // 共创者
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('共创者（可选）', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: '搜索用户名添加共创者...',
                          border: const OutlineInputBorder(),
                          suffixIcon: _searching
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : null,
                        ),
                        onChanged: _searchUsers,
                      ),
                      if (_searchResults.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final user = _searchResults[index];
                              return ListTile(
                                leading: AvatarWidget(
                                    imageUrl: user['avatar_url'],
                                    size: 40,
                                  ),
                                title: Text(user['nickname'] as String? ?? '未知用户'),
                                onTap: () => _addCollaborator(user),
                              );
                            },
                          ),
                        ),

                      // 已选择的共创者
                      if (_collaborators.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text('已选择的共创者：', style: TextStyle(fontSize: 14, color: Colors.grey)),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _collaborators.asMap().entries.map((entry) {
                            final index = entry.key;
                            final collab = entry.value;
                            return Chip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(collab['nickname'] as String),
                                  const SizedBox(width: 4),
                                  Text(
                                    '(${collab['role_label']})',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                              avatar:  AvatarWidget(
                                  imageUrl: collab['avatar_url'],
                                  size: 24,
                                ),
                              onDeleted: () => _removeCollaborator(index),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ],
              )
            else
              // 群岛类型
              DropdownButtonFormField<String>(
                value: _islandType,
                decoration: const InputDecoration(
                  labelText: '群岛类型（必选）',
                  border: OutlineInputBorder(),
                ),
                items: _islandTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                validator: (v) => v == null ? '请选择类型' : null,
                onChanged: (v) => setState(() => _islandType = v),
              ),
            const SizedBox(height: 12),

            // 标签
            TextField(
              controller: _tagsCtrl,
              decoration: const InputDecoration(
                labelText: '标签（用逗号分隔，可选）',
                hintText: '例：原神，崩铁',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // 选择图片按钮
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('选择图片'),
                ),
                const SizedBox(width: 12),
                Text('已选 ${_pickedImages.length} 张'),
              ],
            ),
            const SizedBox(height: 8),

            // 已选图片九宫格预览
            if (_pickedImageBytes.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _pickedImageBytes
                    .asMap()
                    .entries
                    .map((e) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                e.value,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              right: 4,
                              top: 4,
                              child: InkWell(
                                onTap: () => setState(() {
                                  _pickedImages.removeAt(e.key);
                                  _pickedImageBytes.removeAt(e.key);
                                }),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                                ),
                              ),
                            )
                          ],
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}