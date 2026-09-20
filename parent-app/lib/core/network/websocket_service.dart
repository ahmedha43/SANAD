import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/api_constants.dart';
import 'api_client.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  bool _isConnected = false;
  Timer? _reconnectTimer;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  bool get isConnected => _isConnected;

  void connect() {
    final token = ApiClient.token;
    if (token == null) return;

    disconnect();

    final wsUri = Uri.parse('${ApiConstants.wsUrl}/ws?token=$token');

    try {
      _channel = WebSocketChannel.connect(wsUri);
      _isConnected = true;

      _channel!.stream.listen(
        (data) {
          try {
            final decoded = jsonDecode(data as String) as Map<String, dynamic>;
            _messageController.add(decoded);
          } catch (e) {
            // Ignore format error
          }
        },
        onDone: () {
          _isConnected = false;
          _scheduleReconnect();
        },
        onError: (err) {
          _isConnected = false;
          _scheduleReconnect();
        },
      );
    } catch (e) {
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (ApiClient.isAuthenticated) {
        connect();
      }
    });
  }

  void sendMessage(String type, {String? to, Map<String, dynamic>? payload}) {
    if (_channel == null || !_isConnected) return;

    final msg = {
      'type': type,
      'to': to,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'payload': payload ?? {},
    };

    _channel!.sink.add(jsonEncode(msg));
  }

  void sendCommand(String deviceId, String action, [Map<String, dynamic>? params]) {
    sendMessage(
      'COMMAND_REQUEST',
      to: deviceId,
      payload: {
        'command_id': DateTime.now().millisecondsSinceEpoch.toString(),
        'action': action,
        'params': params ?? {},
      },
    );
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }
}
