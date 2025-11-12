import 'package:flutter/material.dart';
import '../../services/event_service.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/empty_view.dart';

class HomeEventsTab extends StatefulWidget {
  const HomeEventsTab({super.key});

  @override
  State<HomeEventsTab> createState() => _HomeEventsTabState();
}

class _HomeEventsTabState extends State<HomeEventsTab> {
  final List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final result = await EventService().fetchUpcomingEvents();
      setState(() {
        _events.clear();
        _events.addAll(result);
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event['name']?.toString() ?? '未知活动',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '${event['city'] ?? '未知城市'} · ${event['location'] ?? '未知地点'}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _formatEventTime(event['start_time'], event['end_time']),
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (event['ticket_url'] != null)
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () {
                    // 打开购票链接
                  },
                  child: const Text('查看详情/购票'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatEventTime(String startTime, String endTime) {
    try {
      final start = DateTime.parse(startTime);
      final end = DateTime.parse(endTime);
      return '${start.month}月${start.day}日 - ${end.month}月${end.day}日';
    } catch (e) {
      return '时间未知';
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const LoadingView()
        : _error != null
            ? ErrorView(error: _error!)
            : _events.isEmpty
                ? const EmptyView()
                : RefreshIndicator(
                    onRefresh: _loadEvents,
                    child: ListView.builder(
                      itemCount: _events.length,
                      itemBuilder: (context, index) {
                        final event = _events[index];
                        return _buildEventCard(event);
                      },
                    ),
                  );
  }
}
