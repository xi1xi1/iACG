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
  bool _isSaving = false;
  File? _selectedImage;
  Uint8List? _webImage;

  late String _selectedRole;
  late String _selectedCosLevel;

  static const List<Map<String, String>> _roleOptions = [
    {'value': 'user', 'label': '普通用户', 'description': '浏览和互动'},
    {'value': 'coser', 'label': 'Coser', 'description': '发布Cosplay作品'},
    {'value': 'creator_support', 'label': '创作支持', 'description': '摄影/妆造/后期等'},
    {'value': 'organizer', 'label': '活动组织者', 'description': '发布和管理活动'},
  ];

  static const List<Map<String, String>> _cosLevelOptions = [
    {'value': 'none', 'label': '暂不设置', 'description': ''},
    {'value': 'newbie', 'label': '新手', 'description': '刚开始接触Cosplay'},
    {'value': 'hobby', 'label': '爱好者', 'description': '业余玩家'},
    {'value': 'semi_pro', 'label': '半职业', 'description': '接商业活动'},
    {'value': 'pro', 'label': '职业', 'description': '全职Coser'},
  ];

  // 粉色主题颜色
  final Color _pinkColor = const Color(0xFFE91E63); // 主粉色
  final Color _lightPink = const Color(0xFFFCE4EC); // 浅粉色背景
  final Color _darkPink = const Color(0xFFAD1457); // 深粉色

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.profile.nickname);
    _bioController = TextEditingController(text: widget.profile.bio ?? '');
    _cityController = TextEditingController(text: widget.profile.city ?? '');
    _selectedRole = widget.profile.role;
    _selectedCosLevel = widget.profile.cosLevel;
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
          final bytes = await image.readAsBytes();
          setState(() {
            _webImage = bytes;
            _selectedImage = null;
          });
        } else {
          setState(() {
            _selectedImage = File(image.path);
            _webImage = null;
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('选择图片失败: $e');
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
      _showErrorSnackBar('头像上传失败: $e');
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? newAvatarUrl;
      if (_selectedImage != null || _webImage != null) {
        newAvatarUrl = await _uploadAvatar();
        if (newAvatarUrl == null) {
          throw Exception('头像上传失败');
        }
      }

      await _profileService.updateProfile(
        userId: widget.profile.id,
        nickname: _nicknameController.text.trim(),
        bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
        avatarUrl: newAvatarUrl,
        role: _selectedRole,
        cosLevel: _selectedCosLevel,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存成功')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showErrorSnackBar('保存失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Widget _buildAvatarSection() {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _pinkColor, width: 3),
              ),
              child: ClipOval(
                child: _buildAvatarImage(),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _pinkColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '点击更换头像',
          style: TextStyle(fontSize: 12, color: _pinkColor.withOpacity(0.7)),
        ),
      ],
    );
  }

  Widget _buildAvatarImage() {
    if (kIsWeb && _webImage != null) {
      return Image.memory(
        _webImage!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
      );
    } else if (!kIsWeb && _selectedImage != null) {
      return Image.file(
        _selectedImage!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
      );
    }
    return _buildCurrentAvatar();
  }

  Widget _buildCurrentAvatar() {
    if (widget.profile.avatarUrl != null && widget.profile.avatarUrl!.isNotEmpty) {
      return Image.network(
        widget.profile.avatarUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
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
      color: _lightPink,
      child: Center(
        child: Icon(
          Icons.person,
          size: 48,
          color: _pinkColor.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.badge, color: _pinkColor),
                const SizedBox(width: 8),
                Text(
                  '我的身份',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _pinkColor,
                  ),
                ),
              ],
            ),
          ),
          ..._roleOptions.map((option) => _buildRoleOption(option)),
        ],
      ),
    );
  }

  Widget _buildRoleOption(Map<String, String> option) {
    final isSelected = _selectedRole == option['value'];

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Material(
        color: isSelected ? _lightPink : Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedRole = option['value']!;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? _pinkColor : Colors.grey.shade400,
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
                        color: _pinkColor,
                      ),
                    ),
                  )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option['label']!,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? _pinkColor : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        option['description']!,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected ? _pinkColor.withOpacity(0.8) : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: _pinkColor,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCosLevelSelector() {
    if (_selectedRole != 'coser') {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.star, color: _pinkColor),
                const SizedBox(width: 8),
                Text(
                  'Coser 等级',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _pinkColor,
                  ),
                ),
              ],
            ),
          ),
          ..._cosLevelOptions.map((option) => _buildCosLevelOption(option)),
        ],
      ),
    );
  }

  Widget _buildCosLevelOption(Map<String, String> option) {
    final isSelected = _selectedCosLevel == option['value'];

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Material(
        color: isSelected ? _lightPink : Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedCosLevel = option['value']!;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? _pinkColor : Colors.grey.shade400,
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
                        color: _pinkColor,
                      ),
                    ),
                  )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option['label']!,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? _pinkColor : Colors.black87,
                        ),
                      ),
                      if (option['description']!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          option['description']!,
                          style: TextStyle(
                            fontSize: 13,
                            color: isSelected ? _pinkColor.withOpacity(0.8) : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: _pinkColor,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '编辑资料',
          style: TextStyle(color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              onPressed: _saveProfile,
              icon: Icon(Icons.check, size: 24, color: _pinkColor),
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
            const SizedBox(height: 32),

            // 基本信息卡片
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, color: _pinkColor),
                        const SizedBox(width: 8),
                        Text(
                          '基本信息',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _pinkColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nicknameController,
                          decoration: InputDecoration(
                            labelText: '昵称',
                            border: const OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person, color: _pinkColor),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: _pinkColor),
                            ),
                            labelStyle: TextStyle(color: _pinkColor),
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
                        TextFormField(
                          controller: _bioController,
                          decoration: InputDecoration(
                            labelText: '个人简介',
                            border: const OutlineInputBorder(),
                            hintText: '介绍一下自己吧~',
                            prefixIcon: Icon(Icons.description, color: _pinkColor),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: _pinkColor),
                            ),
                            labelStyle: TextStyle(color: _pinkColor),
                          ),
                          maxLines: 3,
                          maxLength: 200,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _cityController,
                          decoration: InputDecoration(
                            labelText: '城市',
                            border: const OutlineInputBorder(),
                            prefixIcon: Icon(Icons.location_on, color: _pinkColor),
                            hintText: '如:北京、上海',
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: _pinkColor),
                            ),
                            labelStyle: TextStyle(color: _pinkColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 角色选择
            _buildRoleSelector(),
            const SizedBox(height: 16),

            // Coser 等级选择
            _buildCosLevelSelector(),
            const SizedBox(height: 32),

            // 保存按钮
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _pinkColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Text(
                  '保存修改',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}