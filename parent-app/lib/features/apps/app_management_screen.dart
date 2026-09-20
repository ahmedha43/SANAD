import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/websocket_service.dart';

class AppManagementScreen extends StatefulWidget {
  final Map<String, dynamic> device;
  const AppManagementScreen({super.key, required this.device});

  @override
  State<AppManagementScreen> createState() => _AppManagementScreenState();
}

class _AppManagementScreenState extends State<AppManagementScreen> {
  List<dynamic> _apps = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    try {
      final res = await ApiClient.get(ApiConstants.deviceAppsUrl(widget.device['id']));
      if (res.statusCode == 200) {
        setState(() {
          _apps = jsonDecode(res.body);
        });
      }
    } catch (e) {
      // Ignored
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleBlock(Map<String, dynamic> app, bool blocked) async {
    final pkg = app['package_name'];
    setState(() {
      app['is_blocked'] = blocked;
    });

    try {
      // 1. Update backend DB
      await ApiClient.post(ApiConstants.blockAppUrl(widget.device['id']), {
        'package_name': pkg,
        'is_blocked': blocked,
      });

      // 2. Dispatch immediate command over WebSocket to Kid Agent
      final action = blocked ? 'BLOCK_APP' : 'UNBLOCK_APP';
      WebSocketService().sendCommand(widget.device['id'], action, {'package_name': pkg});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(blocked ? 'Blocked ${app['app_name']}' : 'Unblocked ${app['app_name']}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Revert on error
      setState(() {
        app['is_blocked'] = !blocked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredApps = _apps.where((a) {
      final name = (a['app_name'] as String? ?? '').toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Limits & Blocking'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search installed applications...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredApps.isEmpty
                    ? const Center(child: Text('No applications found.'))
                    : ListView.separated(
                        itemCount: filteredApps.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final app = filteredApps[index];
                          final isBlocked = app['is_blocked'] == true;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isBlocked ? Colors.red.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                              child: Icon(
                                isBlocked ? Icons.block : Icons.android,
                                color: isBlocked ? Colors.red : Colors.blue,
                              ),
                            ),
                            title: Text(
                              app['app_name'] ?? 'Unknown App',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                decoration: isBlocked ? TextDecoration.lineThrough : null,
                                color: isBlocked ? Colors.redAccent : Colors.white,
                              ),
                            ),
                            subtitle: Text(
                              app['package_name'] ?? '',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            trailing: Switch(
                              value: isBlocked,
                              activeColor: Colors.red,
                              onChanged: (val) => _toggleBlock(app, val),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
