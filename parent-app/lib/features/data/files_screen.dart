import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/websocket_service.dart';

class FilesScreen extends StatefulWidget {
  final Map<String, dynamic> device;

  const FilesScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  bool _isLoading = true;
  List<dynamic> _files = [];
  final Map<String, String> _loadedFullImages = {}; // filePath -> base64

  @override
  void initState() {
    super.initState();
    _fetchFiles();
    _listenToWs();
  }

  void _listenToWs() {
    try {
      WebSocketService().messageStream.listen((msg) {
        if (!mounted) return;
        if (msg['type'] == 'FILES_SYNC') {
          final payload = msg['payload'];
          if (payload is List) {
            setState(() {
              _files = payload;
              _isLoading = false;
            });
          }
        } else if (msg['type'] == 'FILE_DATA_RESULT') {
          final payload = msg['payload'];
          if (payload is Map && payload['file_path'] != null && payload['file_base64'] != null) {
            final path = payload['file_path'] as String;
            final b64 = payload['file_base64'] as String;
            setState(() {
              _loadedFullImages[path] = b64;
            });
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _fetchFiles() async {
    setState(() => _isLoading = true);
    final deviceId = widget.device['id'];
    try {
      final res = await ApiClient.get(ApiConstants.filesUrl(deviceId));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body);
        if (list is List) {
          setState(() => _files = list);
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
        'action': 'FETCH_FILES',
        'params': {},
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم طلب مزامنة أحدث الصور والملفات من جهاز الطفل...'),
          backgroundColor: Colors.blue,
        ),
      );
      await Future.delayed(const Duration(seconds: 2));
      _fetchFiles();
    } catch (e) {
      // Ignored
    }
  }

  Future<void> _requestFullFile(String filePath) async {
    final deviceId = widget.device['id'];
    try {
      await ApiClient.post(ApiConstants.commandUrl(deviceId), {
        'action': 'FETCH_FILE_DATA',
        'params': {'file_path': filePath},
      });
    } catch (_) {}
  }

  void _openImageInspection(Map<String, dynamic> file) {
    final filePath = file['file_path'] ?? '';
    final fileName = file['file_name'] ?? 'Photo';
    final thumbBase64 = file['thumbnail_base64'] as String?;

    if (!_loadedFullImages.containsKey(filePath)) {
      _requestFullFile(filePath);
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final fullB64 = _loadedFullImages[filePath];
            final displayB64 = fullB64 ?? thumbBase64;
            final isFullLoaded = fullB64 != null;

            return Dialog.fullscreen(
              backgroundColor: Colors.black.withOpacity(0.95),
              child: Scaffold(
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                  backgroundColor: Colors.black54,
                  title: Text(fileName, style: const TextStyle(fontSize: 16)),
                  actions: [
                    if (!isFullLoaded)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent),
                          ),
                        ),
                      ),
                  ],
                ),
                body: Center(
                  child: displayB64 != null && displayB64.isNotEmpty
                      ? InteractiveViewer(
                          panEnabled: true,
                          boundaryMargin: const EdgeInsets.all(20),
                          minScale: 0.5,
                          maxScale: 4.0,
                          child: Image.memory(
                            base64Decode(displayB64),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, size: 64, color: Colors.redAccent),
                                SizedBox(height: 12),
                                Text('تعذر عرض الصورة', style: TextStyle(color: Colors.white70)),
                              ],
                            ),
                          ),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('جاري تحميل الصورة عالية الدقة من جهاز الطفل...',
                                style: TextStyle(color: Colors.white70)),
                          ],
                        ),
                ),
                bottomNavigationBar: Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.black54,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isFullLoaded ? 'الدقة الكاملة (Original)' : 'جاري جلب الأصل...',
                        style: TextStyle(
                          color: isFullLoaded ? Colors.greenAccent : Colors.amberAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatFileSize(file['file_size']),
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatFileSize(dynamic sizeBytes) {
    if (sizeBytes == null) return '0 B';
    final bytes = sizeBytes is int ? sizeBytes : int.tryParse(sizeBytes.toString()) ?? 0;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '';
    try {
      final intVal = ts is int ? ts : int.tryParse(ts.toString()) ?? 0;
      final dt = DateTime.fromMillisecondsSinceEpoch(intVal);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final childName = widget.device['child']?['name'] ?? widget.device['device_name'] ?? 'Child';

    return Scaffold(
      appBar: AppBar(
        title: Text('معرض الصور والملفات - $childName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث الصور والملفات',
            onPressed: _requestRefreshFromDevice,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey.shade600),
                      const SizedBox(height: 16),
                      const Text('لا توجد ملفات أو صور مسجلة بعد',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('انقر فوق زر التحديث لجلب أحدث الصور والملفات من جهاز الطفل',
                          style: TextStyle(color: Colors.grey.shade400)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _requestRefreshFromDevice,
                        icon: const Icon(Icons.refresh),
                        label: const Text('جلب الملفات والصور الآن'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _files.length,
                  itemBuilder: (context, idx) {
                    final file = _files[idx];
                    final name = file['file_name'] ?? 'File';
                    final mime = file['mime_type'] ?? '';
                    final isImage = mime.startsWith('image/') ||
                        name.endsWith('.jpg') ||
                        name.endsWith('.png') ||
                        name.endsWith('.jpeg');
                    final sizeStr = _formatFileSize(file['file_size']);
                    final timeStr = _formatTimestamp(file['timestamp']);
                    final thumbBase64 = file['thumbnail_base64'] as String?;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        onTap: isImage ? () => _openImageInspection(file) : null,
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isImage
                                ? Colors.purple.withOpacity(0.2)
                                : Colors.blueGrey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: thumbBase64 != null && thumbBase64.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    base64Decode(thumbBase64),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                      isImage ? Icons.image : Icons.insert_drive_file,
                                      color: isImage ? Colors.purpleAccent : Colors.blueGrey,
                                    ),
                                  ),
                                )
                              : Icon(
                                  isImage ? Icons.image : Icons.insert_drive_file,
                                  color: isImage ? Colors.purpleAccent : Colors.blueGrey,
                                ),
                        ),
                        title: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          '$sizeStr • $mime\n$timeStr',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                        ),
                        trailing: isImage
                            ? const Icon(Icons.zoom_in, color: Colors.purpleAccent)
                            : null,
                        isThreeLine: timeStr.isNotEmpty,
                      ),
                    );
                  },
                ),
    );
  }
}
