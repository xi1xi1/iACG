import 'package:flutter/material.dart';
import 'package:iacg/features/messages/message_list_page.dart'; // 导入消息页面
import 'package:iacg/features/profile/following_list_page.dart';
import 'package:iacg/features/root/root_shell.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart'; // 导入认证服务
import '../../services/profile_service.dart';
import '../../services/password_service.dart'; // 导入密码服务
import '../../widgets/avatar_widget.dart'; // 导入 AvatarWidget
import 'edit_profile_page.dart';
import 'my_posts_tab.dart';
import 'my_island_tab.dart';
import 'my_favorites_tab.dart';
import 'my_collab_tab.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage>
    with SingleTickerProviderStateMixin {
  final ProfileService _profileService = ProfileService();
  final AuthService _authService = AuthService(); // 添加认证服务
  final PasswordService _passwordService = PasswordService(); // 添加密码服务
  UserProfile? _profile;
  Map<String, int>? _stats;
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _currentSearchQuery = '';

  // 控制搜索框显示状态
  bool _showSearchField = false;

  // 密码修改相关变量
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isPasswordChanging = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _profile == null) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final profile = await _profileService.fetchMyProfile();
      if (profile == null) {
        throw Exception('无法获取用户信息');
      }
      final stats = await _profileService.fetchUserStats(profile.id);
      setState(() {
        _profile = profile;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出登录吗?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '退出',
              style: TextStyle(color: Color(0xFFED7099)),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFED7099)),
          ),
        ),
      );

      await _profileService.signOut();

      if (!mounted) return;
      Navigator.pop(context);

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const RootShell(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('退出失败: $e')),
        );
      }
    }
  }

  // 显示登录提示
  void _showLoginPrompt(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          '登录提示',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF666666),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF666666),
            ),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushNamed('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFED7099),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('去登录'),
          ),
        ],
      ),
    );
  }

  // 处理消息按钮点击
  void _handleMessageButtonTap() {
    // 检查用户是否登录
    if (!_authService.isLoggedIn) {
      _showLoginPrompt('查看消息需要登录');
      return;
    }

    // 跳转到消息页面
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MessageListPage()),
    );
  }

  void _performSearch(String query) {
    setState(() {
      _currentSearchQuery = query;
    });

    if (query.isEmpty) {
      return;
    }

    _notifyCurrentTabOfSearch(query);
  }

  void _notifyCurrentTabOfSearch(String query) {
    // 可以通知当前选中的tab进行搜索
    // 实际搜索逻辑在各个tab中实现
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _currentSearchQuery = '';
      _showSearchField = false;
    });
    _notifyCurrentTabOfSearch('');
    FocusScope.of(context).unfocus();
  }

  void _onSearchSubmitted(String value) {
    if (value.trim().isNotEmpty) {
      _performSearch(value.trim());
      FocusScope.of(context).unfocus();
    }
  }

  void _toggleSearchField() {
    setState(() {
      _showSearchField = !_showSearchField;
      if (!_showSearchField) {
        _searchController.clear();
        _currentSearchQuery = '';
        _notifyCurrentTabOfSearch('');
      }
    });

    if (_showSearchField) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          FocusScope.of(context).requestFocus(FocusNode());
          FocusScope.of(context)
              .requestFocus(_searchController.selection.extentOffset == 0
                  ? _searchController.selection.baseOffset == 0
                      ? FocusNode()
                      : null
                  : null);
        }
      });
    }
  }

  String _getSearchHintText() {
    switch (_tabController.index) {
      case 0:
        return '搜索作品...';
      case 1:
        return '搜索群岛...';
      case 2:
        return '搜索收藏...';
      case 3:
        return '搜索共创...';
      default:
        return '搜索...';
    }
  }

  // 显示修改密码对话框
  void _showChangePasswordDialog() {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return _buildPasswordChangeSheet(context);
      },
    );
  }

  Widget _buildPasswordChangeSheet(BuildContext context) {
    bool isCurrentPasswordVisible = false;
    bool isNewPasswordVisible = false;
    bool isConfirmPasswordVisible = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 顶部拖拽指示器
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 标题
                  const Text(
                    '修改密码',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '为了账号安全，请设置强密码',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 当前密码
                  TextField(
                    controller: _currentPasswordController,
                    obscureText: !isCurrentPasswordVisible,
                    decoration: InputDecoration(
                      labelText: '当前密码',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          isCurrentPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(() {
                          isCurrentPasswordVisible = !isCurrentPasswordVisible;
                        }),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFED7099)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 新密码
                  TextField(
                    controller: _newPasswordController,
                    obscureText: !isNewPasswordVisible,
                    decoration: InputDecoration(
                      labelText: '新密码',
                      prefixIcon: const Icon(Icons.lock_reset, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          isNewPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(() {
                          isNewPasswordVisible = !isNewPasswordVisible;
                        }),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFED7099)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 密码强度提示
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _newPasswordController,
                    builder: (context, value, child) {
                      if (value.text.isEmpty) return const SizedBox();

                      final isValid =
                          _passwordService.isPasswordValid(value.text);
                      return Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          isValid ? '✓ 密码长度足够' : '⚠ 密码长度需至少6位',
                          style: TextStyle(
                            fontSize: 12,
                            color: isValid ? Colors.green : Colors.orange,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // 确认新密码
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: !isConfirmPasswordVisible,
                    decoration: InputDecoration(
                      labelText: '确认新密码',
                      prefixIcon: const Icon(Icons.lock_reset, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          isConfirmPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(() {
                          isConfirmPasswordVisible = !isConfirmPasswordVisible;
                        }),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFED7099)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 按钮区域
                  Row(
                    children: [
                      // 取消按钮
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isPasswordChanging
                              ? null
                              : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // 确认按钮
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isPasswordChanging
                              ? null
                              : () => _handlePasswordChange(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFED7099),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isPasswordChanging
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Text('确认修改'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 处理密码修改逻辑
  Future<void> _handlePasswordChange(BuildContext context) async {
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // 验证输入
    if (currentPassword.isEmpty) {
      _showErrorSnackBar('请输入当前密码');
      return;
    }

    if (newPassword.isEmpty) {
      _showErrorSnackBar('请输入新密码');
      return;
    }

    if (!_passwordService.isPasswordValid(newPassword)) {
      _showErrorSnackBar('密码长度不足，请确保密码至少6位');
      return;
    }

    if (confirmPassword.isEmpty) {
      _showErrorSnackBar('请确认新密码');
      return;
    }

    if (newPassword != confirmPassword) {
      _showErrorSnackBar('两次输入的新密码不一致');
      return;
    }

    if (newPassword == currentPassword) {
      _showErrorSnackBar('新密码不能与当前密码相同');
      return;
    }

    try {
      setState(() {
        _isPasswordChanging = true;
      });

      // 使用 Supabase 更新密码
      await _passwordService.updatePassword(newPassword);

      // 清除表单
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      // 关闭对话框
      if (mounted) {
        Navigator.pop(context);

        // 显示成功提示
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('密码修改成功'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('密码修改失败: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPasswordChanging = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFED7099)),
          ),
        ),
      );
    }

    if (_error != null || _profile == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 64, color: Color(0xFFED7099)),
              const SizedBox(height: 16),
              Text(
                '加载失败: $_error',
                style: const TextStyle(color: Color(0xFFED7099)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              pinned: true,
              floating: false,
              snap: false,
              expandedHeight: 400,
              backgroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildProfileHeader(),
                collapseMode: CollapseMode.parallax,
              ),
              title: const SizedBox.shrink(),
              centerTitle: false,
              elevation: 0,
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(_showSearchField ? 96 : 48),
                child: _buildTabBarWithSearch(),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            MyPostsTab(userId: _profile!.id, searchQuery: _currentSearchQuery),
            MyIslandTab(userId: _profile!.id, searchQuery: _currentSearchQuery),
            MyFavoritesTab(
                userId: _profile!.id, searchQuery: _currentSearchQuery),
            MyCollabTab(userId: _profile!.id, searchQuery: _currentSearchQuery),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBarWithSearch() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // TabBar和搜索图标在一行
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // TabBar部分 - 占据大部分空间
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFFED7099),
                    labelColor: const Color(0xFFED7099),
                    unselectedLabelColor: Colors.grey[600],
                    indicatorSize: TabBarIndicatorSize.label,
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                    tabs: const [
                      Tab(text: '作品'),
                      Tab(text: '群岛'),
                      Tab(text: '收藏'),
                      Tab(text: '共创'),
                    ],
                    isScrollable: true,
                  ),
                ),

                // 搜索图标按钮 - 右侧
                IconButton(
                  icon: Icon(
                    _showSearchField ? Icons.close : Icons.search,
                    color: _showSearchField
                        ? const Color(0xFFED7099)
                        : Colors.grey[600],
                    size: 22,
                  ),
                  onPressed: _toggleSearchField,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
              ],
            ),
          ),

          // 搜索框区域（展开/收起动画）
          if (_showSearchField)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(Icons.search,
                        color: const Color(0xFFED7099), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: _getSearchHintText(),
                          hintStyle: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 13),
                        onChanged: _performSearch,
                        onSubmitted: _onSearchSubmitted,
                      ),
                    ),
                    if (_currentSearchQuery.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.close,
                            size: 18, color: Colors.grey[600]),
                        onPressed: _clearSearch,
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                      ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),

          // 分隔线
          Container(
            height: 1,
            color: Colors.grey[100],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头像和基本信息行 - 使用交叉轴起始对齐，让内容往下移动
            Row(
              crossAxisAlignment: CrossAxisAlignment.center, // 改为居中对齐
              children: [
                // 头像 - 使用 AvatarWidget
                AvatarWidget(
                  imageUrl: _profile!.avatarUrl,
                  size: 80,
                  showBorder: false,
                  semanticsLabel: '${_profile!.nickname}的头像',
                ),
                const SizedBox(width: 16),

                // 昵称、ID和徽章 - 使用 Column 包裹，增加垂直间距
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 在昵称上方添加间距
                      const SizedBox(height: 8),

                      // 昵称和徽章在一行
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              _profile!.nickname,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 徽章放在昵称右边
                          if (_profile!.isCoser || _profile!.role != 'user')
                            _buildRoleBadges(),
                        ],
                      ),
                      const SizedBox(height: 8), // 增加昵称和ID之间的间距
                      Text(
                        'ID: ${_profile!.id}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 头像下面的三个按钮：编辑资料、消息、设置
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 编辑资料按钮
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              EditProfilePage(profile: _profile!),
                        ),
                      );
                      if (result == true) {
                        _loadData();
                      }
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text(
                      '编辑资料',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFED7099),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFED7099)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 消息按钮 - 使用和首页相同的信封图标
                SizedBox(
                  width: 56,
                  child: ElevatedButton(
                    onPressed: _handleMessageButtonTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFED7099),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFED7099)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                    child: Icon(
                      Icons.markunread_outlined, // 这个图标非常好看！
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 设置按钮 - 改为粉色边框和粉色图标
                SizedBox(
                  width: 56,
                  child: ElevatedButton(
                    onPressed: _showSettingsMenu,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFED7099), // 改为粉色
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(
                            color: Color(0xFFED7099)), // 改为粉色边框
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                    child: const Icon(Icons.settings, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 统计数据行
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('作品', _stats?['posts'] ?? 0),
                _buildStatItem('关注', _stats?['following'] ?? 0),
                _buildStatItem('粉丝', _stats?['followers'] ?? 0),
              ],
            ),
            const SizedBox(height: 10),

            // 个人简介内容（不显示标题）
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xffF8F9FA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _profile!.bio != null && _profile!.bio!.isNotEmpty
                    ? _profile!.bio!
                    : '这个人很神秘，什么都没有写',
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // IP地址/地点信息
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 16, color: const Color(0xFFED7099)),
                const SizedBox(width: 6),
                Text(
                  _profile!.city != null && _profile!.city!.isNotEmpty
                      ? _profile!.city!
                      : '未知',
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 显示设置菜单
  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部拖拽指示器
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // 设置选项标题
              const Text(
                '设置',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 24),

              // 修改密码选项
              ListTile(
                leading:
                    const Icon(Icons.lock_outline, color: Color(0xFFED7099)),
                title: const Text(
                  '修改密码',
                  style: TextStyle(fontSize: 16),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showChangePasswordDialog();
                },
              ),

              // 退出登录选项
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  '退出登录',
                  style: TextStyle(fontSize: 16, color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _handleSignOut();
                },
              ),

              const SizedBox(height: 16),

              // 取消按钮
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                      foregroundColor: Colors.grey[700],
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('取消'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // 徽章布局，放在昵称右边 - 与用户界面完全一致
  Widget _buildRoleBadges() {
    List<Widget> badges = [];

    if (_profile!.isCoser) {
      badges.add(_buildRoleBadge(
        'Coser',
        Icons.camera_alt,
      ));
      if (_profile!.cosLevel != 'none' &&
          _profile!.displayCosLevel.isNotEmpty) {
        badges.add(const SizedBox(width: 8));
        badges.add(_buildRoleBadge(
          _profile!.displayCosLevel,
          Icons.star,
        ));
      }
    } else if (_profile!.role != 'user') {
      badges.add(_buildRoleBadge(
        _profile!.displayRole,
        _getRoleIcon(_profile!.role),
      ));
    }

    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: badges,
    );
  }

  // 徽章样式 - 与用户界面完全一致
  Widget _buildRoleBadge(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFED7099),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // 获取角色图标
  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'coser':
        return Icons.camera_alt;
      case 'creator_support':
        return Icons.palette;
      case 'organizer':
        return Icons.event;
      default:
        return Icons.person;
    }
  }

  Widget _buildStatItem(String label, int count) {
    return GestureDetector(
      onTap: () {
        if (label == '关注') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FollowingListPage(userId: _profile!.id),
            ),
          );
        } else if (label == '粉丝') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FollowersListPage(userId: _profile!.id),
            ),
          );
        }
      },
      child: Column(
        children: [
          Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
