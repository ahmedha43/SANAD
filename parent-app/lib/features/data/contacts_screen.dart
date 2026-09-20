import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';

class ContactsScreen extends StatefulWidget {
  final Map<String, dynamic> device;

  const ContactsScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  bool _isLoading = true;
  List<dynamic> _allContacts = [];
  List<dynamic> _filteredContacts = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    setState(() => _isLoading = true);
    final deviceId = widget.device['id'];
    try {
      final res = await ApiClient.get(ApiConstants.contactsUrl(deviceId));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body);
        if (list is List) {
          setState(() {
            _allContacts = list;
            _filterContacts(_searchController.text);
          });
        }
      }
    } catch (e) {
      // Ignored
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestRefreshFromDevice() async {
    final deviceId = widget.device['id'];
    try {
      await ApiClient.post(ApiConstants.commandUrl(deviceId), {
        'action': 'FETCH_CONTACTS',
        'params': {},
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم طلب تحديث جهات الاتصال من هاتف الطفل...'), backgroundColor: Colors.blue),
      );
      await Future.delayed(const Duration(seconds: 2));
      _fetchContacts();
    } catch (e) {
      // Ignored
    }
  }

  void _filterContacts(String query) {
    if (query.trim().isEmpty) {
      setState(() => _filteredContacts = _allContacts);
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      _filteredContacts = _allContacts.where((c) {
        final name = (c['name'] ?? '').toString().toLowerCase();
        final phone = (c['phone_number'] ?? '').toString().toLowerCase();
        return name.contains(q) || phone.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final childName = widget.device['child']?['name'] ?? widget.device['device_name'] ?? 'Child';

    return Scaffold(
      appBar: AppBar(
        title: Text('جهات اتصال - $childName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'طلب تحديث فوري',
            onPressed: _requestRefreshFromDevice,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Box
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterContacts,
              decoration: InputDecoration(
                hintText: 'بحث بالاسم أو الرقم...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterContacts('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),

          // Total Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'إجمالي جهات الاتصال: ${_filteredContacts.length}',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Contacts List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredContacts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.contacts_outlined, size: 64, color: Colors.grey.shade600),
                            const SizedBox(height: 16),
                            const Text('لا توجد جهات اتصال محفوظة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('انقر فوق زر التحديث لجلب جهات الاتصال من الجهاز', style: TextStyle(color: Colors.grey.shade400)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _requestRefreshFromDevice,
                              icon: const Icon(Icons.refresh),
                              label: const Text('جلب جهات الاتصال الآن'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredContacts.length,
                        itemBuilder: (context, idx) {
                          final contact = _filteredContacts[idx];
                          final name = contact['name'] ?? 'Unknown';
                          final phone = contact['phone_number'] ?? '';

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.teal.shade700,
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(phone, style: TextStyle(color: Colors.grey.shade400)),
                            trailing: IconButton(
                              icon: const Icon(Icons.phone, color: Colors.greenAccent),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('رقم الهاتف: $phone')),
                                );
                              },
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
