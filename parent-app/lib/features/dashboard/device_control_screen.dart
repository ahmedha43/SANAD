import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/websocket_service.dart';
import '../../core/security/crypto_helper.dart';
import '../apps/app_management_screen.dart';
import '../data/calls_screen.dart';
import '../data/contacts_screen.dart';
import '../data/files_screen.dart';
import '../data/notifications_screen.dart';
import '../data/sms_screen.dart';
import '../filter/web_filter_screen.dart';
import '../filter/browser_history_screen.dart';
import '../location/geofence_manager_screen.dart';
import '../location/live_map_screen.dart';
import '../location/route_history_screen.dart';
import '../monitoring/device_owner_screen.dart';
import '../monitoring/live_stream_screen.dart';
import '../reports/screen_time_report_screen.dart';
import '../reports/screen_time_settings_screen.dart';

class DeviceControlScreen extends StatefulWidget {
  final Map<String, dynamic> device;
  final Map<String, dynamic>? subscription;
  final VoidCallback? onDeviceUpdated;

  const DeviceControlScreen({
    super.key,
    required this.device,
    this.subscription,
    this.onDeviceUpdated,
  });

  @override
  State<DeviceControlScreen> createState() => _DeviceControlScreenState();
}

class _DeviceControlScreenState extends State<DeviceControlScreen> {
  late Map<String, dynamic> _device;
  Map<String, dynamic>? _subscription;
  bool _monitoringPaused = false;
  bool _antiUninstall = true;
  bool _stealthMode = false;
  bool _blockSettings = false;
  StreamSubscription? _wsSubscription;
  Timer? _screenshotTimeoutTimer;
  bool _isRefreshing = false;
  String _selectedCategory = 'all';

  bool get _isSubExpired =>
      _subscription != null &&
      (_subscription!['is_expired'] == true || _subscription!['status'] != 'active');

  bool _hasFeature(String featureSlug) {
    if (_subscription == null) return true;
    final tier = _subscription!['tier'] ?? '';
    if (tier == 'family_unlimited' || tier == 'unlimited') return true;
    final feats = _subscription!['features'];
    if (feats is List) {
      return feats.contains(featureSlug);
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _device = Map<String, dynamic>.from(widget.device);
    _subscription = widget.subscription;
    _monitoringPaused = _device['is_monitoring_paused'] == true;
    _antiUninstall = _device['anti_uninstall'] ?? true;
    _stealthMode = _device['stealth_mode'] ?? false;
    _blockSettings = _device['block_settings'] ?? false;
    _listenToLiveUpdates();
  }

  void _listenToLiveUpdates() {
    _wsSubscription = WebSocketService().messageStream.listen((msg) {
      if (!mounted) return;
      final type = msg['type'];
      final from = msg['from'];
      final deviceId = _device['id'];

      if (type == 'MONITORING_STATUS_CHANGED') {
        try {
          final payload = msg['payload'] is String ? jsonDecode(msg['payload']) : msg['payload'];
          final targetDevId = payload?['device_id'] ?? msg['from'];
          if (targetDevId == deviceId) {
            final isPaused = payload?['is_monitoring_paused'] == true;
            setState(() {
              _monitoringPaused = isPaused;
              _device['is_monitoring_paused'] = isPaused;
            });
            widget.onDeviceUpdated?.call();
          }
        } catch (_) {}
      }

      if (from == deviceId) {
        if (type == 'DEVICE_ONLINE') {
          setState(() => _device['status'] = 'online');
          widget.onDeviceUpdated?.call();
        } else if (type == 'DEVICE_OFFLINE') {
          setState(() => _device['status'] = 'offline');
          widget.onDeviceUpdated?.call();
        } else if (type == 'HEARTBEAT_PING' && msg['payload'] != null) {
          setState(() {
            _device['battery_level'] = msg['payload']['battery_level'];
            _device['is_charging'] = msg['payload']['is_charging'];
          });
          widget.onDeviceUpdated?.call();
        }
      }

      if (type == 'SCREENSHOT_CAPTURED' && from == deviceId) {
        _showScreenshotDialog(msg);
      } else if (type == 'SOS_ALERT' && from == deviceId) {
        _showSOSDialog(msg);
      } else if (type == 'SIM_SWAP_ALERT' && from == deviceId) {
        final op = msg['payload']?['new_operator'] ?? 'غير معروف';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🚨 تنبيه أمني: تم تغيير شريحة SIM! المشغل: $op'),
            backgroundColor: Colors.red.shade900,
            duration: const Duration(seconds: 6),
          ),
        );
      } else if (type == 'AIRPLANE_MODE_ALERT' && from == deviceId) {
        final en = msg['payload']?['enabled'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✈️ تنبيه: تم (${en ? "تفعيل" : "تعطيل"}) وضع الطيران'),
            backgroundColor: en ? Colors.amber.shade900 : Colors.teal.shade800,
          ),
        );
      } else if (type == 'LOW_BATTERY_ALERT' && from == deviceId) {
        final lvl = msg['payload']?['battery_level'] ?? 15;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ تنبيه: بطارية هاتف الطفل منخفضة ($lvl%)!'),
            backgroundColor: const Color(0xFF1E293B),
          ),
        );
      } else if (type == 'GEOFENCE_ALERT' && from == deviceId) {
        final ev = msg['payload'] is String ? jsonDecode(msg['payload']) : msg['payload'];
        final action = ev?['event_type'] == 'ENTER' ? 'وصل إلى' : 'غادر';
        final zone = ev?['geofence_name'] ?? 'المنطقة الآمنة';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📍 سياج جغرافي: الطفل $action $zone'),
            backgroundColor: const Color(0xFF1E293B),
          ),
        );
      } else if (type == 'RISK_ALERT' && from == deviceId) {
        _showRiskAlertDialog(msg);
      }
    });
  }

  Future<void> _refreshDeviceData() async {
    setState(() => _isRefreshing = true);
    try {
      final res = await ApiClient.get(ApiConstants.devicesUrl);
      if (res.statusCode == 200) {
        final devs = jsonDecode(utf8.decode(res.bodyBytes));
        if (devs is List) {
          for (final d in devs) {
            if (d['id'] == _device['id']) {
              setState(() {
                _device = Map<String, dynamic>.from(d);
                _monitoringPaused = d['is_monitoring_paused'] == true;
              });
              break;
            }
          }
        }
      }
      widget.onDeviceUpdated?.call();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _sendCommand(String action, String successMsg) {
    final deviceId = _device['id'];
    WebSocketService().sendCommand(deviceId, action);
    ApiClient.post(ApiConstants.commandUrl(deviceId), {
      'action': action,
      'params': {},
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
            const SizedBox(width: 8),
            Text(successMsg),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleMasterMonitoring() async {
    final next = !_monitoringPaused;
    setState(() => _monitoringPaused = next);
    final action = next ? 'PAUSE_MONITORING' : 'RESUME_MONITORING';
    try {
      final deviceId = _device['id'];
      await ApiClient.post(ApiConstants.commandUrl(deviceId), {
        'action': action,
        'params': {},
      });
      WebSocketService().sendCommand(deviceId, action);
      widget.onDeviceUpdated?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next ? '⏸️ تم تعليق درع الحماية مؤقتاً' : '🟢 تم استئناف درع حماية سَنَد'),
            backgroundColor: next ? Colors.amber.shade900 : Colors.green.shade800,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _monitoringPaused = !next);
      }
    }
  }

  void _toggleAntiUninstall() async {
    final next = !_antiUninstall;
    setState(() => _antiUninstall = next);
    try {
      final deviceId = _device['id'];
      await ApiClient.post(ApiConstants.commandUrl(deviceId), {
        'action': 'SET_ANTI_UNINSTALL',
        'params': {'enabled': next},
      });
      WebSocketService().sendCommand(deviceId, 'SET_ANTI_UNINSTALL', {'enabled': next});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next ? '🛡️ تم تفعيل حظر إزالة التطبيق' : '🛡️ تم إلغاء حظر إزالة التطبيق'),
            backgroundColor: next ? Colors.green.shade800 : Colors.blueGrey.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _antiUninstall = !next);
    }
  }

  void _toggleStealthMode() async {
    final next = !_stealthMode;
    setState(() => _stealthMode = next);
    final action = next ? 'HIDE_APP_ICON' : 'SHOW_APP_ICON';
    try {
      final deviceId = _device['id'];
      await ApiClient.post(ApiConstants.commandUrl(deviceId), {
        'action': action,
        'params': {},
      });
      WebSocketService().sendCommand(deviceId, action);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next ? '👻 تم إخفاء أيقونة التطبيق (*#*#2026#*#*)' : '👁️ تم إظهار أيقونة التطبيق'),
            backgroundColor: next ? Colors.deepOrange.shade800 : Colors.blueGrey.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _stealthMode = !next);
    }
  }

  void _toggleBlockSettings() async {
    final next = !_blockSettings;
    setState(() => _blockSettings = next);
    try {
      final deviceId = _device['id'];
      await ApiClient.post(ApiConstants.commandUrl(deviceId), {
        'action': 'SET_BLOCK_SETTINGS',
        'params': {'enabled': next},
      });
      WebSocketService().sendCommand(deviceId, 'SET_BLOCK_SETTINGS', {'enabled': next});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next ? '⚙️ تم حظر فتح إعدادات الهاتف للطفل' : '⚙️ تم السماح بفتح إعدادات الهاتف'),
            backgroundColor: next ? Colors.amber.shade900 : Colors.blueGrey.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _blockSettings = !next);
    }
  }

  void _requestScreenshot() {
    final deviceId = _device['id'];
    WebSocketService().sendMessage('TAKE_SCREENSHOT', to: deviceId);
    ApiClient.post(ApiConstants.commandUrl(deviceId), {
      'action': 'TAKE_SCREENSHOT',
      'params': {},
    });

    _screenshotTimeoutTimer?.cancel();
    _screenshotTimeoutTimer = Timer(const Duration(seconds: 15), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('انتهت مهلة انتظار لقطة الشاشة. تأكد من اتصال هاتف الطفل وتشغيل الشاشة.'),
            backgroundColor: Colors.red.shade900,
          ),
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text('جاري التقاط لقطة شاشة صامتة فورية من هاتف الطفل...'),
            ),
          ],
        ),
        backgroundColor: Color(0xFF1E293B),
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showScreenshotDialog(Map<String, dynamic> msg) {
    _screenshotTimeoutTimer?.cancel();
    _screenshotTimeoutTimer = null;

    final payload = msg['payload'] is String ? jsonDecode(msg['payload']) : msg['payload'];
    final b64 = payload?['image_base64'] as String?;
    if (b64 == null || b64.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(payload?['error'] ?? 'فشل التقاط لقطة الشاشة من الجهاز'),
          backgroundColor: Colors.red.shade800,
        ),
      );
      return;
    }

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
              Navigator.push(context, MaterialPageRoute(builder: (_) => LiveMapScreen(device: _device)));
            },
            icon: const Icon(Icons.map),
            label: const Text('عرض موقع الطفل فوراً'),
          ),
        ],
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
    final deviceId = _device['id'];

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
              'رصدت منظومة سَنَد محتوى عالي الخطورة على هاتف طفلك:',
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
              if (alertId != null) {
                try {
                  await ApiClient.post(ApiConstants.markRiskAlertSafeUrl(deviceId, alertId), {});
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

  Future<void> _showRiskHistoryDialog(Map<String, dynamic> device) async {
    final deviceId = device['id'];
    List<dynamic> alerts = [];
    bool loading = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          if (loading) {
            ApiClient.get(ApiConstants.riskAlertsUrl(deviceId)).then((res) {
              if (res.statusCode == 200) {
                final list = jsonDecode(res.body);
                if (list is List) {
                  setDialogState(() {
                    alerts = list;
                    loading = false;
                  });
                }
              } else {
                setDialogState(() => loading = false);
              }
            }).catchError((_) {
              setDialogState(() => loading = false);
            });
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF1E2230),
            title: const Row(
              children: [
                Icon(Icons.security, color: Colors.amberAccent),
                SizedBox(width: 8),
                Text('سجل تنبيهات الأمان الذكية', style: TextStyle(fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 420,
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : alerts.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 48),
                              SizedBox(height: 12),
                              Text('البيئة آمنة تماماً!', style: TextStyle(fontWeight: FontWeight.bold)),
                              SizedBox(height: 4),
                              Text('لم يتم رصد أي محتوى ضار أو خطر حتى الآن',
                                  style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: alerts.length,
                          itemBuilder: (context, idx) {
                            final alert = alerts[idx];
                            final cat = alert['category'] ?? 'Risk';
                            final sev = alert['severity'] ?? 'HIGH';
                            final snip = alert['snippet'] ?? '';
                            final src = alert['source'] ?? '';
                            final matchedReason = alert['matched_reason'] ?? '';
                            final isSafe = alert['is_safe'] == true;
                            final ts = alert['created_at'] ?? alert['timestamp'];

                            return Card(
                              color: const Color(0xFF282F45),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          cat,
                                          style: const TextStyle(
                                            color: Colors.redAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            sev,
                                            style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(snip, style: const TextStyle(fontSize: 13, color: Colors.white)),
                                    if (matchedReason.toString().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'السبب: $matchedReason',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF93C5FD), fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text('المصدر: $src • $ts',
                                              style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                                        ),
                                        isSafe
                                            ? Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF059669).withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.shield, color: Color(0xFF34D399), size: 12),
                                                    SizedBox(width: 4),
                                                    Text('آمن', style: TextStyle(color: Color(0xFF34D399), fontSize: 10)),
                                                  ],
                                                ),
                                              )
                                            : TextButton.icon(
                                                style: TextButton.styleFrom(
                                                  foregroundColor: const Color(0xFF34D399),
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                ),
                                                icon: const Icon(Icons.shield_outlined, size: 12),
                                                label: const Text('تصنيف كآمن', style: TextStyle(fontSize: 10)),
                                                onPressed: () async {
                                                  final aId = alert['id'];
                                                  try {
                                                    final res = await ApiClient.post(ApiConstants.markRiskAlertSafeUrl(deviceId, aId), {});
                                                    if (res.statusCode == 200) {
                                                      setDialogState(() {
                                                        alert['is_safe'] = true;
                                                      });
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(
                                                          content: Text('🛡️ تم تصنيف التنبيه كآمن ولن يظهر مجدداً'),
                                                          backgroundColor: Color(0xFF065F46),
                                                        ),
                                                      );
                                                    }
                                                  } catch (_) {}
                                                },
                                              ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إغلاق'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _executeFeature({
    required String label,
    required VoidCallback onTap,
    String? requiredFeature,
  }) {
    if (_isSubExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ تم إيقاف هذه الميزة نظراً لانتهاء باقة اشتراكك. يرجى تجديد الترخيص.'),
          backgroundColor: Color(0xFF7F1D1D),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    if (requiredFeature != null && !_hasFeature(requiredFeature)) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Row(
            children: [
              Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
              SizedBox(width: 8),
              Text('ميزة مقفلة (Premium VIP)', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: Text(
            'ميزة "$label" غير متوفرة في باقتك الحالية (${_subscription?['plan_name'] ?? 'الباقة المجانية'}).\n\nيرجى الترقية إلى الباقة المتقدمة أو العائلية لفتح الوصول الكامل إليها.',
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

    onTap();
  }

  @override
  Widget build(BuildContext context) {
    final childName = _device['child']?['name'] ?? 'Child';
    final deviceName = _device['device_name'] ?? 'Android Device';
    final model = _device['model'] ?? 'Android';
    final isOnline = _device['status'] == 'online';
    final battery = _device['battery_level'] ?? 100;
    final isCharging = _device['is_charging'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              childName,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isOnline ? const Color(0xFF10B981) : Colors.grey,
                    shape: BoxShape.circle,
                    boxShadow: isOnline
                        ? [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.6),
                              blurRadius: 6,
                              spreadRadius: 2,
                            )
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isOnline ? 'متصل الآن' : 'غير متصل',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOnline ? const Color(0xFF34D399) : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                  )
                : const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _isRefreshing ? null : _refreshDeviceData,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDeviceHeroBanner(
              childName: childName,
              deviceName: deviceName,
              model: model,
              isOnline: isOnline,
              battery: battery,
              isCharging: isCharging,
            ),
            const SizedBox(height: 14),
            _buildMasterProtectionCard(),
            const SizedBox(height: 18),
            _buildCategoryFilter(),
            const SizedBox(height: 16),
            if (_selectedCategory == 'all' || _selectedCategory == 'surveillance') ...[
              _buildSectionHeader('البث المباشر والتواصل الفوري', Icons.sensors, Colors.cyanAccent),
              const SizedBox(height: 10),
              _buildSurveillanceGrid(),
              const SizedBox(height: 20),
            ],
            if (_selectedCategory == 'all' || _selectedCategory == 'controls') ...[
              _buildSectionHeader('التحكم السريع والأوامر', Icons.touch_app, Colors.amberAccent),
              const SizedBox(height: 10),
              _buildQuickControlsGrid(),
              const SizedBox(height: 20),
            ],
            if (_selectedCategory == 'all' || _selectedCategory == 'security') ...[
              _buildSectionHeader('الأمان ومكافحة التلاعب', Icons.security, Colors.redAccent),
              const SizedBox(height: 10),
              _buildSecurityGrid(),
              const SizedBox(height: 20),
            ],
            if (_selectedCategory == 'all' || _selectedCategory == 'location') ...[
              _buildSectionHeader('الموقع والتتبع الجغرافي', Icons.location_on, Colors.blueAccent),
              const SizedBox(height: 10),
              _buildLocationGrid(),
              const SizedBox(height: 20),
            ],
            if (_selectedCategory == 'all' || _selectedCategory == 'rules') ...[
              _buildSectionHeader('إدارة التطبيقات والإنترنت', Icons.apps, Colors.indigoAccent),
              const SizedBox(height: 10),
              _buildRulesGrid(),
              const SizedBox(height: 20),
            ],
            if (_selectedCategory == 'all' || _selectedCategory == 'logs') ...[
              _buildSectionHeader('سجلات الهاتف والبيانات', Icons.folder_shared, Colors.tealAccent),
              const SizedBox(height: 10),
              _buildLogsGrid(),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceHeroBanner({
    required String childName,
    required String deviceName,
    required String model,
    required bool isOnline,
    required int battery,
    required bool isCharging,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF334155), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isOnline ? const Color(0xFF10B981) : Colors.grey.shade600,
                    width: 2.5,
                  ),
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF3B82F6),
                  child: Text(
                    childName.isNotEmpty ? childName[0].toUpperCase() : 'C',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
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
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Row(
                      children: [
                        Icon(
                          ((_device['os_type'] == 'windows') ||
                                  (_device['model']?.toString().toLowerCase().contains('windows') == true) ||
                                  (_device['os_version']?.toString().toLowerCase().contains('windows') == true))
                              ? Icons.laptop_windows
                              : Icons.phone_android,
                          size: 14,
                          color: ((_device['os_type'] == 'windows') ||
                                  (_device['model']?.toString().toLowerCase().contains('windows') == true) ||
                                  (_device['os_version']?.toString().toLowerCase().contains('windows') == true))
                              ? Colors.cyanAccent
                              : Colors.blueAccent,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '$deviceName • $model',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B132B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isCharging
                        ? Colors.greenAccent.withOpacity(0.5)
                        : (battery > 20 ? Colors.cyanAccent.withOpacity(0.3) : Colors.redAccent.withOpacity(0.5)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCharging
                          ? Icons.battery_charging_full
                          : (battery > 20 ? Icons.battery_std : Icons.battery_alert),
                      size: 18,
                      color: isCharging
                          ? Colors.greenAccent
                          : (battery > 20 ? Colors.cyanAccent : Colors.redAccent),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$battery%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isCharging
                            ? Colors.greenAccent
                            : (battery > 20 ? Colors.white : Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildInfoPill(
                icon: Icons.shield,
                label: (_device['is_device_owner'] == true) ? 'حماية قصوى DO' : 'وضع عادي',
                color: (_device['is_device_owner'] == true) ? Colors.purpleAccent : Colors.grey,
              ),
              const SizedBox(width: 8),
              _buildInfoPill(
                icon: Icons.visibility,
                label: _stealthMode ? 'مخفي' : 'أيقونة ظاهرة',
                color: _stealthMode ? Colors.deepOrangeAccent : Colors.grey,
              ),
              const SizedBox(width: 8),
              _buildInfoPill(
                icon: Icons.lock_clock,
                label: _antiUninstall ? 'منع الإزالة نشط' : 'إزالة ممكنة',
                color: _antiUninstall ? Colors.redAccent : Colors.grey,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPill({required IconData icon, required String label, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterProtectionCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _monitoringPaused
              ? [const Color(0xFF451A03), const Color(0xFF1E293B)]
              : [const Color(0xFF064E3B), const Color(0xFF0F172A)],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _monitoringPaused ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (_monitoringPaused ? Colors.amber : Colors.green).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _monitoringPaused ? Icons.pause_circle_filled : Icons.verified_user,
              color: _monitoringPaused ? Colors.amberAccent : Colors.greenAccent,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _monitoringPaused ? 'درع الحماية معلق مؤقتاً' : 'درع حماية سَنَد نشط بالكامل',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  _monitoringPaused
                      ? 'تم تعليق حظر التطبيقات وتصفية الويب'
                      : 'حظر التطبيقات والويب وتتبع الموقع فعال ومحكم',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
          Switch(
            value: !_monitoringPaused,
            activeColor: const Color(0xFF10B981),
            activeTrackColor: const Color(0xFF065F46),
            inactiveThumbColor: Colors.amberAccent,
            inactiveTrackColor: const Color(0xFF78350F),
            onChanged: (val) => _toggleMasterMonitoring(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final categories = [
      {'id': 'all', 'label': 'الكل', 'icon': Icons.dashboard_outlined},
      {'id': 'surveillance', 'label': 'البث الحي', 'icon': Icons.sensors},
      {'id': 'controls', 'label': 'التحكم', 'icon': Icons.touch_app},
      {'id': 'security', 'label': 'الأمان', 'icon': Icons.security},
      {'id': 'location', 'label': 'الموقع', 'icon': Icons.location_on},
      {'id': 'rules', 'label': 'التطبيقات', 'icon': Icons.apps},
      {'id': 'logs', 'label': 'السجلات', 'icon': Icons.folder_shared},
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final cat = categories[idx];
          final isSelected = _selectedCategory == cat['id'];
          return InkWell(
            onTap: () => setState(() => _selectedCategory = cat['id'] as String),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? const Color(0xFF60A5FA) : const Color(0xFF334155),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    cat['icon'] as IconData,
                    size: 15,
                    color: isSelected ? Colors.white : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cat['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : Colors.grey.shade300,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildSurveillanceGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.25,
      children: [
        _buildFeatureCard(
          icon: Icons.screen_share,
          title: 'بث الشاشة المباشر',
          subtitle: 'Mirror Screen',
          badge: 'WebRTC HD',
          accentColor: const Color(0xFFA855F7),
          requiredFeature: 'webrtc_stream',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LiveStreamScreen(device: _device, initialType: StreamType.screen),
            ),
          ),
        ),
        _buildFeatureCard(
          icon: Icons.videocam,
          title: 'الكاميرا عن بعد',
          subtitle: 'Remote Camera',
          badge: 'أمامي / خلفي',
          accentColor: const Color(0xFF14B8A6),
          requiredFeature: 'live_camera',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LiveStreamScreen(device: _device, initialType: StreamType.camera),
            ),
          ),
        ),
        _buildFeatureCard(
          icon: Icons.hearing,
          title: 'الاستماع الصوتي الحي',
          subtitle: 'Ambient Audio',
          badge: 'صوت محيطي فوري',
          accentColor: const Color(0xFF06B6D4),
          requiredFeature: 'webrtc_stream',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LiveStreamScreen(device: _device, initialType: StreamType.audioOnly),
            ),
          ),
        ),
        _buildFeatureCard(
          icon: Icons.record_voice_over,
          title: 'اللاسلكي الفوري',
          subtitle: 'Walkie-Talkie',
          badge: 'تحدث لمكبر الصوت',
          accentColor: const Color(0xFFF59E0B),
          requiredFeature: 'webrtc_stream',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LiveStreamScreen(device: _device, initialType: StreamType.walkieTalkie),
            ),
          ),
        ),
        _buildFeatureCard(
          icon: Icons.screenshot_monitor,
          title: 'لقطة شاشة صامتة',
          subtitle: 'Instant Screenshot',
          badge: 'فوري وسري',
          accentColor: const Color(0xFF10B981),
          requiredFeature: 'silent_screenshot',
          onTap: _requestScreenshot,
        ),
      ],
    );
  }

  Widget _buildQuickControlsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.25,
      children: [
        _buildFeatureCard(
          icon: Icons.lock,
          title: 'قفل الهاتف فوراً',
          subtitle: 'Lock Device',
          badge: 'إغلاق كامل',
          accentColor: const Color(0xFFEF4444),
          onTap: () => _sendCommand('LOCK_DEVICE', 'تم إرسال أمر قفل الهاتف بنجاح!'),
        ),
        _buildFeatureCard(
          icon: Icons.lock_open,
          title: 'إلغاء قفل الهاتف',
          subtitle: 'Unlock Device',
          badge: 'استعادة الشاشة',
          accentColor: const Color(0xFF10B981),
          onTap: () => _sendCommand('UNLOCK_DEVICE', 'تم إرسال أمر إلغاء القفل بنجاح!'),
        ),
        _buildFeatureCard(
          icon: Icons.campaign,
          title: 'تشغيل صفارة الإنذار',
          subtitle: 'Play Siren Alarm',
          badge: 'أقصى صوت',
          accentColor: const Color(0xFFF97316),
          onTap: () => _sendCommand('PLAY_ALARM', 'تم إطلاق صفارة الإنذار في هاتف الطفل!'),
        ),
        _buildFeatureCard(
          icon: Icons.volume_off,
          title: 'إيقاف الإنذار',
          subtitle: 'Stop Siren',
          badge: 'إسكات الصوت',
          accentColor: const Color(0xFF64748B),
          onTap: () => _sendCommand('STOP_ALARM', 'تم إيقاف صفارة الإنذار!'),
        ),
      ],
    );
  }

  Widget _buildSecurityGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.25,
      children: [
        _buildFeatureCard(
          icon: Icons.verified_user,
          title: 'درع الحماية القصوى',
          subtitle: 'Device Owner Hub',
          badge: 'Android Enterprise',
          accentColor: const Color(0xFF8B5CF6),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DeviceOwnerScreen(device: _device)),
          ),
        ),
        _buildFeatureCard(
          icon: Icons.shield,
          title: 'منع إلغاء التثبيت',
          subtitle: 'Anti-Uninstall',
          badge: _antiUninstall ? 'نشط 🛡️' : 'معطل ⚠️',
          accentColor: _antiUninstall ? const Color(0xFFEF4444) : Colors.grey,
          requiredFeature: 'anti_uninstall',
          isToggle: true,
          toggleValue: _antiUninstall,
          onTap: _toggleAntiUninstall,
        ),
        _buildFeatureCard(
          icon: Icons.visibility_off,
          title: 'الوضع الخفي',
          subtitle: 'Stealth Mode',
          badge: _stealthMode ? 'مخفي 👻' : 'ظاهر 👁️',
          accentColor: const Color(0xFFEA580C),
          requiredFeature: 'stealth_mode',
          isToggle: true,
          toggleValue: _stealthMode,
          onTap: _toggleStealthMode,
        ),
        _buildFeatureCard(
          icon: Icons.settings_suggest,
          title: 'حظر الإعدادات',
          subtitle: 'Block Settings',
          badge: _blockSettings ? 'محظور 🔒' : 'متاح 🔓',
          accentColor: const Color(0xFFF59E0B),
          requiredFeature: 'settings_protection',
          isToggle: true,
          toggleValue: _blockSettings,
          onTap: _toggleBlockSettings,
        ),
        _buildFeatureCard(
          icon: Icons.security,
          title: 'تنبيهات الذكاء الاصطناعي',
          subtitle: 'AI Risk Alerts',
          badge: 'رصد المحتوى الضار',
          accentColor: const Color(0xFFDC2626),
          requiredFeature: 'ai_risk_detection',
          onTap: () => _showRiskHistoryDialog(_device),
        ),
      ],
    );
  }

  Widget _buildLocationGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.25,
      children: [
        _buildFeatureCard(
          icon: Icons.map,
          title: 'الخريطة الحية للموقع',
          subtitle: 'Live GPS Map',
          badge: 'تتبع فوري',
          accentColor: const Color(0xFF3B82F6),
          requiredFeature: 'live_gps',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LiveMapScreen(device: _device)),
          ),
        ),
        _buildFeatureCard(
          icon: Icons.fence,
          title: 'المناطق الآمنة',
          subtitle: 'Safe Geofences',
          badge: 'سياج جغرافي',
          accentColor: const Color(0xFF10B981),
          requiredFeature: 'geofencing',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => GeofenceManagerScreen(device: _device)),
          ),
        ),
        _buildFeatureCard(
          icon: Icons.timeline,
          title: 'سجل المسارات والرحلات',
          subtitle: 'Route History',
          badge: 'إعادة مسار الحركة',
          accentColor: const Color(0xFFF59E0B),
          requiredFeature: 'route_replay',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RouteHistoryScreen(device: _device)),
          ),
        ),
      ],
    );
  }

  Widget _buildRulesGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.25,
      children: [
        _buildFeatureCard(
          icon: Icons.apps,
          title: 'التحكم بالتطبيقات والحظر',
          subtitle: 'App Limits & Blocking',
          badge: 'إدارة وتخصيص',
          accentColor: const Color(0xFF6366F1),
          requiredFeature: 'app_blocking',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AppManagementScreen(device: _device)),
          ),
        ),
        _buildFeatureCard(
          icon: Icons.bar_chart,
          title: 'تقرير وقت الشاشة',
          subtitle: 'Screen Time Report',
          badge: 'رسوم ومخططات',
          accentColor: const Color(0xFF06B6D4),
          requiredFeature: 'screen_time',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ScreenTimeReportScreen(device: _device)),
          ),
        ),
        _buildFeatureCard(
          icon: Icons.nightlight_round,
          title: 'وقت النوم والجدولة',
          subtitle: 'Bedtime & Rules',
          badge: 'جداول الاستخدام',
          accentColor: const Color(0xFF8B5CF6),
          requiredFeature: 'screen_time',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ScreenTimeSettingsScreen(device: _device)),
          ),
        ),
        _buildFeatureCard(
          icon: Icons.language,
          title: 'تصفية مواقع الويب',
          subtitle: 'Web Content Filter',
          badge: 'SafeSearch وحظر',
          accentColor: const Color(0xFF14B8A6),
          requiredFeature: 'app_blocking',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => WebFilterScreen(device: _device)),
          ),
        ),
        _buildFeatureCard(
          icon: Icons.history_edu_rounded,
          title: 'سجل التصفح والبحث',
          subtitle: 'Browser History & Search',
          badge: 'رصد المتصفحات وحظر',
          accentColor: const Color(0xFF06B6D4),
          requiredFeature: 'app_blocking',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BrowserHistoryScreen(device: _device)),
          ),
        ),
      ],
    );
  }

  Widget _buildLogsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.25,
      children: [
        _buildFeatureCard(
          icon: Icons.sms,
          title: 'الرسائل النصية',
          subtitle: 'SMS Messages',
          badge: 'صادر ووارد مشفر',
          accentColor: const Color(0xFF0EA5E9),
          requiredFeature: 'sms_log',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SmsScreen(device: _device)),
          ),
        ),
        _buildFeatureCard(
          icon: Icons.phone_in_talk,
          title: 'سجل المكالمات',
          subtitle: 'Call History',
          badge: 'المكالمات والأرقام',
          accentColor: const Color(0xFF10B981),
          requiredFeature: 'calls_log',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CallsScreen(device: _device)),
          ),
        ),
        _buildFeatureCard(
          icon: Icons.contacts,
          title: 'جهات الاتصال',
          subtitle: 'Contacts Book',
          badge: 'دفتر العناوين',
          accentColor: const Color(0xFF14B8A6),
          requiredFeature: 'contacts',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ContactsScreen(device: _device)),
          ),
        ),
        _buildFeatureCard(
          icon: Icons.notifications_active,
          title: 'سجل الإشعارات',
          subtitle: 'Notifications Log',
          badge: 'واتساب والتواصل',
          accentColor: const Color(0xFFA855F7),
          requiredFeature: 'notifications',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => NotificationsScreen(device: _device)),
          ),
        ),
        _buildFeatureCard(
          icon: Icons.photo_library,
          title: 'معرض الوسائط والملفات',
          subtitle: 'Media & Files',
          badge: 'الصور والملفات',
          accentColor: const Color(0xFFEC4899),
          requiredFeature: 'media_gallery',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => FilesScreen(device: _device)),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    required Color accentColor,
    required VoidCallback onTap,
    String? requiredFeature,
    bool isToggle = false,
    bool toggleValue = false,
  }) {
    final bool isExpired = _isSubExpired;
    final bool isLocked = requiredFeature != null && !_hasFeature(requiredFeature);
    final bool disabled = isExpired || isLocked;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _executeFeature(label: title, onTap: onTap, requiredFeature: requiredFeature),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF151C2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isLocked
                  ? Colors.amber.withOpacity(0.4)
                  : (disabled ? Colors.redAccent.withOpacity(0.3) : accentColor.withOpacity(0.25)),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isLocked ? Icons.lock : icon,
                      color: isLocked ? Colors.amber : accentColor,
                      size: 20,
                    ),
                  ),
                  if (isLocked)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.withOpacity(0.5)),
                      ),
                      child: const Text(
                        'VIP',
                        style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    )
                  else if (isToggle)
                    Transform.scale(
                      scale: 0.75,
                      alignment: Alignment.centerLeft,
                      child: Switch(
                        value: toggleValue,
                        activeColor: accentColor,
                        onChanged: (val) => _executeFeature(label: title, onTap: onTap, requiredFeature: requiredFeature),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
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
