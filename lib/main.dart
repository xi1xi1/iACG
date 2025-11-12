import 'package:flutter/material.dart';
import 'core/supabase_client.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Supabase
  await AppSupabaseClient().initialize();

  runApp(const MyApp());
  
}
