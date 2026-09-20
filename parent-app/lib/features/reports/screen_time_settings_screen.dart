import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/websocket_service.dart';

class ScreenTimeSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> device;

  const ScreenTimeSettingsScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<ScreenTimeSettingsScreen> createState() => _ScreenTimeSettingsScreenState();
}

class _ScreenTimeSettingsScreenState extends State<ScreenTimeSettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isActive = true;
  int _dailyLimitMinutes = 120; // 2 hours default
  TimeOfDay _bedtimeStart = const TimeOfDay(hour: 21, minute: 0);
  TimeOfDay _bedtimeEnd = const TimeOfDay(hour: 7, minute: 0);

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    setState(() => _isLoading = true);
    final deviceId = widget.device['id'];
    try {
      final res = await ApiClient.get(ApiConstants.screenTimeRulesUrl(deviceId));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _dailyLimitMinutes = data['daily_limit_minutes'] ?? 120;
          _isActive = data['is_active'] ?? true;
          if (data['downtime_start'] != null) {
            final parts = (data['downtime_start'] as String).split(':');
            if (parts.length == 2) {
              _bedtimeStart = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
            }
          }
          if (data['downtime_end'] != null) {
            final parts = (data['downtime_end'] as String).split(':');
            if (parts.length == 2) {
              _bedtimeEnd = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
            }
          }
        });
      }
    } catch (e) {
      // Use defaults
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    final deviceId = widget.device['id'];
    final body = {
      'daily_limit_minutes': _dailyLimitMinutes,
      'downtime_start': _formatTimeOfDay(_bedtimeStart),
      'downtime_end': _formatTimeOfDay(_bedtimeEnd),
      'is_active': _isActive,
    };

    try {
      final res = await ApiClient.post(ApiConstants.screenTimeRulesUrl(deviceId), body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        // Also send direct WS sync message
        WebSocketService().sendMessage(
          'SCREEN_TIME_RULE_SYNC',
          to: deviceId,
          payload: body,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ تم حفظ قواعد وقت الشاشة وجدول النوم وإرسالها للطفل بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Server returned ${res.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في حفظ الإعدادات: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final childName = widget.device['child']?['name'] ?? widget.device['device_name'] ?? 'Child';

    return Scaffold(
      appBar: AppBar(
        title: Text('جدول النوم ووقت الشاشة - $childName'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.bedtime, color: Colors.indigoAccent, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'تفعيل إدارة وقت الشاشة الذكية',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'قفل الشاشة تلقائياً أثناء ساعات النوم وعند استنفاد الحد اليومي',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isActive,
                        activeColor: Colors.indigoAccent,
                        onChanged: (val) => setState(() => _isActive = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Bedtime Schedule Section
                _buildSectionHeader('جدول وقت النوم (Bedtime Downtime)', Icons.nightlight_round, Colors.amberAccent),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.bedtime, color: Colors.amberAccent),
                          title: const Text('بداية وقت النوم (قفل الجهاز)'),
                          trailing: OutlinedButton(
                            onPressed: () async {
                              final picked = await showTimePicker(context: context, initialTime: _bedtimeStart);
                              if (picked != null) setState(() => _bedtimeStart = picked);
                            },
                            child: Text(_bedtimeStart.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.wb_sunny, color: Colors.orangeAccent),
                          title: const Text('نهاية وقت النوم (فتح الجهاز)'),
                          trailing: OutlinedButton(
                            onPressed: () async {
                              final picked = await showTimePicker(context: context, initialTime: _bedtimeEnd);
                              if (picked != null) setState(() => _bedtimeEnd = picked);
                            },
                            child: Text(_bedtimeEnd.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Daily Limit Section
                _buildSectionHeader('الحد اليومي الإجمالي للاستخدام', Icons.timer, Colors.cyanAccent),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('الحد الأقصى اليومي:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            Text(
                              '${_dailyLimitMinutes ~/ 60} ساعة و ${_dailyLimitMinutes % 60} دقيقة',
                              style: const TextStyle(fontSize: 15, color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Slider(
                          value: _dailyLimitMinutes.toDouble(),
                          min: 30,
                          max: 480,
                          divisions: 15,
                          label: '$_dailyLimitMinutes دقيقة',
                          activeColor: Colors.cyanAccent,
                          onChanged: (val) => setState(() => _dailyLimitMinutes = val.toInt()),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('30 دقيقة', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                            Text('8 ساعات', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Save Button
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveSettings,
                  icon: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'جارٍ الحفظ...' : 'حفظ وتطبيق القواعد فوراً'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigoAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey.shade200)),
      ],
    );
  }
}
