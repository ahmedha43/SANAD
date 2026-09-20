import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';

class WebFilterScreen extends StatefulWidget {
  final Map<String, dynamic> device;
  const WebFilterScreen({super.key, required this.device});

  @override
  State<WebFilterScreen> createState() => _WebFilterScreenState();
}

class _WebFilterScreenState extends State<WebFilterScreen> {
  bool _isLoading = true;
  bool _isWebFilterEnabled = true;
  List<dynamic> _rules = [];
  String _selectedFilter = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.get(ApiConstants.webFilterRulesUrl(widget.device['id']));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        setState(() {
          _isWebFilterEnabled = data['is_web_filter_enabled'] ?? true;
          _rules = data['rules'] ?? [];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحميل القواعد: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleEngine(bool val) async {
    setState(() => _isWebFilterEnabled = val);
    try {
      await ApiClient.put(ApiConstants.toggleWebFilterEngineUrl(widget.device['id']), {
        'enabled': val,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(val ? '🟢 تم تفعيل محرك حظر وتصفية الويب' : '⏸️ تم إيقاف محرك الويب مؤقتاً'),
          backgroundColor: val ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      setState(() => _isWebFilterEnabled = !val);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تغيير حالة المحرك: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _toggleAll(bool val) async {
    try {
      await ApiClient.put(ApiConstants.toggleAllWebFilterRulesUrl(widget.device['id']), {
        'enabled': val,
      });
      setState(() {
        for (var r in _rules) {
          r['is_active'] = val;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(val ? 'تم تفعيل جميع قواعد الويب' : 'تم تعطيل جميع قواعد الويب'),
          backgroundColor: Colors.blueAccent,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحديث القواعد: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _toggleRule(Map<String, dynamic> rule, bool val) async {
    final oldVal = rule['is_active'];
    setState(() => rule['is_active'] = val);
    try {
      await ApiClient.put(
        ApiConstants.toggleWebFilterRuleUrl(widget.device['id'], rule['id']),
        {'is_active': val},
      );
    } catch (e) {
      setState(() => rule['is_active'] = oldVal);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تعديل القاعدة: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteRule(String ruleId) async {
    try {
      await ApiClient.delete(ApiConstants.deleteWebFilterRuleUrl(widget.device['id'], ruleId));
      setState(() {
        _rules.removeWhere((r) => r['id'] == ruleId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف القاعدة بنجاح'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل حذف القاعدة: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _seedDefaults() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.post(ApiConstants.seedWebFilterDefaultsUrl(widget.device['id']), {});
      if (res.statusCode == 200) {
        await _loadRules();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚡ تم تحميل وتفعيل كافة القوائم الذكية بنجاح!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحميل القوائم الافتراضية: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddRuleDialog() {
    String ruleType = 'keyword';
    String category = 'custom';
    final patternController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.shield, color: Colors.cyanAccent),
                  SizedBox(width: 8),
                  Text('إضافة قاعدة حظر جديدة', style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('نوع القاعدة:', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('كلمة بحث'),
                            selected: ruleType == 'keyword',
                            selectedColor: Colors.purpleAccent.withOpacity(0.3),
                            onSelected: (val) {
                              if (val) setDialogState(() => ruleType = 'keyword');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('رابط موقع'),
                            selected: ruleType == 'domain',
                            selectedColor: Colors.cyanAccent.withOpacity(0.3),
                            onSelected: (val) {
                              if (val) setDialogState(() => ruleType = 'domain');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: patternController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: ruleType == 'keyword' ? 'الكلمة أو النص المحظور' : 'رابط أو اسم الموقع (Domain)',
                        labelStyle: const TextStyle(color: Colors.white60),
                        hintText: ruleType == 'keyword' ? 'مثال: قمار، مخدرات، sex' : 'مثال: example.com',
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('التصنيف:', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButton<String>(
                        value: category,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1E293B),
                        style: const TextStyle(color: Colors.white),
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'adult', child: Text('🔞 محتوى إباحي (Adult)')),
                          DropdownMenuItem(value: 'gambling', child: Text('🎰 قمار ومراهنات (Gambling)')),
                          DropdownMenuItem(value: 'drugs', child: Text('💊 مخدرات وكحول (Drugs)')),
                          DropdownMenuItem(value: 'violence', child: Text('⚔️ عنف وسلاح (Violence)')),
                          DropdownMenuItem(value: 'bypass', child: Text('🛡️ بروكسي وحجب (Bypass)')),
                          DropdownMenuItem(value: 'custom', child: Text('⚙️ مخصص (Custom)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => category = val);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء', style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    final text = patternController.text.trim();
                    if (text.isEmpty) return;
                    Navigator.pop(ctx);
                    try {
                      await ApiClient.post(ApiConstants.webFilterRulesUrl(widget.device['id']), {
                        'rule_type': ruleType,
                        'pattern': text,
                        'category': category,
                      });
                      _loadRules();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('تمت إضافة "$text" بنجاح'), backgroundColor: Colors.green),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('فشل الإضافة: $e'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: const Text('إضافة وحفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<dynamic> get _filteredRules {
    return _rules.filter((r) {
      final pattern = (r['pattern'] ?? '').toString().toLowerCase();
      final cat = (r['category'] ?? '').toString().toLowerCase();
      final type = (r['rule_type'] ?? '').toString().toLowerCase();

      if (_searchQuery.isNotEmpty) {
        if (!pattern.contains(_searchQuery.toLowerCase()) && !cat.contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }

      if (_selectedFilter == 'keyword') return type == 'keyword';
      if (_selectedFilter == 'domain') return type == 'domain';
      if (_selectedFilter == 'adult') return cat == 'adult';
      if (_selectedFilter == 'gambling') return cat == 'gambling';
      if (_selectedFilter == 'drugs') return cat == 'drugs';

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _rules.where((r) => r['is_active'] == true).length;
    final keywordsCount = _rules.where((r) => r['rule_type'] == 'keyword').length;
    final domainsCount = _rules.where((r) => r['rule_type'] == 'domain').length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text('حظر وتصفية الويب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: _loadRules,
          ),
          IconButton(
            icon: const Icon(Icons.bolt, color: Colors.amberAccent),
            tooltip: 'تحميل القوائم الافتراضية الذكية',
            onPressed: _seedDefaults,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.cyanAccent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('إضافة قاعدة', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _showAddRuleDialog,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : RefreshIndicator(
              onRefresh: _loadRules,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Master Engine Switch Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isWebFilterEnabled
                            ? [const Color(0xFF065F46), const Color(0xFF047857)]
                            : [const Color(0xFF7F1D1D), const Color(0xFF991B1B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (_isWebFilterEnabled ? Colors.greenAccent : Colors.redAccent).withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _isWebFilterEnabled ? Icons.shield : Icons.shield_outlined,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isWebFilterEnabled ? 'محرك تصفية الويب نشط 🟢' : 'محرك تصفية الويب معطل ⏸️',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isWebFilterEnabled
                                    ? 'يتم فحص المتصفحات وحظر الكلمات والمواقع فوراً'
                                    : 'تم إيقاف تصفية المواقع مؤقتاً للطفل',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isWebFilterEnabled,
                          activeColor: Colors.greenAccent,
                          activeTrackColor: Colors.white24,
                          inactiveThumbColor: Colors.white70,
                          inactiveTrackColor: Colors.black26,
                          onChanged: _toggleEngine,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Quick Stats Row
                  Row(
                    children: [
                      _buildStatCard('إجمالي القواعد', '${_rules.length}', Icons.rule, Colors.blueAccent),
                      const SizedBox(width: 8),
                      _buildStatCard('القواعد النشطة', '$activeCount', Icons.check_circle, Colors.greenAccent),
                      const SizedBox(width: 8),
                      _buildStatCard('كلمات بحث', '$keywordsCount', Icons.text_fields, Colors.purpleAccent),
                      const SizedBox(width: 8),
                      _buildStatCard('مواقع وروابط', '$domainsCount', Icons.language, Colors.cyanAccent),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Search Box
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'بحث في الكلمات أو الروابط...',
                        hintStyle: TextStyle(color: Colors.white38),
                        prefixIcon: Icon(Icons.search, color: Colors.white54),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Filter Chips & Batch Toggles Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('الكل', 'all'),
                        _buildFilterChip('كلمات البحث', 'keyword'),
                        _buildFilterChip('المواقع والروابط', 'domain'),
                        _buildFilterChip('🔞 إباحية', 'adult'),
                        _buildFilterChip('🎰 قمار', 'gambling'),
                        _buildFilterChip('💊 مخدرات', 'drugs'),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.check_box, size: 16, color: Colors.greenAccent),
                          label: const Text('تفعيل الكل', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                          backgroundColor: const Color(0xFF1E293B),
                          onPressed: () => _toggleAll(true),
                        ),
                        const SizedBox(width: 4),
                        ActionChip(
                          avatar: const Icon(Icons.disabled_by_default, size: 16, color: Colors.redAccent),
                          label: const Text('إيقاف الكل', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                          backgroundColor: const Color(0xFF1E293B),
                          onPressed: () => _toggleAll(false),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Rules List
                  if (_filteredRules.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          const Icon(Icons.filter_list_off, size: 48, color: Colors.white24),
                          const SizedBox(height: 12),
                          const Text('لا توجد قواعد مطابقة', style: TextStyle(color: Colors.white54, fontSize: 16)),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                            icon: const Icon(Icons.bolt, color: Colors.amberAccent),
                            label: const Text('تحميل القوائم الذكية الافتراضية (80+ قاعدة)'),
                            onPressed: _seedDefaults,
                          ),
                        ],
                      ),
                    )
                  else
                    ..._filteredRules.map((rule) => _buildRuleItem(rule)).toList(),

                  const SizedBox(height: 80), // Fab padding
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10), maxLines: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontSize: 12)),
        selected: isSelected,
        selectedColor: Colors.cyanAccent,
        backgroundColor: const Color(0xFF1E293B),
        onSelected: (val) {
          if (val) setState(() => _selectedFilter = value);
        },
      ),
    );
  }

  Widget _buildRuleItem(Map<String, dynamic> rule) {
    final isDomain = rule['rule_type'] == 'domain';
    final isActive = rule['is_active'] ?? true;
    final pattern = rule['pattern'] ?? '';
    final category = rule['category'] ?? 'custom';

    Color catColor = Colors.cyanAccent;
    if (category == 'adult') catColor = Colors.redAccent;
    if (category == 'gambling') catColor = Colors.amberAccent;
    if (category == 'drugs') catColor = Colors.orangeAccent;
    if (category == 'violence') catColor = Colors.deepOrangeAccent;
    if (category == 'bypass') catColor = Colors.purpleAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.white12 : Colors.white10,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isDomain ? Colors.cyanAccent : Colors.purpleAccent).withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isDomain ? Icons.language : Icons.text_fields,
            color: isDomain ? Colors.cyanAccent : Colors.purpleAccent,
            size: 20,
          ),
        ),
        title: Text(
          pattern,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white38,
            fontWeight: FontWeight.bold,
            fontSize: 15,
            decoration: isActive ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                category.toUpperCase(),
                style: TextStyle(color: catColor, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isDomain ? 'رابط موقع' : 'كلمة بحث',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: isActive,
              activeColor: Colors.cyanAccent,
              onChanged: (val) => _toggleRule(rule, val),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              tooltip: 'حذف',
              onPressed: () => _deleteRule(rule['id']),
            ),
          ],
        ),
      ),
    );
  }
}

extension ListFilterExtension on List<dynamic> {
  Iterable<dynamic> filter(bool Function(dynamic) test) {
    return where(test);
  }
}
