/* import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_profile.dart';
import '../../services/profile_service.dart';
import '../../services/upload_service.dart';

class EditProfilePage extends StatefulWidget {
  final UserProfile profile;

  const EditProfilePage({Key? key, required this.profile}) : super(key: key);

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final ProfileService _profileService = ProfileService();
  final UploadService _uploadService = UploadService();
  final ImagePicker _imagePicker = ImagePicker();

  late TextEditingController _nicknameController;
  late TextEditingController _bioController;
  late TextEditingController _cityController;
  bool _isCoser = false;
  bool _isSaving = false;
  File? _selectedImage;
  Uint8List? _webImage; // Web 平台使用的图片数据

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.profile.nickname);
    _bioController = TextEditingController(text: widget.profile.bio ?? '');
    _cityController = TextEditingController(text: widget.profile.city ?? '');
    _isCoser = widget.profile.isCoser;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image != null) {
        if (kIsWeb) {
          // Web 平台:读取图片字节数据
          final bytes = await image.readAsBytes();
          setState(() {
            _webImage = bytes;
            _selectedImage = null;
          });
        } else {
          // 移动/桌面平台:使用 File
          setState(() {
            _selectedImage = File(image.path);
            _webImage = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  Future<String?> _uploadAvatar() async {
    if (_selectedImage == null && _webImage == null) return null;

    try {
      final avatarUrl = await _uploadService.uploadAvatar(
        userId: widget.profile.id,
        imageFile: _selectedImage,
        imageBytes: _webImage,
      );
      
      return avatarUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('头像上传失败: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // 先上传头像(如果有选择新头像)
      String? newAvatarUrl;
      if (_selectedImage != null || _webImage != null) {
        newAvatarUrl = await _uploadAvatar();
        if (newAvatarUrl == null) {
          throw Exception('头像上传失败');
        }
      }

      // 更新用户资料
      await _profileService.updateProfile(
        userId: widget.profile.id,
        nickname: _nicknameController.text.trim(),
        bio: _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        city: _cityController.text.trim().isEmpty
            ? null
            : _cityController.text.trim(),
        isCoser: _isCoser,
        avatarUrl: newAvatarUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存成功')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildAvatarSection() {
    return Center(
      child: Stack(
        children: [
          // 头像显示
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
            child: ClipOval(
              child: _buildAvatarImage(),
            ),
          ),
          
          // 相机图标按钮
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage() {
    // 优先显示新选择的图片
    if (kIsWeb && _webImage != null) {
      return Image.memory(
        _webImage!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultAvatar();
        },
      );
    } else if (!kIsWeb && _selectedImage != null) {
      return Image.file(
        _selectedImage!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultAvatar();
        },
      );
    }
    
    // 显示当前头像
    return _buildCurrentAvatar();
  }

  Widget _buildCurrentAvatar() {
    if (widget.profile.avatarUrl != null && widget.profile.avatarUrl!.isNotEmpty) {
      return Image.network(
        widget.profile.avatarUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultAvatar();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildDefaultAvatar();
        },
      );
    }
    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Text(
          widget.profile.nickname.isNotEmpty ? widget.profile.nickname[0] : '?',
          style: const TextStyle(fontSize: 32, color: Colors.grey),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑资料'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text('保存', style: TextStyle(fontSize: 16)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 头像区域
            _buildAvatarSection(),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                '点击更换头像',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 24),

            // 昵称
            TextFormField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: '昵称',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入昵称';
                }
                if (value.trim().length < 2) {
                  return '昵称至少2个字符';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 简介
            TextFormField(
              controller: _bioController,
              decoration: const InputDecoration(
                labelText: '个人简介',
                border: OutlineInputBorder(),
                hintText: '介绍一下自己吧~',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
              maxLength: 200,
            ),
            const SizedBox(height: 16),

            // 城市
            TextFormField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: '城市',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
                hintText: '如:北京、上海',
              ),
            ),
            const SizedBox(height: 16),

            // 是否 Coser
            Card(
              child: SwitchListTile(
                title: const Text('我是 Coser'),
                subtitle: const Text('开启后将显示 Coser 标识'),
                value: _isCoser,
                onChanged: (value) {
                  setState(() => _isCoser = value);
                },
                secondary: const Icon(Icons.camera),
              ),
            ),
            const SizedBox(height: 24),

            // 保存按钮(底部)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('保存修改', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
} */

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_profile.dart';
import '../../services/profile_service.dart';
import '../../services/upload_service.dart';

class EditProfilePage extends StatefulWidget {
  final UserProfile profile;

  const EditProfilePage({super.key, required this.profile});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final ProfileService _profileService = ProfileService();
  final UploadService _uploadService = UploadService();
  final ImagePicker _imagePicker = ImagePicker();

  late TextEditingController _nicknameController;
  late TextEditingController _bioController;
  late TextEditingController _cityController;
  bool _isCoser = false;
  bool _isSaving = false;
  File? _selectedImage;
  Uint8List? _webImage; // Web 平台使用的图片数据

  // 🔧 新增:用户角色
  late String _selectedRole;
  
  // 🔧 新增:Coser 等级
  late String _selectedCosLevel;

  // 🔧 新增:角色选项列表
  static const List<Map<String, String>> _roleOptions = [
    {'value': 'user', 'label': '普通用户', 'description': '浏览和互动'},
    {'value': 'coser', 'label': 'Coser', 'description': '发布Cosplay作品'},
    {'value': 'creator_support', 'label': '创作支持', 'description': '摄影/妆造/后期等'},
    {'value': 'organizer', 'label': '活动组织者', 'description': '发布和管理活动'},
  ];

  // 🔧 新增:Coser 等级选项
  static const List<Map<String, String>> _cosLevelOptions = [
    {'value': 'none', 'label': '暂不设置', 'description': ''},
    {'value': 'newbie', 'label': '新手', 'description': '刚开始接触Cosplay'},
    {'value': 'hobby', 'label': '爱好者', 'description': '业余玩家'},
    {'value': 'semi_pro', 'label': '半职业', 'description': '接商业活动'},
    {'value': 'pro', 'label': '职业', 'description': '全职Coser'},
  ];

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.profile.nickname);
    _bioController = TextEditingController(text: widget.profile.bio ?? '');
    _cityController = TextEditingController(text: widget.profile.city ?? '');
    _isCoser = widget.profile.isCoser;
    _selectedRole = widget.profile.role; // 🔧 新增:初始化角色
    _selectedCosLevel = widget.profile.cosLevel; // 🔧 新增:初始化等级
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image != null) {
        if (kIsWeb) {
          // Web 平台:读取图片字节数据
          final bytes = await image.readAsBytes();
          setState(() {
            _webImage = bytes;
            _selectedImage = null;
          });
        } else {
          // 移动/桌面平台:使用 File
          setState(() {
            _selectedImage = File(image.path);
            _webImage = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  Future<String?> _uploadAvatar() async {
    if (_selectedImage == null && _webImage == null) return null;

    try {
      final avatarUrl = await _uploadService.uploadAvatar(
        userId: widget.profile.id,
        imageFile: _selectedImage,
        imageBytes: _webImage,
      );
      
      return avatarUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('头像上传失败: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // 先上传头像(如果有选择新头像)
      String? newAvatarUrl;
      if (_selectedImage != null || _webImage != null) {
        newAvatarUrl = await _uploadAvatar();
        if (newAvatarUrl == null) {
          throw Exception('头像上传失败');
        }
      }

      // 更新用户资料
      await _profileService.updateProfile(
        userId: widget.profile.id,
        nickname: _nicknameController.text.trim(),
        bio: _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        city: _cityController.text.trim().isEmpty
            ? null
            : _cityController.text.trim(),
        isCoser: _isCoser,
        avatarUrl: newAvatarUrl,
        role: _selectedRole,  // 🔧 新增:保存角色
        cosLevel: _selectedCosLevel,  // 🔧 新增:保存等级
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存成功')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildAvatarSection() {
    return Center(
      child: Stack(
        children: [
          // 头像显示
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
            child: ClipOval(
              child: _buildAvatarImage(),
            ),
          ),
          
          // 相机图标按钮
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage() {
    // 优先显示新选择的图片
    if (kIsWeb && _webImage != null) {
      return Image.memory(
        _webImage!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultAvatar();
        },
      );
    } else if (!kIsWeb && _selectedImage != null) {
      return Image.file(
        _selectedImage!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultAvatar();
        },
      );
    }
    
    // 显示当前头像
    return _buildCurrentAvatar();
  }

  Widget _buildCurrentAvatar() {
    if (widget.profile.avatarUrl != null && widget.profile.avatarUrl!.isNotEmpty) {
      return Image.network(
        widget.profile.avatarUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultAvatar();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildDefaultAvatar();
        },
      );
    }
    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Text(
          widget.profile.nickname.isNotEmpty ? widget.profile.nickname[0] : '?',
          style: const TextStyle(fontSize: 32, color: Colors.grey),
        ),
      ),
    );
  }

  // 🔧 新增:构建角色选择器
  Widget _buildRoleSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.badge, color: Colors.grey),
                SizedBox(width: 8),
                Text(
                  '我的身份',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._roleOptions.map((option) => _buildRoleOption(option)),
          ],
        ),
      ),
    );
  }

  // 🔧 新增:构建单个角色选项
  Widget _buildRoleOption(Map<String, String> option) {
    final isSelected = _selectedRole == option['value'];
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedRole = option['value']!;
          // 🔧 新增:如果选择了 coser 角色,自动设置 isCoser 为 true
          if (_selectedRole == 'coser') {
            _isCoser = true;
          } else {
            _isCoser = false;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(8),
          border: isSelected 
              ? Border.all(color: Theme.of(context).primaryColor, width: 1)
              : null,
        ),
        child: Row(
          children: [
            // 选中指示器
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected 
                      ? Theme.of(context).primaryColor 
                      : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // 角色信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option['label']!,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected 
                          ? Theme.of(context).primaryColor 
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option['description']!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // 选中图标
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  // 🔧 新增:构建 Coser 等级选择器
  Widget _buildCosLevelSelector() {
    // 只有选择了 coser 角色时才显示
    if (_selectedRole != 'coser') {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.star, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'Coser 等级',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._cosLevelOptions.map((option) => _buildCosLevelOption(option)),
          ],
        ),
      ),
    );
  }

  // 🔧 新增:构建单个 Coser 等级选项
  Widget _buildCosLevelOption(Map<String, String> option) {
    final isSelected = _selectedCosLevel == option['value'];
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCosLevel = option['value']!;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(8),
          border: isSelected 
              ? Border.all(color: Colors.purple, width: 1)
              : null,
        ),
        child: Row(
          children: [
            // 选中指示器
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected 
                      ? Colors.purple 
                      : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.purple,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // 等级信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option['label']!,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected 
                          ? Colors.purple 
                          : Colors.black87,
                    ),
                  ),
                  if (option['description']!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      option['description']!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 选中图标
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Colors.purple,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑资料'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text('保存', style: TextStyle(fontSize: 16)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 头像区域
            _buildAvatarSection(),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                '点击更换头像',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 24),

            // 昵称
            TextFormField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: '昵称',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入昵称';
                }
                if (value.trim().length < 2) {
                  return '昵称至少2个字符';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 简介
            TextFormField(
              controller: _bioController,
              decoration: const InputDecoration(
                labelText: '个人简介',
                border: OutlineInputBorder(),
                hintText: '介绍一下自己吧~',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
              maxLength: 200,
            ),
            const SizedBox(height: 16),

            // 城市
            TextFormField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: '城市',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
                hintText: '如:北京、上海',
              ),
            ),
            const SizedBox(height: 16),

            // 是否 Coser
            Card(
              child: SwitchListTile(
                title: const Text('我是 Coser'),
                subtitle: const Text('开启后将显示 Coser 标识'),
                value: _isCoser,
                onChanged: (value) {
                  setState(() {
                    _isCoser = value;
                    // 🔧 新增:如果开启 isCoser,自动设置角色为 coser
                    if (_isCoser) {
                      _selectedRole = 'coser';
                    } else if (_selectedRole == 'coser') {
                      // 如果关闭 isCoser 且当前角色是 coser,重置为 user
                      _selectedRole = 'user';
                    }
                  });
                },
                secondary: const Icon(Icons.camera),
              ),
            ),
            const SizedBox(height: 16),

            // 🔧 新增:角色选择
            _buildRoleSelector(),
            const SizedBox(height: 16),

            // 🔧 新增:Coser 等级选择(只有选择 coser 角色时显示)
            _buildCosLevelSelector(),
            const SizedBox(height: 24),

            // 保存按钮(底部)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('保存修改', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}