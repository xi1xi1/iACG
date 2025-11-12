import 'package:supabase_flutter/supabase_flutter.dart';

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

