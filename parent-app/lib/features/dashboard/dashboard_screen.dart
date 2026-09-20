import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/websocket_service.dart';
import '../../core/security/crypto_helper.dart';
import '../auth/login_screen.dart';
import '../location/live_map_screen.dart';
import '../pairing/add_device_dialog.dart';
import 'device_control_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _devices = [];
  Map<String, dynamic>? _subscription;
  bool _isLoading = true;
  StreamSubscription? _wsSubscription;
  Timer? _screenshotTimeoutTimer;

  bool get _isSubExpired =>
      _subscription != null &&
      (_subscription!['is_expired'] == true || _subscription!['status'] != 'active');

  @override
  void initState() {
    super.initState();
    _loadDevices();
    _listenToLiveStatus();
  }

  Future<void> _loadDevices() async {
    try {
      final res = await ApiClient.get(ApiConstants.devicesUrl);
      if (res.statusCode == 200) {
        final devs = jsonDecode(utf8.decode(res.bodyBytes));
        if (devs is List) {
          setState(() {
            _devices = devs;
          });
        }
      }

      final subRes = await ApiClient.get(ApiConstants.mySubscriptionUrl);
      if (subRes.statusCode == 200) {
        setState(() {
          _subscription = jsonDecode(subRes.body);
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _listenToLiveStatus() {
    _wsSubscription = WebSocketService().messageStream.listen((msg) {
      if (!mounted) return;
      final type = msg['type'];
      final from = msg['from'];

      if (type == 'MONITORING_STATUS_CHANGED') {
        try {
          final payload = msg['payload'] is String ? jsonDecode(msg['payload']) : msg['payload'];
          final devId = payload?['device_id'] ?? msg['from'];
          final isPaused = payload?['is_monitoring_paused'] == true;
          if (devId != null) {
            setState(() {
              for (var d in _devices) {
                if (d['id'] == devId) {
                  d['is_monitoring_paused'] = isPaused;
                }
              }
            });
          }
        } catch (_) {}
      }

      if (type == 'DEVICE_ONLINE' || type == 'DEVICE_OFFLINE' || type == 'HEARTBEAT_PING') {
        setState(() {
          for (var d in _devices) {
            if (d['id'] == from) {
              if (type == 'DEVICE_ONLINE') d['status'] = 'online';
              if (type == 'DEVICE_OFFLINE') d['status'] = 'offline';
              if (type == 'HEARTBEAT_PING' && msg['payload'] != null) {
                d['battery_level'] = msg['payload']['battery_level'];
                d['is_charging'] = msg['payload']['is_charging'];
              }
            }
          }
        });
      }

      // Emergency SOS Alert
      if (type == 'SOS_ALERT') {
        _showSOSDialog(msg);
      }

      // SIM Swap Alert
      if (type == 'SIM_SWAP_ALERT') {
        final payload = msg['payload'];
        final op = payload != null && payload['new_operator'] != null ? payload['new_operator'] : 'غير معروف';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🚨 تنبيه أمني: تم تغيير أو إزالة شريحة الاتصال (SIM)! المشغل: $op'),
            backgroundColor: Colors.red.shade900,
            duration: const Duration(seconds: 6),
          ),
        );
      }

      // Airplane Mode Alert
      if (type == 'AIRPLANE_MODE_ALERT') {
        final payload = msg['payload'];
        final en = payload != null && payload['enabled'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✈️ تنبيه أمني: قام الطفل بـ (${en ? "تفعيل" : "تعطيل"}) وضع الطيران'),
            backgroundColor: en ? Colors.amber.shade900 : Colors.teal.shade800,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // Low Battery Alert
      if (type == 'LOW_BATTERY_ALERT') {
        final level = msg['payload']?['battery_level'] ?? 15;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.battery_alert, color: Colors.orangeAccent),
                const SizedBox(width: 8),
                Text('⚠️ تنبيه: بطارية جهاز الطفل منخفضة ($level%)!'),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            duration: const Duration(seconds: 5),
          ),
        );
      }

      // Geofence Alert
      if (type == 'GEOFENCE_ALERT') {
        final ev = msg['payload'] is String ? jsonDecode(msg['payload']) : msg['payload'];
        final eventType = ev?['event_type'] == 'ENTER' ? 'وصل إلى' : 'غادر';
        final zoneName = ev?['geofence_name'] ?? 'المنطقة الآمنة';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Text('📍 سياج جغرافي: الطفل $eventType $zoneName'),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            duration: const Duration(seconds: 6),
          ),
        );
      }

      // Remote Screenshot Captured
      if (type == 'SCREENSHOT_CAPTURED') {
        _showScreenshotDialog(msg);
      }

      // AI Risk Alert
      if (type == 'RISK_ALERT') {
        _showRiskAlertDialog(msg);
      }
    });
  }

  void _showSOSDialog(Map<String, dynamic> msg) {
    final payload = msg['payload'] is String ? jsonDecode(msg['payload']) : msg['payload'];
    final lat = payload?['latitude'];
    final lon = payload?['longitude'];
    final battery = payload?['battery_level'] ?? 100;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF7F1D1D),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.white, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'نداء استغاثة (SOS)',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'قام طفلك بالضغط على زر الطوارئ والاستغاثة فوراً!',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text('مستوى البطارية: $battery%', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
            if (lat != null && lon != null) ...[
              const SizedBox(height: 6),
              Text('الموقع الجغرافي: ($lat, $lon)', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red.shade900),
            onPressed: () {
              Navigator.pop(ctx);
              dynamic dev;
              for (var d in _devices) {
                if (d['id'] == msg['from']) {
                  dev = d;
                  break;
                }
              }
              dev ??= _devices.isNotEmpty ? _devices.first : null;
              if (dev != null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => LiveMapScreen(device: dev)));
              }
            },
            icon: const Icon(Icons.map),
            label: const Text('عرض موقع الطفل فوراً'),
          ),
        ],
      ),
    );
  }

  void _showScreenshotDialog(Map<String, dynamic> msg) {
    _screenshotTimeoutTimer?.cancel();
    _screenshotTimeoutTimer = null;

    final payload = msg['payload'] is String ? jsonDecode(msg['payload']) : msg['payload'];
    final b64 = payload?['image_base64'] as String?;
    if (b64 == null || b64.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black.withOpacity(0.95),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.black54,
            title: const Row(
              children: [
                Icon(Icons.screenshot_monitor, color: Colors.cyanAccent),
                SizedBox(width: 8),
                Text('لقطة شاشة فورية (Live Screenshot)', style: TextStyle(fontSize: 16)),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.memory(
                base64Decode(b64),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showRiskAlertDialog(Map<String, dynamic> msg) {
    final payload = msg['payload'] is String ? jsonDecode(msg['payload']) : msg['payload'];
    final category = payload?['category'] ?? 'خطر أمني محتمل';
    final severity = payload?['severity'] ?? 'HIGH';
    final snippet = payload?['snippet'] ?? '';
    final source = payload?['source'] ?? 'محتوى غير آمن';
    final matchedReason = payload?['matched_reason'] ?? payload?['reason'] ?? '';
    final alertId = payload?['id'] ?? payload?['alert_id'];
    final deviceId = msg['from'] ?? payload?['device_id'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF7F1D1D),
        title: Row(
          children: [
            const Icon(Icons.shield_outlined, color: Colors.amberAccent, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'تنبيه أمان ذكي: $category',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade900,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'مستوى الخطورة: $severity • المصدر: $source',
                style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            if (matchedReason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF60A5FA), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'سبب التنبيه: $matchedReason',
                        style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'رصدت منظومة سَنَد محتوى عالي الخطورة على جهاز طفلك:',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
              ),
              child: FutureBuilder<String>(
                future: CryptoHelper.decrypt(snippet),
                builder: (context, snapshot) {
                  return Text(
                    snapshot.data ?? snippet,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.shield, size: 16),
            label: const Text('تصنيف كإنذار آمن'),
            onPressed: () async {
              Navigator.pop(ctx);
              if (alertId != null && deviceId != null) {
                try {
                  await ApiClient.post(ApiConstants.markRiskAlertSafeUrl(deviceId.toString(), alertId), {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🛡️ تم تصنيف هذا الإنذار كآمن! لن يتم إشعارك بهذا النمط مجدداً.'),
                      backgroundColor: Color(0xFF065F46),
                    ),
                  );
                } catch (_) {}
              }
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً، تم الاطلاع', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  void _openAddDeviceDialog() {
    if (_isSubExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ لا يمكنك إضافة أجهزة جديدة نظراً لانتهاء باقة اشتراكك. يرجى التجديد.'),
          backgroundColor: Color(0xFF7F1D1D),
        ),
      );
      return;
    }

    final int maxDev = _subscription?['max_devices'] ?? 2;
    if (_devices.length >= maxDev) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Row(
            children: [
              Icon(Icons.devices_other, color: Colors.amber),
              SizedBox(width: 8),
              Text('تم استهلاك سعة الأجهزة', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: Text(
            'لقد بلغت الحد الأقصى المسموح به في باقتك ($maxDev أجهزة).\nيرجى ترقية الباقة لإضافة أجهزة إضافية.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('حسناً', style: TextStyle(color: Colors.blueAccent)),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AddDeviceDialog(onDeviceAdded: _loadDevices),
    );
  }

  Widget _buildSubscriptionBanner() {
    if (!_isSubExpired) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.15),
        border: Border.all(color: Colors.redAccent.withOpacity(0.6)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('انتهت صلاحية باقة اشتراكك!',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                SizedBox(height: 2),
                Text('تم إيقاف ميزات التحكم والبث المباشر والأوامر. يرجى تجديد الاشتراك للمتابعة.',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewStats() {
    final int total = _devices.length;
    final int online = _devices.where((d) => d['status'] == 'online').length;
    final planName = _subscription?['plan_name'] ?? 'عائلي VIP';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155), width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: _buildStatItem(
              icon: Icons.devices,
              label: 'إجمالي الأجهزة',
              value: '$total',
              color: const Color(0xFF38BDF8),
            ),
          ),
          Container(width: 1, height: 35, color: const Color(0xFF334155)),
          Expanded(
            child: _buildStatItem(
              icon: Icons.wifi,
              label: 'أجهزة متصلة',
              value: '$online',
              color: const Color(0xFF34D399),
            ),
          ),
          Container(width: 1, height: 35, color: const Color(0xFF334155)),
          Expanded(
            child: _buildStatItem(
              icon: Icons.workspace_premium,
              label: 'خطة الاشتراك',
              value: planName,
              color: const Color(0xFFFBBF24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                value,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shield, color: Color(0xFF60A5FA), size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'درع العائلة الذكي',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadDevices,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              await ApiClient.clearSession();
              WebSocketService().disconnect();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
          : RefreshIndicator(
              onRefresh: _loadDevices,
              color: const Color(0xFF3B82F6),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _buildSubscriptionBanner(),
                  _buildOverviewStats(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'أجهزة الأبناء المحمية في سَنَد',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        TextButton.icon(
                          onPressed: _openAddDeviceDialog,
                          icon: const Icon(Icons.add, size: 18, color: Color(0xFF60A5FA)),
                          label: const Text('إضافة جهاز', style: TextStyle(color: Color(0xFF60A5FA), fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                  if (_devices.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF334155)),
                              ),
                              child: const Icon(Icons.phone_android, size: 55, color: Colors.blueAccent),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'لا توجد أجهزة أطفال مقترنة بعد',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'قم بإقران أول جهاز لطفلك الآن لبدء الحماية والتتبع الكامل',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _openAddDeviceDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('إقران جهاز الطفل الآن'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._devices.map((device) => _buildDeviceCard(device)),
                  const SizedBox(height: 40),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDeviceDialog,
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('إضافة طفل', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildDeviceCard(Map<String, dynamic> device) {
    final childName = device['child']?['name'] ?? 'Child';
    final deviceName = device['device_name'] ?? 'Android Device';
    final model = device['model'] ?? 'Android';
    final isOnline = device['status'] == 'online';
    final battery = device['battery_level'] ?? 100;
    final isCharging = device['is_charging'] == true;
    final isPaused = device['is_monitoring_paused'] == true;
    final isDeviceOwner = device['is_device_owner'] == true;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF151C2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOnline ? const Color(0xFF1E3A8A) : const Color(0xFF273549),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DeviceControlScreen(
                  device: device,
                  subscription: _subscription,
                  onDeviceUpdated: _loadDevices,
                ),
              ),
            ).then((_) => _loadDevices());
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Child info row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isOnline ? const Color(0xFF10B981) : Colors.grey.shade600,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFF3B82F6),
                        child: Text(
                          childName.isNotEmpty ? childName[0].toUpperCase() : 'C',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            childName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Row(
                            children: [
                              Icon(
                                ((device['os_type'] == 'windows') ||
                                        (device['model']?.toString().toLowerCase().contains('windows') == true) ||
                                        (device['os_version']?.toString().toLowerCase().contains('windows') == true))
                                    ? Icons.laptop_windows
                                    : Icons.phone_android,
                                size: 14,
                                color: ((device['os_type'] == 'windows') ||
                                        (device['model']?.toString().toLowerCase().contains('windows') == true) ||
                                        (device['os_version']?.toString().toLowerCase().contains('windows') == true))
                                    ? Colors.cyanAccent
                                    : Colors.blueAccent,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  '$deviceName • $model',
                                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Online Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isOnline ? const Color(0xFF065F46).withOpacity(0.4) : const Color(0xFF334155).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isOnline ? const Color(0xFF10B981) : Colors.grey.shade600,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: isOnline ? const Color(0xFF10B981) : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isOnline ? 'متصل' : 'غير متصل',
                            style: TextStyle(
                              color: isOnline ? const Color(0xFF34D399) : Colors.grey.shade400,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Battery & Protection Status Chips
                Row(
                  children: [
                    // Battery
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B132B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCharging
                                ? Icons.battery_charging_full
                                : (battery > 20 ? Icons.battery_std : Icons.battery_alert),
                            size: 16,
                            color: isCharging
                                ? Colors.greenAccent
                                : (battery > 20 ? Colors.cyanAccent : Colors.redAccent),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$battery%${isCharging ? " (شحن)" : ""}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isCharging
                                  ? Colors.greenAccent
                                  : (battery > 20 ? Colors.white : Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Shield status
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isPaused ? Colors.amber : Colors.green).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (isPaused ? Colors.amberAccent : Colors.greenAccent).withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPaused ? Icons.pause_circle_filled : Icons.shield,
                            size: 14,
                            color: isPaused ? Colors.amberAccent : Colors.greenAccent,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isPaused ? 'الحماية معلقة' : 'الحماية نشطة',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isPaused ? Colors.amberAccent : Colors.greenAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // DO badge
                    if (isDeviceOwner)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.purpleAccent.withOpacity(0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_user, size: 14, color: Colors.purpleAccent),
                            SizedBox(width: 4),
                            Text(
                              'DO حماية قصوى',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purpleAccent),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Call to action button to open DeviceControlScreen
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.dashboard_customize, size: 18, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'فتح لوحة التحكم والوظائف الكاملة',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white70),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _screenshotTimeoutTimer?.cancel();
    super.dispose();
  }
}

