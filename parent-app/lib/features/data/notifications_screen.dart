import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/websocket_service.dart';

class NotificationsScreen extends StatefulWidget {
  final Map<String, dynamic> device;

  const NotificationsScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<dynamic> _notifications = [];
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    _listenLiveNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    final deviceId = widget.device['id'];
    try {
      final res = await ApiClient.get(ApiConstants.deviceNotifsUrl(deviceId));
      if (res.statusCode == 200) {
        final list = jsonDecode(utf8.decode(res.bodyBytes));
        if (list is List) {
          setState(() => _notifications = list);
        }
      }
    } catch (e) {
      // Ignored
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _listenLiveNotifications() {
    _wsSub = WebSocketService().messageStream.listen((msg) {
      if (msg['type'] == 'NOTIFICATION_FORWARD') {
        final payload = msg['payload'];
        if (payload != null) {
          final notif = payload is String ? jsonDecode(payload) : payload;
          setState(() {
            _notifications.insert(0, notif);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr.toString()).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final childName = widget.device['child']?['name'] ?? widget.device['device_name'] ?? 'Child';

    return Scaffold(
      appBar: AppBar(
        title: Text('إشعارات هاتف - $childName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.shade600),
                      const SizedBox(height: 16),
                      const Text('لا توجد إشعارات مسجلة بعد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        'عندما يتلقى هاتف الطفل إشعارات من تطبيقات مثل واتساب وتيليجرام وغيرها، ستظهر هنا فوراً',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _notifications.length,
                  itemBuilder: (context, idx) {
                    final notif = _notifications[idx];
                    final appName = notif['app_name'] ?? notif['package_name'] ?? 'App';
                    final title = notif['title'] ?? '';
                    final content = notif['content'] ?? '';
                    final time = _formatDate(notif['received_at'] ?? notif['created_at']);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    appName,
                                    style: const TextStyle(
                                      color: Colors.purpleAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  time,
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                            if (title.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                            if (content.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                content,
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade300),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
