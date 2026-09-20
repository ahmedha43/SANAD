import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/websocket_service.dart';
import 'route_history_screen.dart';

class GeofenceManagerScreen extends StatefulWidget {
  final Map<String, dynamic> device;

  const GeofenceManagerScreen({super.key, required this.device});

  @override
  State<GeofenceManagerScreen> createState() => _GeofenceManagerScreenState();
}

class _GeofenceManagerScreenState extends State<GeofenceManagerScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late TabController _tabController;
  StreamSubscription? _wsSub;

  bool _isLoading = true;
  bool _isSaving = false;
  List<dynamic> _geofences = [];
  List<dynamic> _breachEvents = [];

  // Map & Designer State
  LatLng _childLocation = const LatLng(33.4884, 43.2138); // Fallback to region
  LatLng? _selectedCenter;
  double _selectedRadius = 300.0;
  String _triggerType = 'both'; // 'both', 'exit', 'enter'
  bool _isCreatingMode = false;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initChildLocation();
    _loadAll();
    _listenToLiveUpdates();
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _tabController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _initChildLocation() {
    final lastLoc = widget.device['last_location'];
    if (lastLoc != null && lastLoc['latitude'] != null && lastLoc['longitude'] != null) {
      _childLocation = LatLng(
        (lastLoc['latitude'] as num).toDouble(),
        (lastLoc['longitude'] as num).toDouble(),
      );
      _selectedCenter = _childLocation;
    }
  }

  void _listenToLiveUpdates() {
    _wsSub = WebSocketService().messageStream.listen((msg) {
      if (msg['type'] == 'LOCATION_UPDATE' && msg['from'] == widget.device['id']) {
        final payload = msg['payload'];
        if (payload != null && payload['latitude'] != null && payload['longitude'] != null) {
          if (mounted) {
            setState(() {
              _childLocation = LatLng(
                (payload['latitude'] as num).toDouble(),
                (payload['longitude'] as num).toDouble(),
              );
            });
          }
        }
      }
    });
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchLatestLocation(),
      _fetchGeofences(),
      _fetchBreachEvents(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchLatestLocation() async {
    final deviceId = widget.device['id'];
    if (deviceId == null) return;
    try {
      final res = await ApiClient.get(ApiConstants.latestLocationUrl(deviceId));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final loc = data is Map ? (data['data'] ?? data['location'] ?? data) : null;
        if (loc != null && loc['latitude'] != null && loc['longitude'] != null) {
          final lat = (loc['latitude'] as num).toDouble();
          final lng = (loc['longitude'] as num).toDouble();
          if (mounted) {
            setState(() {
              _childLocation = LatLng(lat, lng);
              if (_selectedCenter == null || !_isCreatingMode) {
                _selectedCenter = _childLocation;
              }
            });
            _mapController.move(_childLocation, 15);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchGeofences() async {
    final childId = widget.device['child_id'] ?? widget.device['child']?['id'];
    if (childId == null) return;
    try {
      final res = await ApiClient.get(ApiConstants.childGeofencesUrl(childId));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data is List ? data : (data['data'] is List ? data['data'] : []);
        if (list is List) {
          setState(() {
            _geofences = list;
          });
        }
      }
    } catch (_) {
      // Ignored
    }
  }

  Future<void> _fetchBreachEvents() async {
    final childId = widget.device['child_id'] ?? widget.device['child']?['id'];
    if (childId == null) return;
    try {
      final res = await ApiClient.get(ApiConstants.childGeofenceEventsUrl(childId));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data is List ? data : (data['data'] is List ? data['data'] : []);
        if (list is List) {
          setState(() {
            _breachEvents = list;
          });
        }
      }
    } catch (_) {
      // Ignored
    }
  }

  void _startCreatingZone() {
    setState(() {
      _isCreatingMode = true;
      _selectedCenter ??= _childLocation;
      if (_nameController.text.isEmpty) {
        _nameController.text = 'المدرسة';
      }
    });
    if (_selectedCenter != null) {
      _mapController.move(_selectedCenter!, 15);
    }
  }

  void _cancelCreatingZone() {
    setState(() {
      _isCreatingMode = false;
      _nameController.clear();
    });
  }

  void _applyPreset(String name, double radius) {
    setState(() {
      _nameController.text = name;
      _selectedRadius = radius;
    });
  }

  void _onMapTap(LatLng point) {
    if (_isCreatingMode) {
      setState(() {
        _selectedCenter = point;
      });
    }
  }

  void _focusZone(dynamic gf) {
    final lat = (gf['latitude'] as num).toDouble();
    final lng = (gf['longitude'] as num).toDouble();
    _mapController.move(LatLng(lat, lng), 16);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم تكبير خريطة المنطقة: ${gf['name']}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _saveGeofence() async {
    final childId = widget.device['child_id'] ?? widget.device['child']?['id'];
    if (childId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم العثور على طفل مرتبط')),
      );
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال اسم المنطقة الآمنة')),
      );
      return;
    }

    final center = _selectedCenter ?? _childLocation;
    final alertOnEntry = _triggerType == 'both' || _triggerType == 'enter';
    final alertOnExit = _triggerType == 'both' || _triggerType == 'exit';

    setState(() => _isSaving = true);

    final body = {
      'child_id': childId,
      'name': name,
      'latitude': center.latitude,
      'longitude': center.longitude,
      'radius': _selectedRadius.toInt(),
      'radius_meters': _selectedRadius.toInt(),
      'trigger_type': _triggerType,
      'alert_on_entry': alertOnEntry,
      'alert_on_exit': alertOnExit,
    };

    try {
      final res = await ApiClient.post(ApiConstants.geofencesUrl, body);
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ تم إنشاء وتفعيل المنطقة الآمنة "$name" بنجاح'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        _cancelCreatingZone();
        await _fetchGeofences();
      } else {
        throw Exception('Server returned ${res.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل حفظ المنطقة: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteGeofence(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('حذف المنطقة الآمنة'),
        content: Text('هل أنت متأكد من رغبتك في حذف المنطقة "$name"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await ApiClient.delete(ApiConstants.deleteGeofenceUrl(id));
      if (res.statusCode == 200) {
        setState(() {
          _geofences.removeWhere((g) => g['id'] == id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف المنطقة الآمنة'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحذف: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  String _formatEventTime(dynamic timeVal) {
    if (timeVal == null) return 'قبل قليل';
    try {
      final dt = DateTime.tryParse(timeVal.toString());
      if (dt != null) {
        final localDt = dt.toLocal();
        return '${localDt.year}/${localDt.month}/${localDt.day} - ${localDt.hour.toString().padLeft(2, '0')}:${localDt.minute.toString().padLeft(2, '0')}';
      }
      return timeVal.toString();
    } catch (_) {
      return timeVal.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final childName = widget.device['child']?['name'] ?? widget.device['device_name'] ?? 'Child';

    return Scaffold(
      appBar: AppBar(
        title: Text('المناطق الآمنة - $childName'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF10B981),
          tabs: [
            Tab(
              icon: const Icon(Icons.shield_outlined),
              text: 'الخريطة والمناطق (${_geofences.length})',
            ),
            Tab(
              icon: const Icon(Icons.history_toggle_off),
              text: 'سجل التجاوزات (${_breachEvents.length})',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: _loadAll,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMapAndZonesTab(),
                _buildBreachEventsTab(),
              ],
            ),
    );
  }

  Widget _buildMapAndZonesTab() {
    return Column(
      children: [
        // 1. Interactive Map Section (Top Half)
        Expanded(
          flex: _isCreatingMode ? 5 : 4,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _childLocation,
                  initialZoom: 14.5,
                  onTap: (tapPosition, point) => _onMapTap(point),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.parentalcontrol.parentapp',
                  ),
                  // Active Geofence Circles Layer
                  CircleLayer(
                    circles: [
                      // Render all active saved geofences
                      ..._geofences.map((gf) {
                        final lat = (gf['latitude'] as num).toDouble();
                        final lng = (gf['longitude'] as num).toDouble();
                        final rad = ((gf['radius_meters'] ?? gf['radius'] ?? 300) as num).toDouble();
                        return CircleMarker(
                          point: LatLng(lat, lng),
                          radius: rad,
                          useRadiusInMeter: true,
                          color: const Color(0x2810B981),
                          borderColor: const Color(0xFF10B981),
                          borderStrokeWidth: 2,
                        );
                      }),
                      // Live Designer Preview Circle
                      if (_isCreatingMode && _selectedCenter != null)
                        CircleMarker(
                          point: _selectedCenter!,
                          radius: _selectedRadius,
                          useRadiusInMeter: true,
                          color: const Color(0x3338BDF8),
                          borderColor: const Color(0xFF38BDF8),
                          borderStrokeWidth: 3,
                        ),
                    ],
                  ),
                  // Markers Layer
                  MarkerLayer(
                    markers: [
                      // Child Live Marker
                      Marker(
                        point: _childLocation,
                        width: 44,
                        height: 44,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.5),
                                blurRadius: 10,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.child_care, color: Colors.white, size: 24),
                        ),
                      ),
                      // Saved Geofences Centers Labels
                      for (final gf in _geofences)
                        Marker(
                          point: LatLng(
                            (gf['latitude'] as num).toDouble(),
                            (gf['longitude'] as num).toDouble(),
                          ),
                          width: 100,
                          height: 32,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xDD0F172A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF10B981)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.shield, size: 12, color: Color(0xFF10B981)),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    gf['name'] ?? '',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Designer Draggable/Selected Pin
                      if (_isCreatingMode && _selectedCenter != null)
                        Marker(
                          point: _selectedCenter!,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_on, color: Color(0xFF38BDF8), size: 40),
                        ),
                    ],
                  ),
                ],
              ),

              // Top Map Floating Status Pill
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xE60F172A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isCreatingMode ? Icons.edit_location_alt : Icons.touch_app,
                          size: 16,
                          color: _isCreatingMode ? const Color(0xFF38BDF8) : const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isCreatingMode
                              ? 'انقر على الخريطة لتحديد مركز المنطقة الآمنة'
                              : 'انقر على "+ إضافة منطقة" لتحديد محيط أمان جديد',
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Floating Map Shortcut Buttons
              Positioned(
                bottom: 12,
                right: 12,
                child: Column(
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'centerChild',
                      backgroundColor: const Color(0xFF1E293B),
                      onPressed: () => _mapController.move(_childLocation, 15),
                      child: const Icon(Icons.my_location, color: Color(0xFF10B981)),
                    ),
                    const SizedBox(height: 8),
                    if (_isCreatingMode)
                      FloatingActionButton.small(
                        heroTag: 'useChildAsCenter',
                        tooltip: 'استخدام موقع الطفل كمركز',
                        backgroundColor: const Color(0xFF1E293B),
                        onPressed: () {
                          setState(() => _selectedCenter = _childLocation);
                          _mapController.move(_childLocation, 15);
                        },
                        child: const Icon(Icons.child_care, color: Color(0xFF38BDF8)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 2. Bottom Controls / Zones List Section
        Expanded(
          flex: _isCreatingMode ? 6 : 5,
          child: Container(
            color: const Color(0xFF0F172A),
            child: _isCreatingMode ? _buildDesignerPanel() : _buildActiveZonesList(),
          ),
        ),
      ],
    );
  }

  // Interactive Zone Designer Card
  Widget _buildDesignerPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.add_location_alt, color: Color(0xFF10B981), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'تحديد محيط الأمان التفاعلي',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: _cancelCreatingZone,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Zone Name Field
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'اسم المنطقة الآمنة (مثال: المدرسة، المنزل)',
              filled: true,
              fillColor: const Color(0xFF1E293B),
              prefixIcon: const Icon(Icons.label_outline, color: Color(0xFF10B981)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),

          // Quick Presets
          const Text('نماذج سريعة جاهزة:', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _presetChip('🏠 المنزل', 'المنزل', 150),
                _presetChip('🏫 المدرسة', 'المدرسة', 300),
                _presetChip('⚽ النادي', 'النادي الرياضي', 500),
                _presetChip('🏘️ الحي', 'الحي السكني', 1000),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Radius Slider
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('نصف قطر الدائرة (محيط الأمان):',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_selectedRadius.toInt()} متر',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _selectedRadius,
                  min: 50,
                  max: 3000,
                  divisions: 59,
                  activeColor: const Color(0xFF10B981),
                  inactiveColor: Colors.grey.shade700,
                  onChanged: (v) => setState(() => _selectedRadius = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Trigger Alert Type Selection
          DropdownButtonFormField<String>(
            initialValue: _triggerType,
            dropdownColor: const Color(0xFF1E293B),
            decoration: InputDecoration(
              labelText: 'نوع التنبيه المطلوب',
              filled: true,
              fillColor: const Color(0xFF1E293B),
              prefixIcon: const Icon(Icons.notifications_active_outlined, color: Color(0xFF10B981)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'both', child: Text('عند الدخول والخروج معاً 🔄 (موصى به)')),
              DropdownMenuItem(value: 'exit', child: Text('عند الخروج فقط 🚨 (تنبيه التجاوز)')),
              DropdownMenuItem(value: 'enter', child: Text('عند الدخول والوصول فقط 🟢')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _triggerType = val);
            },
          ),
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveGeofence,
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline),
                  label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ وتفعيل المنطقة الآمنة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _cancelCreatingZone,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('إلغاء'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _presetChip(String label, String name, double radius) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        backgroundColor: const Color(0xFF1E293B),
        side: const BorderSide(color: Colors.white24),
        onPressed: () => _applyPreset(name, radius),
      ),
    );
  }

  // Active Zones List
  Widget _buildActiveZonesList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield, color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'المناطق الآمنة النشطة (${_geofences.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('إضافة منطقة جديدة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _startCreatingZone,
              ),
            ],
          ),
        ),
        Expanded(
          child: _geofences.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fence, size: 54, color: Colors.grey.shade600),
                      const SizedBox(height: 10),
                      const Text('لا توجد مناطق آمنة محددة بعد',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('انقر على "إضافة منطقة جديدة" لرسم محيط المدرسة أو المنزل',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: _geofences.length,
                  itemBuilder: (context, idx) {
                    final gf = _geofences[idx];
                    final radius = gf['radius_meters'] ?? gf['radius'] ?? 300;
                    return Card(
                      color: const Color(0xFF1E293B),
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 22),
                        ),
                        title: Text(
                          gf['name'] ?? 'منطقة آمنة',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          'نصف القطر: $radius متر • نشطة 🟢',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.center_focus_strong, color: Color(0xFF38BDF8), size: 20),
                              tooltip: 'تكبير على الخريطة',
                              onPressed: () => _focusZone(gf),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              tooltip: 'حذف',
                              onPressed: () => _deleteGeofence(gf['id'].toString(), gf['name'] ?? ''),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Breach Events History Tab
  Widget _buildBreachEventsTab() {
    if (_breachEvents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_user, size: 64, color: Color(0xFF10B981)),
              ),
              const SizedBox(height: 16),
              const Text(
                'البيئة آمنة تماماً',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'لم يتم رصد أي خروج أو تجاوز للمناطق الجغرافية الآمنة المحددة للطفل.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _breachEvents.length,
      itemBuilder: (context, idx) {
        final ev = _breachEvents[idx];
        final isExit = (ev['event_type'] ?? '').toString().toUpperCase() == 'EXIT';
        final zoneName = ev['geofence_name'] ?? 'المنطقة الآمنة';
        final timeStr = _formatEventTime(ev['triggered_at'] ?? ev['created_at']);

        return Card(
          color: const Color(0xFF1E293B),
          margin: const EdgeInsets.only(bottom: 10),
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
                          isExit ? Icons.warning_rounded : Icons.check_circle_rounded,
                          color: isExit ? Colors.redAccent : const Color(0xFF10B981),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isExit ? 'خروج وتجاوز المحيط' : 'دخول للمنطقة',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isExit ? Colors.redAccent : const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      timeStr,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 16, color: Colors.white70),
                    const SizedBox(width: 6),
                    Text(
                      'المنطقة: $zoneName',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.route, size: 16),
                    label: const Text('عرض بالمسار'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RouteHistoryScreen(device: widget.device),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
