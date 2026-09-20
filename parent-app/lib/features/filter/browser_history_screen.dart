import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/websocket_service.dart';

class BrowserHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> device;
  const BrowserHistoryScreen({super.key, required this.device});

  @override
  State<BrowserHistoryScreen> createState() => _BrowserHistoryScreenState();
}

class _BrowserHistoryScreenState extends State<BrowserHistoryScreen> {
  bool _isLoading = true;
  List<dynamic> _history = [];
  Map<String, dynamic>? _stats;
  String _selectedFilter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final deviceId = widget.device['id'];
      final historyRes = await ApiClient.get(ApiConstants.browserHistoryUrl(deviceId, limit: 150));
      final statsRes = await ApiClient.get(ApiConstants.browserHistoryStatsUrl(deviceId));

      if (historyRes.statusCode == 200) {
        final data = jsonDecode(utf8.decode(historyRes.bodyBytes));
        setState(() {
          _history = data['history'] ?? [];
        });
      }

      if (statsRes.statusCode == 200) {
        final statsData = jsonDecode(utf8.decode(statsRes.bodyBytes));
        setState(() {
          _stats = statsData;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحميل سجل التصفح: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('مسح سجل التصفح', style: TextStyle(color: Colors.white)),
        content: const Text(
          'هل أنت متأكد من مسح سجل التصفح والبحث لهذا الجهاز نهائياً؟',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('مسح السجل', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await ApiClient.delete(ApiConstants.clearBrowserHistoryUrl(widget.device['id']));
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم مسح سجل التصفح بنجاح'), backgroundColor: Colors.green),
          );
        }
        _loadHistory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل مسح السجل: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _quickBlockDomain(String domain, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('حظر الموقع فوراً', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'هل تريد حظر الموقع "$domain" فوراً وإضافته إلى قائمة الحظر؟',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الحظر', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final deviceId = widget.device['id'];
      
      // 1. Direct web filter rule creation
      await ApiClient.post(ApiConstants.webFilterRulesUrl(deviceId), {
        'rule_type': 'domain',
        'pattern': domain,
        'description': title.isNotEmpty ? 'حظر فوري: $title' : 'حظر فوري للنطاق: $domain',
        'action': 'block',
        'category': 'custom',
      });

      // 2. Browser history quick block
      try {
        await ApiClient.post(ApiConstants.quickBlockBrowserDomainUrl(deviceId), {
          'domain': domain,
          'title': title,
        });
      } catch (_) {}

      // 3. WS update notification
      WebSocketService().sendMessage(
        'WEB_FILTER_UPDATED',
        to: deviceId,
        payload: {
          'is_web_filter_enabled': true,
          'target_domain': domain,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حظر "$domain" فوراً بلحظتها! 🚫'), backgroundColor: Colors.green),
        );
      }

      // Update local state
      setState(() {
        for (var item in _history) {
          if (item['domain'] == domain) {
            item['is_blocked'] = true;
          }
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحظر: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<dynamic> get _filteredHistory {
    var list = List<dynamic>.from(_history);

    if (_selectedFilter == 'searches') {
      list = list.where((i) => i['is_search_query'] == true || (i['search_query'] != null && i['search_query'].toString().isNotEmpty)).toList();
    } else if (_selectedFilter == 'top-visited') {
      list.sort((a, b) => ((b['visit_count'] ?? 1) as num).compareTo((a['visit_count'] ?? 1) as num));
    } else if (_selectedFilter == 'blocked') {
      list = list.where((i) => i['is_blocked'] == true).toList();
    } else if (_selectedFilter == 'chrome') {
      list = list.where((i) => (i['browser'] ?? '').toString().toLowerCase().contains('chrome')).toList();
    } else if (_selectedFilter == 'edge') {
      list = list.where((i) => (i['browser'] ?? '').toString().toLowerCase().contains('edge')).toList();
    } else if (_selectedFilter == 'firefox') {
      list = list.where((i) => (i['browser'] ?? '').toString().toLowerCase().contains('firefox')).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((i) {
        final title = (i['title'] ?? '').toString().toLowerCase();
        final url = (i['url'] ?? '').toString().toLowerCase();
        final query = (i['search_query'] ?? '').toString().toLowerCase();
        final domain = (i['domain'] ?? '').toString().toLowerCase();
        return title.contains(q) || url.contains(q) || query.contains(q) || domain.contains(q);
      }).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text('سجل التصفح والبحث السحابي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
            tooltip: 'تحديث السجل',
            onPressed: _loadHistory,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            tooltip: 'مسح السجل',
            onPressed: _clearHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : RefreshIndicator(
              onRefresh: _loadHistory,
              color: Colors.cyanAccent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsRow(),
                    const SizedBox(height: 16),
                    _buildKeywordsRadar(),
                    const SizedBox(height: 16),
                    _buildSearchBar(),
                    const SizedBox(height: 12),
                    _buildFilterPills(),
                    const SizedBox(height: 14),
                    _buildHistoryList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsRow() {
    final totalVisits = _stats?['total_visits'] ?? _history.length;
    final totalSearches = _stats?['total_searches'] ?? _history.where((i) => i['is_search_query'] == true).length;
    final topDomains = _stats?['top_domains'] as List?;
    final topDomain = (topDomains != null && topDomains.isNotEmpty) ? topDomains[0]['domain'] : '--';
    final blockedCount = _stats?['blocked_hits'] ?? _history.where((i) => i['is_blocked'] == true).length;

    return Row(
      children: [
        Expanded(child: _buildMiniStatCard('عدد المواقع', '$totalVisits', Icons.language, Colors.cyanAccent)),
        const SizedBox(width: 8),
        Expanded(child: _buildMiniStatCard('عمليات البحث', '$totalSearches', Icons.search, Colors.purpleAccent)),
        const SizedBox(width: 8),
        Expanded(child: _buildMiniStatCard('الأكثر زيارة', '$topDomain', Icons.local_fire_department, Colors.amberAccent)),
        const SizedBox(width: 8),
        Expanded(child: _buildMiniStatCard('المحظورة', '$blockedCount', Icons.shield, Colors.redAccent)),
      ],
    );
  }

  Widget _buildMiniStatCard(String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131D33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            val,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 9.5),
          ),
        ],
      ),
    );
  }

  Widget _buildKeywordsRadar() {
    final topSearches = (_stats?['top_searches'] as List?) ?? [];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.travel_explore, color: Colors.purpleAccent, size: 18),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'رادار كلمات البحث (Google & YouTube Cloud)',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('رصد مباشر', style: TextStyle(color: Colors.purpleAccent, fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (topSearches.isEmpty)
            const Text('لا توجد عمليات بحث مسجلة حتى الآن.', style: TextStyle(color: Colors.white54, fontSize: 12))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: topSearches.map((s) {
                final query = s['query'] ?? '';
                final count = s['count'] ?? 1;
                final isYt = query.toString().toLowerCase().contains('youtube') ||
                    query.toString().toLowerCase().contains('فيديو') ||
                    query.toString().toLowerCase().contains('اغنية');
                return InkWell(
                  onTap: () {
                    setState(() {
                      _searchQuery = query;
                      _searchController.text = query;
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isYt ? Colors.red.withOpacity(0.15) : Colors.blue.withOpacity(0.15),
                      border: Border.all(
                        color: isYt ? Colors.redAccent.withOpacity(0.4) : Colors.blueAccent.withOpacity(0.4),
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isYt ? Icons.play_circle_fill : Icons.search,
                          size: 13,
                          color: isYt ? Colors.redAccent : Colors.cyanAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          query,
                          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: (isYt ? Colors.redAccent : Colors.purpleAccent).withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131D33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 13.5),
        decoration: InputDecoration(
          hintText: 'بحث في العناوين أو الروابط أو كلمات البحث...',
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 12.5),
          prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        onChanged: (val) => setState(() => _searchQuery = val),
      ),
    );
  }

  Widget _buildFilterPills() {
    final filters = [
      {'key': 'all', 'label': 'الكل', 'icon': Icons.list},
      {'key': 'searches', 'label': 'بحث 🔍', 'icon': Icons.search},
      {'key': 'top-visited', 'label': 'الأكثر تكراراً 📈', 'icon': Icons.trending_up},
      {'key': 'blocked', 'label': 'المحظورة 🚫', 'icon': Icons.block},
      {'key': 'chrome', 'label': 'Chrome', 'icon': Icons.public},
      {'key': 'edge', 'label': 'Edge', 'icon': Icons.language},
      {'key': 'firefox', 'label': 'Firefox', 'icon': Icons.explore},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f['key'];
          return Padding(
            padding: const EdgeInsets.only(left: 6),
            child: ChoiceChip(
              avatar: Icon(f['icon'] as IconData, size: 14, color: isSelected ? Colors.black : Colors.cyanAccent),
              label: Text(f['label'] as String),
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              selected: isSelected,
              selectedColor: Colors.cyanAccent,
              backgroundColor: const Color(0xFF131D33),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isSelected ? Colors.cyanAccent : Colors.white12),
              ),
              onSelected: (_) => setState(() => _selectedFilter = f['key'] as String),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHistoryList() {
    final list = _filteredHistory;

    if (list.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF131D33),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(
          children: [
            Icon(Icons.history_toggle_off, color: Colors.white24, size: 48),
            SizedBox(height: 12),
            Text('لا توجد سجلات تصفح تطابق هذا الفلتر', style: TextStyle(color: Colors.white70, fontSize: 13.5)),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, idx) {
        final item = list[idx];
        final isSearch = item['is_search_query'] == true || (item['search_query'] != null && item['search_query'].toString().isNotEmpty);
        final isBlocked = item['is_blocked'] == true;
        final browser = (item['browser'] ?? '').toString().toLowerCase();

        IconData browserIcon = Icons.public;
        Color browserColor = Colors.cyanAccent;
        if (browser.contains('chrome')) {
          browserIcon = Icons.language;
          browserColor = Colors.redAccent;
        } else if (browser.contains('edge')) {
          browserIcon = Icons.web;
          browserColor = Colors.blueAccent;
        } else if (browser.contains('firefox')) {
          browserIcon = Icons.explore;
          browserColor = Colors.orangeAccent;
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isBlocked ? const Color(0xFF2D151D) : const Color(0xFF131D33),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isBlocked ? Colors.redAccent.withOpacity(0.3) : Colors.white10,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(browserIcon, color: browserColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item['title'] ?? item['domain'] ?? 'صفحة ويب',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'زيارات: ${item['visit_count'] ?? 1}',
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (isSearch)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search, size: 13, color: Colors.purpleAccent),
                      const SizedBox(width: 4),
                      Text(
                        'بحث: ${item['search_query'] ?? item['title']}',
                        style: const TextStyle(color: Color(0xFFE9D5FF), fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              Text(
                item['url'] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.cyanAccent.withOpacity(0.8), fontSize: 11),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item['visited_at'] != null ? item['visited_at'].toString().replaceFirst('T', ' ').split('.').first : '',
                    style: const TextStyle(color: Colors.white38, fontSize: 10.5),
                  ),
                  if (isBlocked)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.block, color: Colors.redAccent, size: 12),
                          SizedBox(width: 4),
                          Text('محظور 🚫', style: TextStyle(color: Colors.redAccent, fontSize: 10.5, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withOpacity(0.15),
                        foregroundColor: Colors.redAccent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.redAccent.withOpacity(0.4)),
                        ),
                      ),
                      icon: const Icon(Icons.block, size: 13),
                      label: const Text('حظر هذا الموقع', style: TextStyle(fontSize: 11)),
                      onPressed: () => _quickBlockDomain(item['domain'] ?? '', item['title'] ?? ''),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
