import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../widgets/primary_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _isLogin = true;
Future<void> _submit() async {
  if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请填写邮箱和密码')),
    );
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    if (_isLogin) {
      // 登录逻辑
      await _authService.signInWithEmail(
        _emailController.text,
        _passwordController.text,
      );
      
      // 只有登录成功才跳转到首页
      if (mounted) {
        // Navigator.of(context).pushReplacementNamed('/');
           // ✅ 直接 pop 返回 RootShell
        Navigator.of(context).pop();
      }
    } else {
      // 注册逻辑
      print('📝 [注册流程] 开始注册...');
      await _authService.signUpWithEmail(
        _emailController.text,
        _passwordController.text,
        '新用户',
      );
      
      // 注册成功，显示提示并切换回登录模式
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('注册成功！请登录')),
        );
        setState(() {
          _isLogin = true; // 切换回登录模式
          _emailController.clear();
          _passwordController.clear();
        });
      }
      return; // ⭐⭐⭐ 重要：注册后立即返回，不继续执行 ⭐⭐⭐
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败: $e')),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
  // Future<void> _submit() async {
  //   if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('请填写邮箱和密码')),
  //     );
  //     return;
  //   }

  //   setState(() {
  //     _isLoading = true;
  //   });

  //   try {
  //     if (_isLogin) {
  //       await _authService.signInWithEmail(
  //         _emailController.text,
  //         _passwordController.text,
  //       );
  //     } else {
  //       // 注册逻辑 - 需要昵称
  //       // 这里简化处理，实际应该有一个注册表单
  //       await _authService.signUpWithEmail(
  //         _emailController.text,
  //         _passwordController.text,
  //         '新用户',
  //       );
  //     }

  //     // 登录成功，跳转到首页
  //     if (mounted) {
  //       Navigator.of(context).pushReplacementNamed('/');
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('操作失败: $e')),
  //       );
  //     }
  //   } finally {
  //     if (mounted) {
  //       setState(() {
  //         _isLoading = false;
  //       });
  //     }
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? '登录' : '注册'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            Text(
              _isLogin ? '欢迎回来' : '创建账号',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isLogin ? '登录您的iACG账号' : '加入iACG Cosplay社区',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: '邮箱',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: '密码',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              text: _isLogin ? '登录' : '注册',
              onPressed: _submit,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _isLogin = !_isLogin;
                  });
                },
                child: Text(
                  _isLogin ? '没有账号？立即注册' : '已有账号？立即登录',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
