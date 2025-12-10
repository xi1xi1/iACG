import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:iacg/features/post/post_detail_page.dart';
import 'package:iacg/services/post_service.dart';
import 'package:iacg/services/tag_service.dart';
import 'package:iacg/services/search_service.dart';
import 'package:iacg/services/profile_service.dart';
import 'package:iacg/widgets/avatar_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iacg/services/event_service.dart'; // 新增导入
import 'package:intl/intl.dart';
class PostComposePage extends StatefulWidget {
  final String? initialChannel;
  final String? autoFillTag; // ✅ 新增：自动填充的标签名称
  const PostComposePage({
    super.key,
    this.initialChannel,
    this.autoFillTag, // ✅ 新增
  });

  @override
  State<PostComposePage> createState() => _PostComposePageState();
}

class _PostComposePageState extends State<PostComposePage> {
  final _formKey = GlobalKey<FormState>();
  final _postService = PostService();
  final _tagService = TagService();
  final _searchService = SearchService();
  final _client = Supabase.instance.client;
  final _profileService = ProfileService();
 // 新增：活动标签字段（仅用于event频道）
  String? _eventThemeTag; // 活动标签
  final TextEditingController _eventThemeTagCtrl = TextEditingController();
  late String _channel; // cos | island | event
  bool _isOrganizer = false;
  bool _loadingUserRole = true;
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _eventService = EventService(); 
  String? _eventTag; // ✅ 新增：活动标签字段

  // ✅ 新增：存储自动填充的标签
  String? _autoFilledTag;

  // COS only
  String? _cosCategory; // anime/game/comic/novel/other
  final _cosCategories = const ['anime', 'game', 'comic', 'novel', 'other'];
  String? _ipTag; // IP标签
  final List<Map<String, dynamic>> _collaborators = []; // 共创者列表

  // Island only
  String? _islandType;
  final _islandTypes = const ['求助', '分享', '吐槽', '找搭子', '约拍', '其他'];

  // Event only
  //String? _eventType;
 // final _eventTypes = const ['漫展', '同人展', 'Cosplay比赛', '摄影会', '交流会', '其他活动'];
  DateTime? _eventStartTime;
  DateTime? _eventEndTime;
  final TextEditingController _eventLocationCtrl = TextEditingController();
  final TextEditingController _eventCityCtrl = TextEditingController();
  final TextEditingController _eventTicketUrlCtrl = TextEditingController();
  final TextEditingController _eventParticipantCountCtrl =
      TextEditingController();
      
  String? _eventLocation;
  String? _eventCity;
  String? _eventTicketUrl;

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

  // 二次元风格颜色 - 修改为ED7099粉色
  final Color _primaryColor = const Color(0xFFED7099); // 粉色 - 与首页发作品按钮一致
  final Color _secondaryColor = const Color(0xFF8B5CF6); // 紫色
  final Color _accentColor = const Color(0xFFED7099); // 青色改为粉色，用于选择图片按钮
  final Color _backgroundColor = const Color(0xFFF8FAFC); // 浅灰背景

  @override
  void initState() {
    super.initState();
    // 初始化频道，如果有传入的初始频道则使用，否则默认cos
    _channel = widget.initialChannel ?? 'cos';
    // ✅ 新增：处理自动填充的标签
    if (widget.autoFillTag != null && widget.autoFillTag!.trim().isNotEmpty) {
      _autoFilledTag = widget.autoFillTag!.trim();

      // 自动将活动标签添加到标签输入框
      if (_tagsCtrl.text.trim().isEmpty) {
        _tagsCtrl.text = _autoFilledTag!;
      } else {
        // 检查是否已经包含该标签（简单的检查）
        final currentTags = _tagsCtrl.text
            .split(RegExp(r'[，, ]'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        if (!currentTags.contains(_autoFilledTag!)) {
          _tagsCtrl.text = '${_tagsCtrl.text}, ${_autoFilledTag!}';
        }
      }

      // （可选）自动设置标题前缀
      if (_titleCtrl.text.isEmpty) {
        _titleCtrl.text = '';
      }
    }
    _checkUserRole();
  }

  @override
  void dispose() {
   // _eventThemeTagCtrl.dispose(); 
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _tagsCtrl.dispose();
    _searchCtrl.dispose();
    // _eventLocationCtrl.dispose();
    // _eventCityCtrl.dispose();
    // _eventTicketUrlCtrl.dispose();
    // _eventParticipantCountCtrl.dispose();
    super.dispose();
  }

  // 检查用户是否是活动组织者
  Future<void> _checkUserRole() async {
    try {
      final profile = await _profileService.fetchMyProfile();
      if (profile != null) {
        setState(() {
          _isOrganizer = profile.role == 'organizer';
          _loadingUserRole = false;
        });
        print('用户身份检查完成: isOrganizer = $_isOrganizer, role = ${profile.role}');
      } else {
        setState(() => _loadingUserRole = false);
      }
    } catch (e) {
      print('检查用户身份失败: $e');
      setState(() => _loadingUserRole = false);
    }
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

  // 添加时间选择方法
Future<void> _pickEventTime({required bool isStart}) async {
  final now = DateTime.now();
  final initial = isStart ? _eventStartTime : _eventEndTime;
  
  final picked = await showDatePicker(
    context: context,
    initialDate: initial ?? now,
    firstDate: now,
    lastDate: DateTime(now.year + 1),
  );
  
  if (picked != null) {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? now),
    );
    
    if (time != null) {
      final dateTime = DateTime(
        picked.year, picked.month, picked.day,
        time.hour, time.minute
      );
      
      setState(() {
        if (isStart) {
          _eventStartTime = dateTime;
        } else {
          _eventEndTime = dateTime;
        }
      });
    }
  }
}

// 角色检查方法（替换原有的_checkUserRole）
Future<bool> _isUserOrganizer() async {
  final user = _client.auth.currentUser;
  if (user == null) return false;
  
  try {
    final response = await _client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .single();
    
    return response['role'] == 'organizer';
  } catch (e) {
    print('获取用户角色失败: $e');
    return false;
  }
}

  // 添加共创者（带角色选择）
  void _addCollaborator(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '选择角色',
          style:
              TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF374151)),
        ),
        content: Container(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView(
            shrinkWrap: true,
            children: _roles.map((role) {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getRoleIcon(role['value'] ?? 'other'),
                      color: _primaryColor,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    role['label'] ?? '其他合作',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
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
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // 获取角色图标
  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'photographer':
        return Icons.camera_alt;
      case 'makeup':
        return Icons.brush;
      case 'costume':
        return Icons.checkroom;
      case 'props':
        return Icons.build;
      case 'retouch':
        return Icons.photo_filter;
      default:
        return Icons.people;
    }
  }

  // 移除共创者
  void _removeCollaborator(int index) {
    setState(() => _collaborators.removeAt(index));
  }
Future<void> _publish() async {
  if (!(_formKey.currentState?.validate() ?? false)) return;

  // ✅ 新增：活动字段验证
  if (_channel == 'event') {
    // 权限检查
    final isOrganizer = await _isUserOrganizer();
    if (!isOrganizer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('只有活动组织者才能发布活动帖子'))
      );
      return;
    }
    
    // 必填字段检查
    if (_eventStartTime == null || _eventEndTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择活动时间'))
      );
      return;
    }
    if (_eventLocation == null || _eventCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写活动地点和城市'))
      );
      return;
    }
    if (_eventTag == null || _eventTag!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写活动标签'))
      );
      return;
    }
    if (_eventStartTime!.isAfter(_eventEndTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('开始时间不能晚于结束时间'))
      );
      return;
    }
  }

  final user = _client.auth.currentUser;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('请先登录'),
        backgroundColor: _primaryColor,
      ),
    );
    return;
  }

  setState(() => _publishing = true);
  int? postId;

  try {
    // ✅ 修改：区分活动发布和普通发布
    if (_channel == 'event') {
      // ✅ 新增：处理活动标签（仿照IP标签）
      int? eventTagId;
      if (_eventTag != null && _eventTag!.trim().isNotEmpty) {
        final eventTagNames = [_eventTag!.trim()];
        final tagIds = await _tagService.ensureTagsAndReturnIds(
          eventTagNames, 
          type: 'theme' // ✅ 活动标签使用 'theme' 类型
        );
        if (tagIds.isNotEmpty) {
          eventTagId = tagIds.first;
          // 同时添加到普通标签中（为了在详情页显示）
          if (_tagsCtrl.text.trim().isEmpty) {
            _tagsCtrl.text = _eventTag!;
          } else {
            _tagsCtrl.text = '${_tagsCtrl.text}, ${_eventTag!}';
          }
        }
      }

      // 使用 EventService 创建活动
      final result = await _eventService.createEvent(
        name: _titleCtrl.text.trim(),
        title: _titleCtrl.text.trim(),
        content: _contentCtrl.text.trim().isEmpty ? '' : _contentCtrl.text.trim(),
        authorId: user.id,
        startTime: _eventStartTime!,
        endTime: _eventEndTime!,
        location: _eventLocation!,
        city: _eventCity,
        ticketUrl: _eventTicketUrl,
        eventTag: _eventTag, // ✅ 传递活动标签
      );
      
      postId = result['postId'];
      print('活动创建成功，帖子ID: $postId, 活动ID: ${result['eventId']}');
    } else {
      // ✅ 保留原有的普通帖子发布逻辑
      // 处理 IP 标签
      int? mainIpTagId;
      if (_ipTag != null && _ipTag!.trim().isNotEmpty) {
        final ipTagNames = [_ipTag!.trim()];
        final tagIds = await _tagService.ensureTagsAndReturnIds(
          ipTagNames, 
          type: 'ip' // ✅ COS的IP标签类型
        );
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
    }

    // 2) 添加共创者（活动和COS都支持，群岛不支持）
    if (_collaborators.isNotEmpty && _channel != 'island') {
      try {
        final collaboratorEntries = _collaborators.map((collab) => {
          'post_id': postId,
          'user_id': collab['user_id'],
          'role': collab['role'],
          'display_name': null,
        }).toList();

        await _client.from('post_collaborators').insert(collaboratorEntries);
        print('添加了 ${_collaborators.length} 个共创者');
      } catch (e) {
        print('添加共创者失败: $e');
      }
    }

    // 3) 上传图片并绑定 post_media（所有频道都支持）
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

    // 4) 绑定标签（所有频道都支持）
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
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  } finally {
    if (mounted) setState(() => _publishing = false);
  }
}
//   Future<void> _publish() async {
//     if (!(_formKey.currentState?.validate() ?? false)) return;

//     final user = _client.auth.currentUser;
//     if (user == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: const Text('请先登录'),
//           backgroundColor: _primaryColor,
//         ),
//       );
//       return;
//     }

//     setState(() => _publishing = true);
//     int? postId;

//     try {
//       int? mainThemeTagId;
//         if (_channel == 'event') {
//       if (_eventThemeTag == null || _eventThemeTag!.trim().isEmpty) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: const Text('请填写活动标签'),
//             backgroundColor: Colors.red,
//           ),
//         );
//         setState(() => _publishing = false);
//         return;
//       } // 创建theme类型的标签
//       final themeTagNames = [_eventThemeTag!.trim()];
//       final themeTagIds = await _tagService.ensureTagsAndReturnIds(themeTagNames, type: 'theme');
//       if (themeTagIds.isNotEmpty) {
//         mainThemeTagId = themeTagIds.first;
//       }
//     }
//       // 处理 IP 标签
//       int? mainIpTagId;
//       if (_ipTag != null && _ipTag!.trim().isNotEmpty) {
//         final ipTagNames = [_ipTag!.trim()];
//         final tagIds = await _tagService.ensureTagsAndReturnIds(ipTagNames, type: 'ip');
//         if (tagIds.isNotEmpty) {
//           mainIpTagId = tagIds.first;
//           // 同时添加到普通标签中
//           if (_tagsCtrl.text.trim().isEmpty) {
//             _tagsCtrl.text = _ipTag!;
//           } else {
//             _tagsCtrl.text = '${_tagsCtrl.text}, ${_ipTag!}';
//           }
//         }
        
//       }
      
      

//       // 1) 创建帖子
// postId = await _postService.createPost(
//   authorId: user.id,
//   channel: _channel,
//   title: _titleCtrl.text.trim(),
//   content:
//       _contentCtrl.text.trim().isEmpty ? null : _contentCtrl.text.trim(),
//   mainCategory: _channel == 'cos' ? _cosCategory : null,
//   mainIpTagId: mainIpTagId,
//   mainThemeTagId: mainThemeTagId, // ✅ 新增：传递活动标签ID
//   islandType: _channel == 'island' ? _islandType : null,
//   // ✅ 新增：如果是活动，添加活动相关参数
//   eventType: _channel == 'event' ? _eventType : null,
//   eventStartTime: _channel == 'event' ? _eventStartTime : null,
//   eventEndTime: _channel == 'event' ? _eventEndTime : null,
//   eventLocation: _channel == 'event' ? _eventLocationCtrl.text.trim() : null,
//   eventCity: _channel == 'event' ? _eventCityCtrl.text.trim() : null,
//   eventTicketUrl: _channel == 'event' ? _eventTicketUrlCtrl.text.trim() : null,
//   eventParticipantCount: _channel == 'event' ? 
//     (_eventParticipantCountCtrl.text.trim().isEmpty ? 
//       null : int.tryParse(_eventParticipantCountCtrl.text.trim())) : null,
// );
//       // postId = await _postService.createPost(
//       //   authorId: user.id,
//       //   channel: _channel,
//       //   title: _titleCtrl.text.trim(),
//       //   content:
//       //       _contentCtrl.text.trim().isEmpty ? null : _contentCtrl.text.trim(),
//       //   mainCategory: _channel == 'cos' ? _cosCategory : null,
//       //   mainIpTagId: mainIpTagId,
        
//       //   islandType: _channel == 'island' ? _islandType : null,
//       // );

//       // print('帖子创建成功，ID: $postId');

//       // 2) 添加共创者
//       if (_collaborators.isNotEmpty) {
//         try {
//           final collaboratorEntries = _collaborators
//               .map((collab) => {
//                     'post_id': postId,
//                     'user_id': collab['user_id'],
//                     'role': collab['role'],
//                     'display_name': null,
//                   })
//               .toList();

//           await _client.from('post_collaborators').insert(collaboratorEntries);
//           print('添加了 ${_collaborators.length} 个共创者');
//         } catch (e) {
//           print('添加共创者失败: $e');
//         }
//       }

//       // 3) 上传图片并绑定 post_media
//       if (_pickedImages.isNotEmpty) {
//         print('开始上传 ${_pickedImages.length} 张图片');
//         final mediaEntries = <Map<String, String>>[];
//         for (int i = 0; i < _pickedImages.length; i++) {
//           final file = _pickedImages[i];
//           print('上传第 ${i + 1} 张图片: ${file.path}');
//           try {
//             final xFile = XFile(file.path);
//             final url = await _postService.uploadMediaFile(
//               postId: postId!,
//               xFile: xFile,
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
//           await _postService.attachMedia(postId!, mediaEntries);
//           print('媒体附件关联成功');
//         }
//       }

//       // 4) 绑定标签
//       final raw = _tagsCtrl.text.trim();
//       if (raw.isNotEmpty) {
//         final names = raw
//             .split(RegExp(r'[，,]'))
//             .map((s) => s.trim())
//             .where((s) => s.isNotEmpty)
//             .toList();
//         try {
//           final tagIds = await _tagService.ensureTagsAndReturnIds(names);
//           if (tagIds.isNotEmpty) {
//             await _postService.attachTags(postId!, tagIds);
//             print('成功添加 ${tagIds.length} 个标签: $names');
//           }
//         } catch (e) {
//           print('标签处理失败: $e');
//         }
//       }

//       if (!mounted) return;

//       print('发布流程完成，跳转到详情页');
//       // 5) 成功后跳详情页
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

//       String errorMessage = '发布失败：$e';
//       if (postId != null) {
//         errorMessage = '帖子已创建，但后续处理失败：$e\n帖子ID: $postId';
//       }

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(errorMessage),
//           backgroundColor: Colors.red,
//           duration: const Duration(seconds: 5),
//         ),
//       );
//     } finally {
//       if (mounted) setState(() => _publishing = false);
//     }
//   }

// ✅ 新增：构建标签部分（包含活动标签提示）
  Widget _buildTagsSection() {
    return _buildAnimeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ 新增：如果是从活动页来的，显示提示
          if (_autoFilledTag != null && _autoFilledTag!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFED7099).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: const Color(0xFFED7099).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_note,
                    color: Colors.pink[600],
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '已自动添加活动标签 #$_autoFilledTag，添加标签示例：每日一水，经验分享（用逗号分隔）',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.pink[600],
                      ),
                    ),
                  ),
                  // 可选：添加移除按钮
                  GestureDetector(
                    onTap: () {
                      _removeAutoFilledTag();
                    },
                    child: Icon(
                      Icons.close,
                      color: Colors.grey[500],
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),

          const Text(
            '标签',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF374151)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _tagsCtrl,
            decoration: InputDecoration(
              hintText: '例：每日一水，经验分享（用逗号分隔）',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryColor, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

// ✅ 新增：移除自动填充的标签
  void _removeAutoFilledTag() {
    if (_autoFilledTag == null) return;
    // 只是隐藏提示，不删除输入框中的标签
    setState(() {
      _autoFilledTag = null;
    });

    // 可以给用户一个提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('活动标签提示已隐藏，如需删除请手动编辑标签'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // 构建二次元风格卡片
  Widget _buildAnimeCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  // 构建二次元风格按钮
  Widget _buildAnimeButton({
    required VoidCallback? onPressed,
    required Widget child,
    Color? backgroundColor,
    bool isPrimary = false,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            backgroundColor ?? (isPrimary ? _primaryColor : _secondaryColor),
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor:
            (backgroundColor ?? (isPrimary ? _primaryColor : _secondaryColor))
                .withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      child: child,
    );
  }

  // 构建频道选择芯片 - 修改为更小的按钮尺寸
  Widget _buildChannelChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return Card(
      elevation: isSelected ? 1 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? _primaryColor : Colors.grey.shade300,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: const BoxConstraints(
            minWidth: 80, // 更小的最小宽度
            maxWidth: 120, // 更小的最大宽度
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13, // 更小的字体
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? _primaryColor : Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCos = _channel == 'cos';
    final isEvent = _channel == 'event';

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '发布内容',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: _buildAnimeButton(
              onPressed: _publishing ? null : _publish,
              isPrimary: true,
              child: _publishing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.send, size: 16),
                        SizedBox(width: 4),
                        Text('发布',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // // 频道选择
            // _buildAnimeCard(
            //   child: Column(
            //     crossAxisAlignment: CrossAxisAlignment.start,
            //     children: [
            //       const Text(
            //         '选择频道',
            //         style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
            //       ),
            //       const SizedBox(height: 12),
            //       if (_loadingUserRole)
            //         const Center(
            //           child: CircularProgressIndicator(),
            //         )
            //       else
            //         Column(
            //           children: [
            //             // 使用 Wrap 或 Row 配合 MainAxisAlignment.center 来防止按钮过度拉长
            //
            //             Wrap(
            //               spacing: 4,
            //               runSpacing: 4,
            //               alignment: WrapAlignment.center,
            //               children: [
            //                 _buildChannelChip(
            //                   label: 'COS作品',
            //                   isSelected: _channel == 'cos',
            //                   onSelected: () => setState(() => _channel = 'cos'),
            //                 ),
            //                 _buildChannelChip(
            //                   label: '群岛社区',
            //                   isSelected: _channel == 'island',
            //                   onSelected: () => setState(() => _channel = 'island'),
            //                 ),
            //                 if (_isOrganizer)
            //                   _buildChannelChip(
            //                     label: '活动',
            //                     isSelected: _channel == 'event',
            //                     onSelected: () => setState(() => _channel = 'event'),
            //                   ),
            //               ],
            //             ),
            //           ],
            //         ),
            //       // if (!_isOrganizer && !_loadingUserRole)
            //       //   Container(
            //       //     margin: const EdgeInsets.only(top: 8),
            //       //     padding: const EdgeInsets.all(12),
            //       //     decoration: BoxDecoration(
            //       //       color: Colors.orange.shade50,
            //       //       borderRadius: BorderRadius.circular(8),
            //       //       border: Border.all(color: Colors.orange.shade200),
            //       //     ),
            //       //     child: Row(
            //       //       children: [
            //       //         Icon(Icons.info_outline, color: Colors.orange.shade600, size: 16),
            //       //         const SizedBox(width: 8),
            //       //         Expanded(
            //       //           child: Text(
            //       //             '只有活动组织者才能发布活动',
            //       //             style: TextStyle(
            //       //               fontSize: 12,
            //       //               color: Colors.orange.shade700,
            //       //             ),
            //       //           ),
            //       //         ),
            //       //       ],
            //       //     ),
            //       //   ),
            //     ],
            //   ),
            // ),

            // 标题和正文二合一，中间用一条半透明的黑直线分开
            _buildAnimeCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题部分
                  // const Text(
                  //   '标题',
                  //   style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                  // ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleCtrl,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: '标题',
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),

                  // 半透明的黑直线分隔
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    height: 1,
                    color: Colors.black.withOpacity(0.1),
                  ),

                  //正文部分
                  // const Text(
                  //   '正文内容',
                  //   style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                  // ),
                  const SizedBox(height: 15),
                  Container(
                    height: 300,
                    child: TextFormField(
                      controller: _contentCtrl,
                      minLines: 5,
                      maxLines: 100,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '分享你的想法...',
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // COS 分类 或 群岛类型 或 活动类型
            if (isCos)
              _buildAnimeCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'COS分类',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF374151)),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _cosCategory,
                      decoration: InputDecoration(
                        labelText: '选择分类',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: _primaryColor, width: 2),
                        ),
                      ),
                      items: _cosCategories.map((c) {
                        final label = {
                          'anime': '动漫',
                          'game': '游戏',
                          'comic': '漫画',
                          'novel': '小说',
                          'other': '其他',
                        }[c]!;
                        return DropdownMenuItem(
                          value: c,
                          child: Text(label),
                        );
                      }).toList(),
                      validator: (v) => v == null ? '请选择分类' : null,
                      onChanged: (v) => setState(() => _cosCategory = v),
                    ),
                    const SizedBox(height: 12),

                    // IP标签
                    const Text(
                      'IP标签',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF374151)),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: InputDecoration(
                        hintText: '例如：原神、崩坏：星穹铁道',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: _primaryColor, width: 2),
                        ),
                      ),
                      onChanged: (v) => setState(() => _ipTag = v),
                    ),
                    const SizedBox(height: 12),

                    // 共创者
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '共创者',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF374151)),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: '搜索用户名添加共创者...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: _primaryColor, width: 2),
                            ),
                            suffixIcon: _searching
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : null,
                          ),
                          onChanged: _searchUsers,
                        ),
                        if (_searchResults.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final user = _searchResults[index];
                                return ListTile(
                                  leading: AvatarWidget(
                                    imageUrl: user['avatar_url'] as String?,
                                    size: 40,
                                  ),
                                  title: Text(
                                      user['nickname'] as String? ?? '未知用户'),
                                  onTap: () => _addCollaborator(user),
                                );
                              },
                            ),
                          ),

                        // 已选择的共创者
                        if (_collaborators.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            '已选择的共创者：',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children:
                                _collaborators.asMap().entries.map((entry) {
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
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                avatar: AvatarWidget(
                                  imageUrl: collab['avatar_url'] as String?,
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
                ),
              )
            else if (isEvent)
  _buildAnimeCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ✅ 活动标签（必填）
        const Text(
          '活动标签 *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          decoration: InputDecoration(
            hintText: '例如：CP30、夏日祭',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _primaryColor, width: 2),
            ),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? '请输入活动标签' : null,
          onChanged: (v) => setState(() => _eventTag = v),
        ),
        const SizedBox(height: 12),

        // 活动时间
        const Text(
          '活动时间 *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickEventTime(isStart: true),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Text(_eventStartTime == null 
                    ? '选择开始时间'
                    : '开始: ${DateFormat('MM/dd HH:mm').format(_eventStartTime!)}'
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickEventTime(isStart: false),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Text(_eventEndTime == null 
                    ? '选择结束时间'
                    : '结束: ${DateFormat('MM/dd HH:mm').format(_eventEndTime!)}'
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 活动地点
        const Text(
          '活动地点 *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
        ),
        const SizedBox(height: 8),
        TextFormField(
          decoration: InputDecoration(
            hintText: '例如：上海国家会展中心',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _primaryColor, width: 2),
            ),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? '请输入活动地点' : null,
          onChanged: (v) => setState(() => _eventLocation = v),
        ),
        const SizedBox(height: 12),
        
        // 活动城市
        const Text(
          '活动城市 *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
        ),
        const SizedBox(height: 8),
        TextFormField(
          decoration: InputDecoration(
            hintText: '例如：上海',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _primaryColor, width: 2),
            ),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? '请输入活动城市' : null,
          onChanged: (v) => setState(() => _eventCity = v),
        ),
        const SizedBox(height: 12),
        
        // 购票链接
        const Text(
          '购票链接（可选）',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
        ),
        const SizedBox(height: 8),
        TextFormField(
          decoration: InputDecoration(
            hintText: 'https://...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _primaryColor, width: 2),
            ),
          ),
          onChanged: (v) => setState(() => _eventTicketUrl = v),
        ),
      ],
    ),
  )
            else
              _buildAnimeCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '群岛类型',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF374151)),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _islandType,
                      decoration: InputDecoration(
                        labelText: '选择类型',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: _primaryColor, width: 2),
                        ),
                      ),
                      items: _islandTypes
                          .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      validator: (v) => v == null ? '请选择类型' : null,
                      onChanged: (v) => setState(() => _islandType = v),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),

// 标签（包含活动标签提示）
            _buildTagsSection(),
            // 标签
            // _buildAnimeCard(
            //   child: Column(
            //     crossAxisAlignment: CrossAxisAlignment.start,
            //     children: [
            //       const Text(
            //         '标签',
            //         style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
            //       ),
            //       const SizedBox(height: 8),
            //       TextField(
            //         controller: _tagsCtrl,
            //         decoration: InputDecoration(
            //           hintText: '例：原神，崩铁（用逗号分隔）',
            //           border: OutlineInputBorder(
            //             borderRadius: BorderRadius.circular(12),
            //             borderSide: BorderSide(color: Colors.grey.shade300),
            //           ),
            //           focusedBorder: OutlineInputBorder(
            //             borderRadius: BorderRadius.circular(12),
            //             borderSide: BorderSide(color: _primaryColor, width: 2),
            //           ),
            //         ),
            //       ),
            //     ],
            //   ),
            // ),

            // 图片上传
            _buildAnimeCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '图片上传',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF374151)),
                  ),
                  const SizedBox(height: 12),
                  _buildAnimeButton(
                    onPressed: _pickImages,
                    backgroundColor: _accentColor,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_photo_alternate, size: 18),
                        SizedBox(width: 8),
                        Text('选择图片',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '已选择 ${_pickedImages.length} 张图片',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  // 图片预览
                  if (_pickedImageBytes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _pickedImageBytes.asMap().entries.map((e) {
                        return Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  e.value,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 4,
                              top: 4,
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _pickedImages.removeAt(e.key);
                                  _pickedImageBytes.removeAt(e.key);
                                }),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
