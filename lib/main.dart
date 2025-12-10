import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/supabase_client.dart';
import 'features/root/root_shell.dart';
import 'features/auth/login_page.dart';
import 'theme/app_theme.dart';

void main() async {
  debugPaintSizeEnabled = false;
  WidgetsFlutterBinding.ensureInitialized();

  // 捕获详细错误信息
  FlutterError.onError = (FlutterErrorDetails details) {
    print('🔥🔥🔥 ==================== Flutter错误 ====================');
    print('错误: ${details.exception}');
    print('📍 堆栈跟踪:');
    print(details.stack);
    print('🔥🔥🔥 ===================================================');
    FlutterError.dumpErrorToConsole(details);
  };

  runZonedGuarded(() async {
    bool isSupabaseInitialized = false;
    String? initError;
    try {
      await AppSupabaseClient().initialize();
      isSupabaseInitialized = true;
      print('✅ Supabase 初始化成功');
    } catch (e) {
      initError = e.toString();
      print('❌ Supabase 初始化失败: $e');
    }

    runApp(MyApp(
      isSupabaseInitialized: isSupabaseInitialized,
      initError: initError,
    ));
  }, (error, stack) {
    print('🔥🔥🔥 ==================== Zone错误 ====================');
    print('错误: $error');
    print('📍 堆栈跟踪:');
    print(stack);
    print('🔥🔥🔥 ===================================================');
  });
}

class MyApp extends StatefulWidget {
  final bool isSupabaseInitialized;
  final String? initError;

  const MyApp({
    super.key,
    required this.isSupabaseInitialized,
    this.initError,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late StreamSubscription<AuthState> _authStateSubscription;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    if (widget.isSupabaseInitialized) {
      _listenToAuthState();
    }
  }

  @override
  void dispose() {
    if (widget.isSupabaseInitialized) {
      _authStateSubscription.cancel();
    }
    super.dispose();
  }

  void _listenToAuthState() {
    final supabaseClient = AppSupabaseClient().client;

    _authStateSubscription = supabaseClient.auth.onAuthStateChange.listen(
      (AuthState state) {
        print('🔄 认证状态变化: ${state.event}');
        
        setState(() {
          _currentUser = state.session?.user;
        });

        if (state.event == 'SIGNED_OUT') {
          print('✅ 用户已退出登录');
        }
        
        if (state.event == 'SIGNED_IN') {
          print('✅ 用户已登录: ${state.session?.user.id}');
        }
      },
      onError: (error) {
        print('❌ 认证监听失败: $error');
      },
    );

    // 检查初始用户状态
    final initialUser = supabaseClient.auth.currentUser;
    print('🔍 初始用户状态: ${initialUser?.id ?? "未登录"}');
    
    setState(() {
      _currentUser = initialUser;
    });
  }

  Widget _getInitialPage() {
    if (!widget.isSupabaseInitialized) {
      return _buildErrorPage('App 初始化失败', '原因: ${widget.initError}');
    }

    // ✅ 核心逻辑：总是进入首页，无论登录状态
    print('✅ 启动应用，直接显示首页(无需登录)');
    return const RootShell();
  }

  Widget _buildErrorPage(String title, String message) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text(message, 
                 style: const TextStyle(color: Colors.red, fontSize: 12),
                 textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                runApp(MyApp(
                  isSupabaseInitialized: widget.isSupabaseInitialized,
                  initError: widget.initError,
                ));
              },
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iACG Cosplay',
      //theme: ThemeData(primarySwatch: Colors.blue),
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: _getInitialPage(),
      routes: {
        '/login': (context) => const LoginPage(),
      },
    );
  }
}
// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'core/supabase_client.dart';
// import 'features/root/root_shell.dart';
// import 'features/auth/login_page.dart';
// import 'dart:async';
// import 'package:flutter/material.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   // ✅ 添加这段 - 捕获详细错误信息
//   FlutterError.onError = (FlutterErrorDetails details) {
//     print('🔥🔥🔥 ==================== Flutter错误 ====================');
//     print('错误: ${details.exception}');
//     print('📍 堆栈跟踪:');
//     print(details.stack);
//     print('🔥🔥🔥 ===================================================');
//     FlutterError.dumpErrorToConsole(details);
//   };

//   runZonedGuarded(() async {
//     // 你原来的初始化代码
//     bool isSupabaseInitialized = false;
//     String? initError;
//     try {
//       await AppSupabaseClient().initialize();
//       isSupabaseInitialized = true;
//       print('✅ Supabase 初始化成功');
//     } catch (e) {
//       initError = e.toString();
//       print('❌ Supabase 初始化失败: $e');
//     }

//     runApp(MyApp(
//       isSupabaseInitialized: isSupabaseInitialized,
//       initError: initError,
//     ));
//   }, (error, stack) {
//     print('🔥🔥🔥 ==================== Zone错误 ====================');
//     print('错误: $error');
//     print('📍 堆栈跟踪:');
//     print(stack);
//     print('🔥🔥🔥 ===================================================');
//   });
// }

// class MyApp extends StatefulWidget {
//   final bool isSupabaseInitialized;
//   final String? initError;

//   const MyApp({
//     super.key,
//     required this.isSupabaseInitialized,
//     this.initError,
//   });

//   @override
//   State<MyApp> createState() => _MyAppState();
// }

// class _MyAppState extends State<MyApp> {
//   late StreamSubscription<AuthState> _authStateSubscription;
//   User? _currentUser;

//   @override
//   void initState() {
//     super.initState();
//     if (widget.isSupabaseInitialized) {
//       _listenToAuthState();
//     }
//   }

//   @override
//   void dispose() {
//     if (widget.isSupabaseInitialized) {
//       _authStateSubscription.cancel();
//     }
//     super.dispose();
//   }

//   void _listenToAuthState() {
//     final supabaseClient = AppSupabaseClient().client;

//     _authStateSubscription = supabaseClient.auth.onAuthStateChange.listen(
//       (AuthState state) {
//         print('🔄 认证状态变化: ${state.event}');
        
//         setState(() {
//           _currentUser = state.session?.user;
//         });

//         // 如果用户退出登录,不做任何跳转,保持在当前页面
//         if (state.event == 'SIGNED_OUT') {
//           print('✅ 用户已退出登录');
//         }
        
//         // 如果用户登录成功,也不做跳转,只更新状态
//         if (state.event == 'SIGNED_IN') {
//           print('✅ 用户已登录: ${state.session?.user.id}');
//         }
//       },
//       onError: (error) {
//         print('❌ 认证监听失败: $error');
//       },
//     );

//     // 检查初始用户状态
//     final initialUser = supabaseClient.auth.currentUser;
//     print('🔍 初始用户状态: ${initialUser?.id ?? "未登录"}');
    
//     setState(() {
//       _currentUser = initialUser;
//     });
//   }

//   Widget _getInitialPage() {
//     if (!widget.isSupabaseInitialized) {
//       return _buildErrorPage('App 初始化失败', '原因: ${widget.initError}');
//     }

//     // ✅ 核心改动:直接进入 RootShell,不再检查登录状态
//     print('✅ 启动应用,直接显示首页(无需登录)');
//     return const RootShell();
//   }

//   Widget _buildErrorPage(String title, String message) {
//     return Scaffold(
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Icon(Icons.error_outline, size: 64, color: Colors.red),
//             const SizedBox(height: 16),
//             Text(title, style: const TextStyle(fontSize: 18)),
//             const SizedBox(height: 8),
//             Text(message, 
//                  style: const TextStyle(color: Colors.red, fontSize: 12),
//                  textAlign: TextAlign.center),
//             const SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: () {
//                 // 重启应用
//                 runApp(MyApp(
//                   isSupabaseInitialized: widget.isSupabaseInitialized,
//                   initError: widget.initError,
//                 ));
//               },
//               child: const Text('重试'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'iACG Cosplay',
//       theme: ThemeData(primarySwatch: Colors.blue),
//       debugShowCheckedModeBanner: false,
//       home: _getInitialPage(),
//       routes: {
//         '/login': (context) => const LoginPage(),
//       },
//     );
//   }
// }