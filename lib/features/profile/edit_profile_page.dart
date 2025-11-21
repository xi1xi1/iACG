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
}