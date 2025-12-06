import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'features/root/root_shell.dart';
import 'features/auth/login_page.dart';
import 'features/messages/message_list_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iACG Cosplay',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const RootShell(), // 直接进入首页，不强制登录
      routes: {
        '/login': (context) => const LoginPage(),
      },
    );
  }
}
