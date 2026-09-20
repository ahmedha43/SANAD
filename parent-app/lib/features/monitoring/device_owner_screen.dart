import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/network/websocket_service.dart';

class DeviceOwnerScreen extends StatefulWidget {
  final Map<String, dynamic> device;

  const DeviceOwnerScreen({super.key, required this.device});

  @override
  State<DeviceOwnerScreen> createState() => _DeviceOwnerScreenState();
}

class _DeviceOwnerScreenState extends State<DeviceOwnerScreen> {
  bool _isDeviceOwner = false;
  bool _isDeviceAdmin = false;
  bool _isLoading = true;
  StreamSubscription? _wsSub;

  final String _adbCommand =
      'adb shell dpm set-device-owner com.parentalcontrol.kidsagent/.service.AgentDeviceAdminReceiver';

  @override
  void initState() {
    super.initState();
    _listenToStatus();
    _requestStatus();
  }

  void _listenToStatus() {
    _wsSub = WebSocketService().messageStream.listen((msg) {
      if (msg['type'] == 'DEVICE_OWNER_STATUS') {
        final payload = msg['payload'];
        if (payload != null && mounted) {
          final data = payload is String ? jsonDecode(payload) : payload;
          setState(() {
            _isDeviceOwner = data['is_device_owner'] == true;
            _isDeviceAdmin = data['is_device_admin'] == true;
            _isLoading = false;
          });
        }
      }
    });
  }

  void _requestStatus() {
    setState(() => _isLoading = true);
    WebSocketService().sendMessage(
      'GET_DEVICE_OWNER_STATUS',
      to: widget.device['id'],
    );
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  void _copyAdbCommand() {
    Clipboard.setData(ClipboardData(text: _adbCommand));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ أمر ADB بنجاح إلى الحافظة ✓'),
        backgroundColor: Colors.teal,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          title: const Text('الحماية القصوى (Device Owner)'),
          backgroundColor: const Color(0xFF1E293B),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث الحالة',
              onPressed: _requestStatus,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStatusCard(),
                    const SizedBox(height: 16),
                    _buildProtectionsMatrix(),
                    const SizedBox(height: 16),
                    _buildAdbMethodCard(),
                    const SizedBox(height: 16),
                    _buildQrMethodCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDeviceOwner ? Colors.green.shade600 : Colors.purple.shade400,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.security,
                    color: _isDeviceOwner ? Colors.greenAccent : Colors.purpleAccent,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'وضع مالك الجهاز (Device Owner)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isDeviceOwner ? Colors.green.shade900 : Colors.red.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _isDeviceOwner ? 'مفعل 🟢' : 'غير مفعل 🔴',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _isDeviceOwner
                ? 'الجهاز محمي بأقصى صلاحيات Android Enterprise للمؤسسات. لا يمكن للطفل إلغاء التثبيت أو عمل ضبط مصنع.'
                : 'التطبيق يعمل بالوضع القياسي (مسؤول جهاز: ${_isDeviceAdmin ? "مفعل" : "غير مفعل"}). يمكنك تفعيله كـ Device Owner لمنع الحذف وإعادة ضبط المصنع نهائياً.',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildProtectionsMatrix() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'حالة الحمايات والسياسات المؤسسية',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildPolicyRow('حظر إلغاء التثبيت', 'setUninstallBlocked', _isDeviceOwner),
          _buildPolicyRow('منع ضبط المصنع (الفورمات)', 'DISALLOW_FACTORY_RESET', _isDeviceOwner),
          _buildPolicyRow('منع الوضع الآمن (Safe Boot)', 'DISALLOW_SAFE_BOOT', _isDeviceOwner),
          _buildPolicyRow('منع إيقاف الوصول والموقع', 'DISALLOW_APPS_CONTROL', _isDeviceOwner),
          _buildPolicyRow('كاشف تبديل شريحة الـ SIM', 'SIM_STATE_CHANGED', true),
          _buildPolicyRow('كاشف وضع الطيران', 'AIRPLANE_MODE_CHANGED', true),
        ],
      ),
    );
  }

  Widget _buildPolicyRow(String title, String subtitle, bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
            ],
          ),
          Text(
            active ? 'محمي 🔒' : 'غير نشط ⚠️',
            style: TextStyle(
              color: active ? Colors.greenAccent : Colors.orangeAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdbMethodCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.terminal, color: Colors.cyanAccent, size: 22),
              SizedBox(width: 8),
              Text(
                'الطريقة الأولى: أمر ADB الجاهز (نسخة واحدة)',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'صل جهاز الطفل بالكمبيوتر ونفذ الأمر التالي عبر سطر الأوامر:',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade800),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _adbCommand,
                    style: const TextStyle(color: Colors.lightBlueAccent, fontFamily: 'monospace', fontSize: 11),
                    textDirection: TextDirection.ltr,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.cyanAccent, size: 20),
                  tooltip: 'نسخ',
                  onPressed: _copyAdbCommand,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrMethodCard() {
    final qrData = jsonEncode({
      "android.app.extra.PROVISIONING_DEVICE_ADMIN_COMPONENT_NAME":
          "com.parentalcontrol.kidsagent/com.parentalcontrol.kidsagent.service.AgentDeviceAdminReceiver",
      "android.app.extra.PROVISIONING_LEAVE_ALL_SYSTEM_APPS_ENABLED": true,
      "android.app.extra.PROVISIONING_SKIP_ENCRYPTION": true
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Row(
            children: [
              Icon(Icons.qr_code, color: Colors.tealAccent, size: 22),
              SizedBox(width: 8),
              Text(
                'الطريقة الثانية: رمز QR بعد إعادة ضبط المصنع',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'عند تشغيل الجهاز الجديد أو المفرمت، انقر 6 مرات متتالية على شاشة الترحيب البيضاء لمسح الرمز أدناه:',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 160.0,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Android Enterprise Provisioning Ready',
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
