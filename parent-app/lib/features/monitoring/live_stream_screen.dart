import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../core/network/websocket_service.dart';

enum StreamType { screen, camera, audioOnly, walkieTalkie }

class LiveStreamScreen extends StatefulWidget {
  final Map<String, dynamic> device;
  final StreamType initialType;

  const LiveStreamScreen({
    super.key,
    required this.device,
    this.initialType = StreamType.screen,
  });

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  StreamSubscription? _wsSubscription;
  bool _isConnected = false;
  bool _hasRemoteDescription = false;
  bool _isTalking = false;
  final List<RTCIceCandidate> _pendingIceCandidates = [];
  late StreamType _currentType;
  String _connectionStatusText = 'Connecting to WebRTC...';

  @override
  void initState() {
    super.initState();
    _currentType = widget.initialType;
    _initRenderer();
    _listenToSignaling();
  }

  Future<void> _initRenderer() async {
    await _remoteRenderer.initialize();
    _startWebRTCSession();
  }

  void _listenToSignaling() {
    _wsSubscription?.cancel();
    _wsSubscription = WebSocketService().messageStream.listen((msg) async {
      if (msg['from'] != widget.device['id']) return;

      final type = msg['type'];
      if (type == 'RTC_ANSWER') {
        final payload = msg['payload'];
        if (payload != null && payload['sdp'] != null) {
          final answer = RTCSessionDescription(payload['sdp'], 'answer');
          try {
            await _peerConnection?.setRemoteDescription(answer);
            _hasRemoteDescription = true;
            if (mounted) {
              setState(() {
                _connectionStatusText = 'Establishing media channel...';
              });
            }

            // Flush pending ICE candidates
            for (final candidate in _pendingIceCandidates) {
              await _peerConnection?.addCandidate(candidate);
            }
            _pendingIceCandidates.clear();
          } catch (e) {
            debugPrint('Error setting remote description: $e');
          }
        }
      } else if (type == 'RTC_ICE_CANDIDATE') {
        final payload = msg['payload'];
        if (payload != null && payload['sdp'] != null) {
          final candidate = RTCIceCandidate(
            payload['sdp'],
            payload['sdp_mid'] ?? '',
            payload['sdp_mline_index'] ?? 0,
          );
          if (_hasRemoteDescription && _peerConnection != null) {
            await _peerConnection?.addCandidate(candidate);
          } else {
            _pendingIceCandidates.add(candidate);
          }
        }
      } else if (type == 'CAMERA_SWITCH_RESULT') {
        final payload = msg['payload'];
        if (mounted && payload != null) {
          final success = payload['success'] == true;
          final isFront = payload['is_front'] == true;
          final err = payload['error'] as String?;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? (isFront ? '📷 تم التبديل إلى الكاميرا الأمامية' : '📷 تم التبديل إلى الكاميرا الخلفية')
                    : 'فشل تبديل الكاميرا: ${err ?? "خطأ غير معروف"}',
              ),
              backgroundColor: success ? Colors.teal.shade700 : Colors.red.shade700,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else if (type == 'STREAM_ERROR') {
        final payload = msg['payload'];
        if (mounted && payload != null) {
          final err = payload['error'] as String? ?? 'حدث خطأ أثناء الاتصال بالبث';
          setState(() {
            _connectionStatusText = err;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err),
              backgroundColor: Colors.amber.shade900,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    });
  }

  void _switchCamera() {
    WebSocketService().sendMessage(
      'CAMERA_SWITCH',
      to: widget.device['id'],
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('جارٍ إرسال أمر تبديل الكاميرا...'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _startWebRTCSession() async {
    _hasRemoteDescription = false;
    _pendingIceCandidates.clear();
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream = null;

    if (mounted) {
      setState(() {
        _isConnected = false;
        _connectionStatusText = 'Connecting to ${widget.device['device_name']}...';
      });
    }

    final config = <String, dynamic>{
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:192.168.1.110:3478'},
        {
          'urls': 'turn:192.168.1.110:3478',
          'username': 'parentalctl',
          'credential': 'SecureTurnSecretPass2026',
        }
      ],
      'sdpSemantics': 'unified-plan',
    };

    try {
      _peerConnection?.close();
      _peerConnection = await createPeerConnection(config);

      _peerConnection!.onIceCandidate = (candidate) {
        WebSocketService().sendMessage(
          'RTC_ICE_CANDIDATE',
          to: widget.device['id'],
          payload: {
            'sdp': candidate.candidate,
            'sdp_mid': candidate.sdpMid,
            'sdp_mline_index': candidate.sdpMLineIndex,
          },
        );
      };

      _peerConnection!.onAddStream = (MediaStream stream) {
        if (mounted) {
          setState(() {
            _remoteRenderer.srcObject = stream;
            _isConnected = true;
          });
        }
      };

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'video') {
          if (event.streams.isNotEmpty) {
            _remoteRenderer.srcObject = event.streams[0];
          }
          if (mounted) {
            setState(() => _isConnected = true);
          }
        } else if (event.track.kind == 'audio') {
          event.track.enabled = true;
          if ((_currentType == StreamType.audioOnly || _currentType == StreamType.walkieTalkie) && mounted) {
            setState(() => _isConnected = true);
          }
        }
      };

      _peerConnection!.onConnectionState = (state) {
        debugPrint('WebRTC ConnectionState: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          if (mounted) {
            setState(() => _isConnected = true);
          }
        }
      };

      if (_currentType == StreamType.walkieTalkie) {
        // Walkie-Talkie mode: Send parent audio to child's loudspeaker
        _localStream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': false,
        });

        _localStream?.getTracks().forEach((track) {
          _peerConnection?.addTrack(track, _localStream!);
        });

        final offer = await _peerConnection!.createOffer({
          'offerToReceiveVideo': 0,
          'offerToReceiveAudio': 1,
        });
        await _peerConnection!.setLocalDescription(offer);

        WebSocketService().sendMessage(
          'RTC_OFFER',
          to: widget.device['id'],
          payload: {
            'stream_type': 'ptt',
            'sdp': offer.sdp,
          },
        );
      } else {
        // RecvOnly transceivers for Screen, Camera, or Ambient Audio
        await _peerConnection!.addTransceiver(
          kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
          init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
        );

        if (_currentType != StreamType.audioOnly) {
          await _peerConnection!.addTransceiver(
            kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
            init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
          );
        }

        final offer = await _peerConnection!.createOffer({
          'offerToReceiveVideo': _currentType == StreamType.audioOnly ? 0 : 1,
          'offerToReceiveAudio': 1,
        });
        await _peerConnection!.setLocalDescription(offer);

        WebSocketService().sendMessage(
          'RTC_OFFER',
          to: widget.device['id'],
          payload: {
            'stream_type': _currentType == StreamType.audioOnly ? 'audio_only' : _currentType.name,
            'sdp': offer.sdp,
          },
        );
      }
    } catch (e) {
      debugPrint('Error starting WebRTC session: $e');
      if (mounted) {
        setState(() {
          _connectionStatusText = 'Connection failed. Tap refresh to retry.';
        });
      }
    }
  }

  void _startTalking() {
    setState(() => _isTalking = true);
    WebSocketService().sendMessage('PTT_START', to: widget.device['id']);
  }

  void _stopTalking() {
    setState(() => _isTalking = false);
    WebSocketService().sendMessage('PTT_STOP', to: widget.device['id']);
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    WebSocketService().sendMessage('STREAM_STOP', to: widget.device['id']);
    _remoteRenderer.dispose();
    _peerConnection?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _currentType == StreamType.screen
        ? 'بث الشاشة المباشر'
        : _currentType == StreamType.camera
            ? 'الكاميرا المباشرة'
            : _currentType == StreamType.walkieTalkie
                ? 'اللاسلكي الفوري (Walkie-Talkie)'
                : 'الاستماع الصوتي للمحيط';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(title, style: const TextStyle(fontSize: 16)),
          backgroundColor: const Color(0xFF0F172A),
          actions: [
            if (_currentType == StreamType.camera)
              IconButton(
                icon: const Icon(Icons.flip_camera_android, color: Colors.amberAccent),
                tooltip: 'تبديل الكاميرا (أمامية / خلفية)',
                onPressed: _switchCamera,
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'إعادة الاتصال',
              onPressed: () {
                _peerConnection?.close();
                _startWebRTCSession();
              },
            )
          ],
        ),
        body: Stack(
          children: [
            Center(
              child: _isConnected
                  ? (_currentType == StreamType.walkieTalkie
                      ? _buildWalkieTalkieUI()
                      : _currentType == StreamType.audioOnly
                          ? _buildAudioLiveIndicator()
                          : RTCVideoView(
                              _remoteRenderer,
                              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                            ))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: Colors.blueAccent),
                        const SizedBox(height: 20),
                        Text(
                          _connectionStatusText,
                          style: const TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
            ),
            if (_currentType == StreamType.camera && _isConnected)
              Positioned(
                bottom: 95,
                left: 0,
                right: 0,
                child: Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xCC0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      elevation: 4,
                    ),
                    icon: const Icon(Icons.flip_camera_android, size: 22, color: Colors.amberAccent),
                    label: const Text(
                      'تبديل الكاميرا (أمامية / خلفية)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _switchCamera,
                  ),
                ),
              ),
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 12),
                    _buildModeButton(Icons.screen_share, 'الشاشة', StreamType.screen),
                    const SizedBox(width: 8),
                    _buildModeButton(Icons.camera_alt, 'الكاميرا', StreamType.camera),
                    const SizedBox(width: 8),
                    _buildModeButton(Icons.hearing, 'صوت المحيط', StreamType.audioOnly),
                    const SizedBox(width: 8),
                    _buildModeButton(Icons.radio, 'اللاسلكي PTT', StreamType.walkieTalkie),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioLiveIndicator() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.teal.withOpacity(0.15),
            border: Border.all(color: Colors.tealAccent, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.tealAccent.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
              )
            ],
          ),
          child: const Icon(
            Icons.graphic_eq,
            size: 65,
            color: Colors.tealAccent,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'الاستماع المباشر لمحيط الجهاز',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'بث صوتي مشفر خفيف جداً (~30 kbps) من جهاز ${widget.device['device_name']}',
          style: const TextStyle(color: Colors.white60, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildWalkieTalkieUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.15),
            border: Border.all(color: Colors.amberAccent.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.volume_up, color: Colors.amberAccent, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '⚠️ مكبر الصوت في جهاز الطفل سيعمل بأقصى درجة متجاوزاً وضع الصامت.',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        GestureDetector(
          onTapDown: (_) => _startTalking(),
          onTapUp: (_) => _stopTalking(),
          onTapCancel: () => _stopTalking(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: _isTalking ? 170 : 150,
            height: _isTalking ? 170 : 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: _isTalking
                    ? [Colors.red.shade700, Colors.redAccent]
                    : [Colors.cyan.shade700, Colors.cyanAccent],
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isTalking ? Colors.redAccent : Colors.cyanAccent).withOpacity(0.5),
                  blurRadius: _isTalking ? 40 : 20,
                  spreadRadius: _isTalking ? 10 : 3,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.mic,
                  size: 55,
                  color: Colors.white,
                ),
                const SizedBox(height: 6),
                Text(
                  _isTalking ? 'حرر للإيقاف' : 'اضغط وتحدث',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _isTalking ? '🎙️ يتم البث المباشر لمكبر صوت الطفل الآن...' : 'جاهز للتحدث - اضغط مطولاً على الزر',
          style: TextStyle(
            color: _isTalking ? Colors.redAccent : Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildModeButton(IconData icon, String label, StreamType type) {
    final isSelected = _currentType == type;
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blueAccent : const Color(0xFF1E293B),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () {
        if (_currentType != type) {
          setState(() {
            _currentType = type;
            _isConnected = false;
          });
          _peerConnection?.close();
          _startWebRTCSession();
        }
      },
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
