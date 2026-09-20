import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';

class AddDeviceDialog extends StatefulWidget {
  final VoidCallback onDeviceAdded;
  const AddDeviceDialog({super.key, required this.onDeviceAdded});

  @override
  State<AddDeviceDialog> createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends State<AddDeviceDialog> {
  final _nameController = TextEditingController();
  bool _isCreating = false;
  String? _pairCode;
  String? _error;

  Future<void> _createChildAndGetCode() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() {
      _isCreating = true;
      _error = null;
    });

    try {
      // 1. Create Child profile
      final childRes = await ApiClient.post(ApiConstants.childrenUrl, {
        'name': _nameController.text.trim(),
      });

      if (childRes.statusCode == 201) {
        final child = jsonDecode(childRes.body);
        final childId = child['id'] as String;

        // 2. Request 6-digit pairing code
        final codeRes = await ApiClient.post(ApiConstants.pairCodeUrl(childId), {});
        if (codeRes.statusCode == 200) {
          final codeData = jsonDecode(codeRes.body);
          setState(() {
            _pairCode = codeData['code'] as String;
          });
          widget.onDeviceAdded();
        }
      } else {
        setState(() => _error = 'Failed to create child profile');
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(_pairCode == null ? 'Add Child Device' : 'Pair Child Device'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),

            if (_pairCode == null) ...[
              const Text(
                'Enter child name to generate pairing code:',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: "Child's Name",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ] else ...[
              const Text(
                'Open Kids Agent app on your child’s phone and enter this code:',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF3B82F6), width: 2),
                ),
                child: Text(
                  _pairCode!,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                    color: Color(0xFF60A5FA),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 140,
                width: 140,
                child: QrImageView(
                  data: jsonEncode({
                    'code': _pairCode,
                    'server': ApiConstants.baseUrl,
                  }),
                  version: QrVersions.auto,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.white),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.white),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Code expires in 15 minutes',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_pairCode == null ? 'Cancel' : 'Done'),
        ),
        if (_pairCode == null)
          ElevatedButton(
            onPressed: _isCreating ? null : _createChildAndGetCode,
            child: _isCreating
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Generate Code'),
          ),
      ],
    );
  }
}
