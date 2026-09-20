import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/security/crypto_helper.dart';

class SmsScreen extends StatefulWidget {
  final Map<String, dynamic> device;

  const SmsScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<SmsScreen> createState() => _SmsScreenState();
}

class _SmsScreenState extends State<SmsScreen> {
  bool _isLoading = true;
  List<dynamic> _messages = [];

  @override
  void initState() {
    super.initState();
    _fetchSms();
  }

  Future<void> _fetchSms() async {
    setState(() => _isLoading = true);
    final deviceId = widget.device['id'];
    try {
      final res = await ApiClient.get(ApiConstants.smsUrl(deviceId));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body);
        if (list is List) {
          setState(() => _messages = list);
        }
      }
    } catch (e) {
      // Ignored
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestRefreshFromDevice() async {
    final deviceId = widget.device['id'];
    try {
      await ApiClient.post(ApiConstants.commandUrl(deviceId), {
        'action': 'FETCH_SMS',
        'params': {},
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم طلب مزامنة الرسائل من هاتف الطفل...'), backgroundColor: Colors.blue),
      );
      await Future.delayed(const Duration(seconds: 2));
      _fetchSms();
    } catch (e) {
      // Ignored
    }
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '';
    try {
      final intVal = ts is int ? ts : int.tryParse(ts.toString()) ?? 0;
      final dt = DateTime.fromMillisecondsSinceEpoch(intVal);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final childName = widget.device['child']?['name'] ?? widget.device['device_name'] ?? 'Child';

    return Scaffold(
      appBar: AppBar(
        title: Text('رسائل SMS - $childName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث الرسائل',
            onPressed: _requestRefreshFromDevice,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mark_chat_unread_outlined, size: 64, color: Colors.grey.shade600),
                      const SizedBox(height: 16),
                      const Text('لا توجد رسائل SMS مسجلة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('انقر فوق زر التحديث لجلب الرسائل من هاتف الطفل', style: TextStyle(color: Colors.grey.shade400)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _requestRefreshFromDevice,
                        icon: const Icon(Icons.refresh),
                        label: const Text('جلب الرسائل الآن'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (context, idx) {
                    final msg = _messages[idx];
                    final isIncoming = msg['is_incoming'] != false;
                    final sender = msg['sender'] ?? 'Unknown';
                    final body = msg['body'] ?? '';
                    final timeStr = _formatTimestamp(msg['timestamp']);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isIncoming ? Icons.call_received : Icons.call_made,
                                      size: 16,
                                      color: isIncoming ? Colors.cyanAccent : Colors.orangeAccent,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      sender,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (isIncoming ? Colors.cyanAccent : Colors.orangeAccent).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isIncoming ? 'واردة (Incoming)' : 'صادرة (Sent)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isIncoming ? Colors.cyanAccent : Colors.orangeAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            FutureBuilder<String>(
                              future: CryptoHelper.decrypt(body),
                              builder: (context, snapshot) {
                                return Text(
                                  snapshot.data ?? body,
                                  style: const TextStyle(fontSize: 14, height: 1.3),
                                );
                              },
                            ),
                            if (timeStr.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.bottomLeft,
                                child: Text(
                                  timeStr,
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                ),
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
