import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/websocket_service.dart';

class CallsScreen extends StatefulWidget {
  final Map<String, dynamic> device;

  const CallsScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  bool _isLoading = true;
  List<dynamic> _calls = [];

  @override
  void initState() {
    super.initState();
    _fetchCalls();
    _listenToWs();
  }

  void _listenToWs() {
    try {
      WebSocketService().messageStream.listen((msg) {
        if (!mounted) return;
        if (msg['type'] == 'CALLS_SYNC') {
          final payload = msg['payload'];
          if (payload is List) {
            setState(() {
              _calls = payload;
              _isLoading = false;
            });
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _fetchCalls() async {
    setState(() => _isLoading = true);
    final deviceId = widget.device['id'];
    try {
      final res = await ApiClient.get(ApiConstants.callsUrl(deviceId));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body);
        if (list is List) {
          setState(() => _calls = list);
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
        'action': 'FETCH_CALLS',
        'params': {},
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم طلب مزامنة سجل المكالمات من هاتف الطفل...'),
          backgroundColor: Colors.blue,
        ),
      );
      await Future.delayed(const Duration(seconds: 2));
      _fetchCalls();
    } catch (e) {
      // Ignored
    }
  }

  String _formatDuration(dynamic secVal) {
    final sec = secVal is int ? secVal : int.tryParse(secVal?.toString() ?? '0') ?? 0;
    if (sec <= 0) return '0 ثانية';
    final m = sec ~/ 60;
    final s = sec % 60;
    if (m > 0 && s > 0) return '$m د و $s ث';
    if (m > 0) return '$m دقيقة';
    return '$s ثانية';
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
        title: Text('سجل المكالمات - $childName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث سجل المكالمات',
            onPressed: _requestRefreshFromDevice,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _calls.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.phone_missed_outlined, size: 64, color: Colors.grey.shade600),
                      const SizedBox(height: 16),
                      const Text('لا توجد مكالمات مسجلة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('انقر فوق زر التحديث لجلب السجل من هاتف الطفل', style: TextStyle(color: Colors.grey.shade400)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _requestRefreshFromDevice,
                        icon: const Icon(Icons.refresh),
                        label: const Text('جلب السجل الآن'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _calls.length,
                  itemBuilder: (context, idx) {
                    final call = _calls[idx];
                    final number = call['number'] ?? '';
                    final name = call['name'] as String?;
                    final callType = (call['call_type'] ?? 'INCOMING').toString().toUpperCase();
                    final durationSec = call['duration_seconds'] ?? 0;
                    final timeStr = _formatTimestamp(call['timestamp']);

                    final isUnknown = name == null || name.trim().isEmpty || name.toLowerCase() == 'unknown';

                    IconData typeIcon;
                    Color typeColor;
                    String typeLabel;

                    switch (callType) {
                      case 'OUTGOING':
                        typeIcon = Icons.call_made;
                        typeColor = Colors.blueAccent;
                        typeLabel = 'صادرة';
                        break;
                      case 'MISSED':
                        typeIcon = Icons.call_missed;
                        typeColor = Colors.redAccent;
                        typeLabel = 'فائتة';
                        break;
                      case 'REJECTED':
                        typeIcon = Icons.call_end;
                        typeColor = Colors.orangeAccent;
                        typeLabel = 'مرفوضة';
                        break;
                      case 'INCOMING':
                      default:
                        typeIcon = Icons.call_received;
                        typeColor = Colors.greenAccent;
                        typeLabel = 'واردة';
                        break;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: typeColor.withOpacity(0.18),
                                  child: Icon(typeIcon, color: typeColor, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              isUnknown ? number : name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isUnknown) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.shade900.withOpacity(0.35),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: Colors.amberAccent, width: 0.8),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.warning_amber_rounded, size: 12, color: Colors.amberAccent),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'رقم مجهول',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.amberAccent,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (!isUnknown && number.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          number,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 18),
                                  tooltip: 'نسخ الرقم',
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: number));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('تم نسخ الرقم إلى الحافظة'),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const Divider(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: typeColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        typeLabel,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: typeColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Row(
                                      children: [
                                        Icon(Icons.timer_outlined, size: 14, color: Colors.grey.shade400),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatDuration(durationSec),
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Text(
                                  timeStr,
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
