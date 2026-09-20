import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/websocket_service.dart';

class LiveMapScreen extends StatefulWidget {
  final Map<String, dynamic> device;
  const LiveMapScreen({super.key, required this.device});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(24.7136, 46.6753); // Default Riyadh
  final List<LatLng> _breadcrumbTrail = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLocationAndHistory();
    _listenToLiveUpdates();
  }

  Future<void> _loadLocationAndHistory() async {
    final deviceId = widget.device['id'];
    try {
      // Latest location
      final res = await ApiClient.get(ApiConstants.latestLocationUrl(deviceId));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _currentLocation = LatLng(data['latitude'], data['longitude']);
        });
        _mapController.move(_currentLocation, 15);
      }

      // History trail
      final histRes = await ApiClient.get(ApiConstants.locationHistoryUrl(deviceId));
      if (histRes.statusCode == 200) {
        final List list = jsonDecode(histRes.body);
        setState(() {
          _breadcrumbTrail.clear();
          for (var item in list) {
            _breadcrumbTrail.add(LatLng(item['latitude'], item['longitude']));
          }
        });
      }
    } catch (e) {
      // Ignored
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _listenToLiveUpdates() {
    WebSocketService().messageStream.listen((msg) {
      if (msg['type'] == 'LOCATION_UPDATE' && msg['from'] == widget.device['id']) {
        final payload = msg['payload'];
        if (payload != null && payload['latitude'] != null) {
          final newLoc = LatLng(payload['latitude'], payload['longitude']);
          if (mounted) {
            setState(() {
              _currentLocation = newLoc;
              _breadcrumbTrail.add(newLoc);
            });
            _mapController.move(newLoc, 16);
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final childName = widget.device['child']?['name'] ?? widget.device['device_name'];

    return Scaffold(
      appBar: AppBar(
        title: Text('$childName’s Location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () => _mapController.move(_currentLocation, 16),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation,
                    initialZoom: 15.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.parentalcontrol.parentapp',
                    ),
                    // Breadcrumb History Polyline
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _breadcrumbTrail,
                          strokeWidth: 4.0,
                          color: Colors.blueAccent.withOpacity(0.8),
                        ),
                      ],
                    ),
                    // Child Marker
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _currentLocation,
                          width: 60,
                          height: 60,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  childName,
                                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const Icon(Icons.location_pin, color: Colors.redAccent, size: 36),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  bottom: 24,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Live GPS Coordinates',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_currentLocation.latitude.toStringAsFixed(5)}, ${_currentLocation.longitude.toStringAsFixed(5)}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            // Request refresh
                            WebSocketService().sendCommand(widget.device['id'], 'GET_LOCATION');
                          },
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Locate'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
