import '../core/supabase_client.dart';

class EventService {
  final _client = AppSupabaseClient().client;

  // 获取即将开始的活动
  Future<List<Map<String, dynamic>>> fetchUpcomingEvents() async {
    final response = await _client
        .from('events')
        .select('*')
        .gte('start_time', DateTime.now().toIso8601String())
        .order('start_time', ascending: true)
        .limit(10);

    return (response as List).cast<Map<String, dynamic>>();
  }

  // 获取所有活动
  Future<List<Map<String, dynamic>>> fetchAllEvents() async {
    final response = await _client
        .from('events')
        .select('*')
        .order('start_time', ascending: false)
        .limit(20);

    return (response as List).cast<Map<String, dynamic>>();
  }

  // 按城市筛选活动
  Future<List<Map<String, dynamic>>> fetchEventsByCity(String city) async {
    final response = await _client
        .from('events')
        .select('*')
        .eq('city', city)
        .gte('start_time', DateTime.now().toIso8601String())
        .order('start_time', ascending: true);

    return (response as List).cast<Map<String, dynamic>>();
  }
}
