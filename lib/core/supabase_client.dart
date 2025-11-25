/* import 'package:supabase_flutter/supabase_flutter.dart';

class AppSupabaseClient {
  static final AppSupabaseClient _instance = AppSupabaseClient._internal();
  factory AppSupabaseClient() => _instance;
  AppSupabaseClient._internal();

  static const String supabaseUrl = 'https://vzxrqxyoshkvwoaxzjzc.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ6eHJxeHlvc2hrdndvYXh6anpjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIyNDUzNjksImV4cCI6MjA3NzgyMTM2OX0.izPo42wmWdIYQc0dGA8Z0gRP3ZHdyFelnS0oZMcYG7s';

  Future<void> initialize() async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  SupabaseClient get client => Supabase.instance.client;
}

 */

import 'package:supabase_flutter/supabase_flutter.dart';

class AppSupabaseClient {
  static final AppSupabaseClient _instance = AppSupabaseClient._internal();
  factory AppSupabaseClient() => _instance;
  AppSupabaseClient._internal();

  static const String supabaseUrl = 'https://vzxrqxyoshkvwoaxzjzc.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ6eHJxeHlvc2hrdndvYXh6anpjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIyNDUzNjksImV4cCI6MjA3NzgyMTM2OX0.izPo42wmWdIYQc0dGA8Z0gRP3ZHdyFelnS0oZMcYG7s';

  // 新增：标记初始化是否完成（默认未完成）
  bool _isInitialized = false;
  // 新增：初始化完成的 Future，供外部等待
  Future<void>? _initializeFuture;

  /// 初始化 Supabase（确保全局只执行一次）
  Future<void> initialize() async {
    // 若已初始化或正在初始化，直接返回，避免重复调用
    if (_initializeFuture != null) return _initializeFuture!;
    
    _initializeFuture = _doInitialize();
    return _initializeFuture!;
  }

  /// 实际的初始化逻辑（私有，避免外部直接调用）
  Future<void> _doInitialize() async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    // 初始化完成后，标记状态
    _isInitialized = true;
    print('✅ Supabase 初始化完成');
  }

  /// 获取 SupabaseClient（确保初始化完成后才返回）
  SupabaseClient get client {
    if (!_isInitialized) {
      throw Exception(
        '❌ Supabase 尚未初始化！请先调用 AppSupabaseClient().initialize() 并等待完成',
      );
    }
    return Supabase.instance.client;
  }
}