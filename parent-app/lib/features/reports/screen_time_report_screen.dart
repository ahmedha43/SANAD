import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';

class ScreenTimeReportScreen extends StatefulWidget {
  final Map<String, dynamic> device;
  const ScreenTimeReportScreen({super.key, required this.device});

  @override
  State<ScreenTimeReportScreen> createState() => _ScreenTimeReportScreenState();
}

class _ScreenTimeReportScreenState extends State<ScreenTimeReportScreen> {
  List<dynamic> _usageList = [];
  bool _isLoading = true;
  int _totalSeconds = 0;

  @override
  void initState() {
    super.initState();
    _loadDailyUsage();
  }

  Future<void> _loadDailyUsage() async {
    try {
      final res = await ApiClient.get(ApiConstants.deviceUsageUrl(widget.device['id']));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        int total = 0;
        for (var item in list) {
          total += (item['usage_duration_seconds'] as num? ?? 0).toInt();
        }
        setState(() {
          _usageList = list;
          _totalSeconds = total;
        });
      }
    } catch (e) {
      // Ignored
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${mins}m';
    return '${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Screen Time & Activity Report')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Today's Screen Time",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatDuration(_totalSeconds),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Chart Card
                  const Text(
                    'App Usage Breakdown',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 220,
                    padding: const EdgeInsets.only(top: 20, right: 20, left: 10, bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: _usageList.isEmpty
                        ? const Center(child: Text('No activity data recorded yet today'))
                        : BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: (_usageList.first['usage_duration_seconds'] as num? ?? 100) / 60.0 * 1.2,
                              barTouchData: BarTouchData(enabled: true),
                              titlesData: const FlTitlesData(
                                show: true,
                                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              barGroups: List.generate(
                                _usageList.take(5).length,
                                (i) {
                                  final item = _usageList[i];
                                  final minutes = (item['usage_duration_seconds'] as num? ?? 0) / 60.0;
                                  return BarChartGroupData(
                                    x: i,
                                    barRods: [
                                      BarChartRodData(
                                        toY: minutes,
                                        color: const Color(0xFF38BDF8),
                                        width: 16,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 28),

                  // App Ranking List
                  const Text(
                    'Top Applications',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _usageList.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _usageList[index];
                      final seconds = (item['usage_duration_seconds'] as num? ?? 0).toInt();
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF334155),
                          child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        title: Text(item['package_name'] ?? 'App'),
                        trailing: Text(
                          _formatDuration(seconds),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
