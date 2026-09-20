import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';

class RouteHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> device;

  const RouteHistoryScreen({super.key, required this.device});

  @override
  State<RouteHistoryScreen> createState() => _RouteHistoryScreenState();
}

class _RouteHistoryScreenState extends State<RouteHistoryScreen> {
  final MapController _mapController = MapController();
  bool _isLoading = true;
  List<Map<String, dynamic>> _historyPoints = [];
  List<Map<String, dynamic>> _geofences = [];
  final List<Map<String, dynamic>> _breachEvents = [];
  final List<List<LatLng>> _breachSegments = [];
  int _selectedHours = 24;
  int _currentIndex = 0;
  bool _isPlaying = false;
  Timer? _playbackTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchGeofences(),
      _fetchHistory(),
    ]);
    _calculateBreaches();
    if (mounted) setState(() => _isLoading = false);
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
          _geofences = list.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (_) {
      // Ignored
    }
  }

  Future<void> _fetchHistory() async {
    _stopPlayback();
    final deviceId = widget.device['id'];
    try {
      final url = '${ApiConstants.locationHistoryUrl(deviceId)}?hours=$_selectedHours';
      final res = await ApiClient.get(url);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body);
        if (list is List) {
          final points = list.map((e) => Map<String, dynamic>.from(e)).toList();
          // Sort chronologically (oldest to newest)
          points.sort((a, b) {
            final t1 = (a['recorded_at'] ?? a['timestamp'] ?? 0).toString();
            final t2 = (b['recorded_at'] ?? b['timestamp'] ?? 0).toString();
            return t1.compareTo(t2);
          });

          _historyPoints = points;
          _currentIndex = points.isNotEmpty ? points.length - 1 : 0;

          if (points.isNotEmpty) {
            final last = points.last;
            final lat = (last['latitude'] as num).toDouble();
            final lng = (last['longitude'] as num).toDouble();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _mapController.move(LatLng(lat, lng), 15);
            });
          }
        }
      }
    } catch (_) {
      // Ignored
    }
  }

  void _calculateBreaches() {
    _breachEvents.clear();
    _breachSegments.clear();
    if (_historyPoints.isEmpty) return;

    if (_geofences.isEmpty) {
      for (final pt in _historyPoints) {
        pt['isBreach'] = false;
        pt['zoneName'] = '';
      }
      return;
    }

    const distanceCalc = Distance();
    bool wasInside = true;
    List<LatLng> currentSegment = [];

    for (int i = 0; i < _historyPoints.length; i++) {
      final pt = _historyPoints[i];
      final lat = (pt['latitude'] as num).toDouble();
      final lng = (pt['longitude'] as num).toDouble();
      final latLng = LatLng(lat, lng);

      bool insideAny = false;
      String nearestZone = '';
      double minDistance = double.infinity;

      for (final f in _geofences) {
        final fLat = (f['latitude'] as num).toDouble();
        final fLng = (f['longitude'] as num).toDouble();
        final fRadius = ((f['radius_meters'] ?? f['radius'] ?? 300) as num).toDouble();
        final dist = distanceCalc.as(LengthUnit.Meter, latLng, LatLng(fLat, fLng));

        if (dist <= fRadius) {
          insideAny = true;
          nearestZone = (f['name'] ?? 'المنطقة الآمنة').toString();
        }
        if (dist < minDistance) {
          minDistance = dist;
          if (nearestZone.isEmpty) nearestZone = (f['name'] ?? 'المنطقة الآمنة').toString();
        }
      }

      pt['isBreach'] = !insideAny;
      pt['zoneName'] = nearestZone;

      if (!insideAny) {
        currentSegment.add(latLng);
        // Detect transition from inside to outside
        if (wasInside && i > 0) {
          final timeStr = _formatPointTime(pt['recorded_at'] ?? pt['timestamp']);
          final speed = pt['speed'] != null ? ((pt['speed'] as num) * 3.6).round() : 0;
          _breachEvents.add({
            'index': i,
            'point': latLng,
            'time': timeStr,
            'speed': speed,
            'zone': nearestZone,
            'distanceOutside': minDistance.round(),
          });
        }
      } else {
        if (currentSegment.length > 1) {
          _breachSegments.add(List.from(currentSegment));
        }
        currentSegment.clear();
      }

      wasInside = insideAny;
    }

    if (currentSegment.length > 1) {
      _breachSegments.add(List.from(currentSegment));
    }
  }

  void _startPlayback() {
    if (_historyPoints.isEmpty) return;
    setState(() {
      _isPlaying = true;
      if (_currentIndex >= _historyPoints.length - 1) {
        _currentIndex = 0;
      }
    });

    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_currentIndex < _historyPoints.length - 1) {
        setState(() {
          _currentIndex++;
        });
        final pt = _historyPoints[_currentIndex];
        final lat = (pt['latitude'] as num).toDouble();
        final lng = (pt['longitude'] as num).toDouble();
        _mapController.move(LatLng(lat, lng), _mapController.camera.zoom);
      } else {
        _stopPlayback();
      }
    });
  }

  void _stopPlayback() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    if (mounted && _isPlaying) {
      setState(() => _isPlaying = false);
    }
  }

  String _formatPointTime(dynamic timeVal) {
    if (timeVal == null) return '';
    try {
      if (timeVal is int) {
        final dt = DateTime.fromMillisecondsSinceEpoch(timeVal);
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
      }
      final dt = DateTime.tryParse(timeVal.toString());
      if (dt != null) {
        final localDt = dt.toLocal();
        return '${localDt.hour.toString().padLeft(2, '0')}:${localDt.minute.toString().padLeft(2, '0')}:${localDt.second.toString().padLeft(2, '0')}';
      }
      return timeVal.toString();
    } catch (_) {
      return '';
    }
  }

  void _showBreachDetailsModal(Map<String, dynamic> ev) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2230),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('تجاوز محيط المنطقة الآمنة!',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.redAccent)),
                      Text('تم رصد خروج الطفل خارج نطاق الحماية المحدد',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Colors.white12),
            _infoRow(Icons.shield_outlined, 'المنطقة الآمنة المتجاوزة', ev['zone'].toString()),
            const SizedBox(height: 8),
            _infoRow(Icons.access_time, 'توقيت لحظة الخروج', ev['time'].toString()),
            const SizedBox(height: 8),
            _infoRow(Icons.speed, 'السرعة عند التجاوز', '${ev['speed']} كم/س'),
            const SizedBox(height: 8),
            _infoRow(Icons.social_distance, 'المسافة خارج المحيط', '${ev['distanceOutside']} متر'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('انتقال إلى هذه اللحظة في المسار'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _stopPlayback();
                  final idx = ev['index'] as int;
                  setState(() => _currentIndex = idx);
                  _mapController.move(ev['point'] as LatLng, 16);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white70),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontSize: 13, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final childName = widget.device['child']?['name'] ?? widget.device['device_name'] ?? 'Child';
    final pointsLatLng = _historyPoints.map((p) {
      final lat = (p['latitude'] as num).toDouble();
      final lng = (p['longitude'] as num).toDouble();
      return LatLng(lat, lng);
    }).toList();

    final currentPoint = _historyPoints.isNotEmpty && _currentIndex < _historyPoints.length
        ? _historyPoints[_currentIndex]
        : null;

    final currentLatLng = currentPoint != null
        ? LatLng(
            (currentPoint['latitude'] as num).toDouble(),
            (currentPoint['longitude'] as num).toDouble(),
          )
        : const LatLng(24.7136, 46.6753);

    final isCurrentPointBreach = currentPoint != null && currentPoint['isBreach'] == true;

    return Scaffold(
      appBar: AppBar(
        title: Text('مسار الرحلات - $childName'),
        actions: [
          DropdownButton<int>(
            value: _selectedHours,
            dropdownColor: const Color(0xFF1E2230),
            underline: const SizedBox(),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            items: const [
              DropdownMenuItem(value: 6, child: Text('آخر 6 ساعات')),
              DropdownMenuItem(value: 12, child: Text('آخر 12 ساعة')),
              DropdownMenuItem(value: 24, child: Text('آخر 24 ساعة')),
              DropdownMenuItem(value: 48, child: Text('آخر 48 ساعة')),
            ],
            onChanged: (val) {
              if (val != null && val != _selectedHours) {
                setState(() => _selectedHours = val);
                _loadData();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث المسار',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _historyPoints.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.route_outlined, size: 64, color: Colors.grey.shade600),
                      const SizedBox(height: 16),
                      const Text('لا توجد رحلات مسجلة في هذه الفترة',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('سيتم تسجيل المسار تلقائياً مع تحرك الطفل بالهاتف',
                          style: TextStyle(color: Colors.grey.shade400)),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: currentLatLng,
                        initialZoom: 15.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.parentalcontrol.parentapp',
                        ),
                        // 1. Safe Zones Circles Layer
                        CircleLayer(
                          circles: _geofences.map((f) {
                            final lat = (f['latitude'] as num).toDouble();
                            final lng = (f['longitude'] as num).toDouble();
                            final rad = ((f['radius_meters'] ?? f['radius'] ?? 300) as num).toDouble();
                            return CircleMarker(
                              point: LatLng(lat, lng),
                              radius: rad,
                              useRadiusInMeter: true,
                              color: const Color(0x2210B981),
                              borderColor: const Color(0xFF10B981),
                              borderStrokeWidth: 2,
                            );
                          }).toList(),
                        ),
                        // 2. Historical Route Polylines
                        PolylineLayer(
                          polylines: [
                            // Normal Full Route Polyline (cyan)
                            Polyline(
                              points: pointsLatLng,
                              strokeWidth: 4.5,
                              color: Colors.cyanAccent.withValues(alpha: 0.65),
                            ),
                            // Safe Zone Breach Segments (BOLD RED)
                            for (final seg in _breachSegments)
                              Polyline(
                                points: seg,
                                strokeWidth: 6.0,
                                color: Colors.redAccent,
                              ),
                            // Traversed progress up to current scrubber index (amber)
                            if (_currentIndex > 0)
                              Polyline(
                                points: pointsLatLng.take(_currentIndex + 1).toList(),
                                strokeWidth: 5.5,
                                color: Colors.amberAccent,
                              ),
                          ],
                        ),
                        // 3. Markers Layer
                        MarkerLayer(
                          markers: [
                            // Safe Zones Center Labels
                            for (final f in _geofences)
                              Marker(
                                point: LatLng(
                                  (f['latitude'] as num).toDouble(),
                                  (f['longitude'] as num).toDouble(),
                                ),
                                width: 90,
                                height: 32,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xCC064E3B),
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
                                          f['name'] ?? '',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            // Start Point
                            if (pointsLatLng.isNotEmpty)
                              Marker(
                                point: pointsLatLng.first,
                                width: 40,
                                height: 40,
                                child: const Icon(Icons.flag_circle, color: Colors.greenAccent, size: 36),
                              ),
                            // End Point
                            if (pointsLatLng.length > 1)
                              Marker(
                                point: pointsLatLng.last,
                                width: 40,
                                height: 40,
                                child: const Icon(Icons.flag_circle, color: Colors.blueAccent, size: 36),
                              ),
                            // Safe Zone Breach Warning Markers (🚨)
                            for (final ev in _breachEvents)
                              Marker(
                                point: ev['point'] as LatLng,
                                width: 36,
                                height: 36,
                                child: GestureDetector(
                                  onTap: () => _showBreachDetailsModal(ev),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.redAccent.withValues(alpha: 0.6),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                            // Current Scrubber Marker
                            Marker(
                              point: currentLatLng,
                              width: 50,
                              height: 50,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isCurrentPointBreach ? Colors.redAccent : Colors.amberAccent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isCurrentPointBreach ? Colors.redAccent : Colors.amberAccent).withValues(alpha: 0.6),
                                      blurRadius: 10,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isCurrentPointBreach ? Icons.warning_rounded : Icons.directions_walk,
                                  color: isCurrentPointBreach ? Colors.white : Colors.black,
                                  size: 26,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Floating Timeline & Breach Controls Card
                    Positioned(
                      bottom: 20,
                      left: 16,
                      right: 16,
                      child: Card(
                        color: const Color(0xFF1A1F2C).withValues(alpha: 0.96),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 10,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Breach Summary Quick-Jump Chips (if breaches detected)
                              if (_breachEvents.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                                              const SizedBox(width: 6),
                                              Text(
                                                'رصد ${_breachEvents.length} تجاوزات للمناطق الآمنة',
                                                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                            ],
                                          ),
                                          const Text(
                                            'انقر للقفز',
                                            style: TextStyle(fontSize: 10, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: _breachEvents.map((ev) {
                                            return Padding(
                                              padding: const EdgeInsets.only(left: 6),
                                              child: InkWell(
                                                onTap: () {
                                                  _stopPlayback();
                                                  final idx = ev['index'] as int;
                                                  setState(() => _currentIndex = idx);
                                                  _mapController.move(ev['point'] as LatLng, _mapController.camera.zoom);
                                                },
                                                borderRadius: BorderRadius.circular(16),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.redAccent.withValues(alpha: 0.25),
                                                    borderRadius: BorderRadius.circular(16),
                                                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.location_on, size: 12, color: Colors.redAccent),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '${ev['zone']} • ${ev['time']}',
                                                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Playback Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill),
                                        color: isCurrentPointBreach ? Colors.redAccent : Colors.cyanAccent,
                                        iconSize: 38,
                                        onPressed: _isPlaying ? _stopPlayback : _startPlayback,
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                'النقطة ${_currentIndex + 1} من ${_historyPoints.length}',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                              ),
                                              if (isCurrentPointBreach) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.redAccent,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text(
                                                    '⚠️ متجاوز للمحيط!',
                                                    style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          if (currentPoint != null)
                                            Text(
                                              'الوقت: ${_formatPointTime(currentPoint['recorded_at'] ?? currentPoint['timestamp'])}',
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (currentPoint != null && currentPoint['speed'] != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: (isCurrentPointBreach ? Colors.redAccent : Colors.blueAccent).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'السرعة: ${((currentPoint['speed'] as num) * 3.6).toStringAsFixed(0)} كم/س',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isCurrentPointBreach ? Colors.redAccent : Colors.blueAccent,
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              // Timeline Slider
                              if (_historyPoints.length > 1)
                                Slider(
                                  value: _currentIndex.toDouble(),
                                  min: 0,
                                  max: (_historyPoints.length - 1).toDouble(),
                                  divisions: _historyPoints.length - 1,
                                  activeColor: isCurrentPointBreach ? Colors.redAccent : Colors.amberAccent,
                                  inactiveColor: Colors.grey.shade700,
                                  onChanged: (val) {
                                    _stopPlayback();
                                    final idx = val.round();
                                    setState(() => _currentIndex = idx);
                                    final pt = _historyPoints[idx];
                                    final lat = (pt['latitude'] as num).toDouble();
                                    final lng = (pt['longitude'] as num).toDouble();
                                    _mapController.move(LatLng(lat, lng), _mapController.camera.zoom);
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
