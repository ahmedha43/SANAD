using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using SIPSorcery.Media;
using SIPSorcery.Net;
using SIPSorceryMedia.Abstractions;
using SIPSorceryMedia.Encoders;
using SIPSorceryMedia.Windows;
using Sanad.Core.Models;

namespace Sanad.Core.Services
{
    public class WebRtcLiveStreamService
    {
        private readonly ConfigService _configService;
        private RTCPeerConnection? _peerConnection;
        private WindowsAudioEndPoint? _audioEndPoint;
        private WindowsVideoEndPoint? _videoEndPoint;
        private VideoEncoderEndPoint? _screenEncoderEndPoint;
        private CancellationTokenSource? _screenCts;

        public event Func<string, object, Task>? OnSendSignalingMessage;
        public bool IsStreaming => _peerConnection != null && 
            (_peerConnection.connectionState == RTCPeerConnectionState.connected || 
             _peerConnection.connectionState == RTCPeerConnectionState.connecting);

        public WebRtcLiveStreamService(ConfigService configService)
        {
            _configService = configService;
        }

        public async Task HandleRemoteOfferAsync(string fromParent, string streamType, string sdpOffer)
        {
            try
            {
                Log($"[WebRTC] Received RTC_OFFER from {fromParent} for stream_type: {streamType}");
                Log($"[WebRTC] Offer SDP:\n{sdpOffer}");
                await CloseCurrentSessionAsync();

                var rtcConfig = new RTCConfiguration
                {
                    iceServers = new List<RTCIceServer>
                    {
                        new RTCIceServer { urls = "stun:stun.l.google.com:19302" },
                        new RTCIceServer { urls = "stun:192.168.88.54:3478" },
                        // TURN via host LAN IP
                        new RTCIceServer
                        {
                            urls = "turn:192.168.88.54:3478",
                            username = "parentalctl",
                            credential = "SecureTurnSecretPass2026"
                        },
                        new RTCIceServer
                        {
                            urls = "turns:192.168.88.54:5349",
                            username = "parentalctl",
                            credential = "SecureTurnSecretPass2026"
                        }
                    }
                };

                _peerConnection = new RTCPeerConnection(rtcConfig);

                _peerConnection.onicecandidate += (candidate) =>
                {
                    if (candidate != null && OnSendSignalingMessage != null)
                    {
                        // Filter out internal Docker network candidates that the phone cannot reach
                        if (candidate.candidate.Contains(" 172.") || candidate.candidate.Contains("172.22.") || candidate.candidate.Contains("172.17."))
                        {
                            Log($"[WebRTC] Filtered out unreachable Docker candidate: {candidate.candidate}");
                            return;
                        }

                        Log($"[WebRTC] Sending ICE candidate: {candidate.candidate}");
                        var candPayload = new
                        {
                            sdp = candidate.candidate,
                            candidate = candidate.candidate,
                            sdp_mid = candidate.sdpMid ?? "0",
                            sdp_mline_index = candidate.sdpMLineIndex
                        };
                        _ = OnSendSignalingMessage("RTC_ICE_CANDIDATE", candPayload);
                    }
                    else if (candidate == null)
                    {
                        Log("[WebRTC] ICE gathering complete (null candidate).");
                    }
                };

                _peerConnection.onicecandidateerror += (candidate, url) =>
                {
                    Log($"[WebRTC] ICE candidate error: url={url}, candidate={candidate?.candidate}");
                };

                _peerConnection.oniceconnectionstatechange += (state) =>
                {
                    Log($"[WebRTC] ICE connection state: {state}");
                };

                _peerConnection.onicegatheringstatechange += (state) =>
                {
                    Log($"[WebRTC] ICE gathering state: {state}");
                };

                _peerConnection.onconnectionstatechange += (state) =>
                {
                    Log($"[WebRTC] Connection state changed: {state}");
                    if (state == RTCPeerConnectionState.closed)
                    {
                        _ = CloseCurrentSessionAsync();
                    }
                };

                // 1. Setup Audio (Microphone and/or Speaker)
                try
                {
                    var audioEncoder = new AudioEncoder();
                    bool isSink = streamType == "ptt";
                    bool isSource = streamType != "ptt";

                    _audioEndPoint = new WindowsAudioEndPoint(audioEncoder, -1, -1, isSink, isSource);
                    
                    var audioFormats = new List<AudioFormat>
                    {
                        new AudioFormat(AudioCodecsEnum.PCMU, 0, 8000),
                        new AudioFormat(AudioCodecsEnum.PCMA, 8, 8000)
                    };

                    var audioStatus = isSink ? MediaStreamStatusEnum.RecvOnly : MediaStreamStatusEnum.SendOnly;
                    var audioTrack = new MediaStreamTrack(audioFormats, audioStatus);
                    _peerConnection.addTrack(audioTrack);

                    int audioTxCount = 0;
                    if (isSource)
                    {
                        _audioEndPoint.OnAudioSourceEncodedSample += (duration, sample) =>
                        {
                            audioTxCount++;
                            if (audioTxCount % 50 == 1)
                            {
                                Log($"[WebRTC] Encoded and sent audio frame #{audioTxCount}, size={sample.Length} bytes");
                            }
                            if (_peerConnection != null)
                            {
                                _peerConnection.SendAudio(duration, sample);
                            }
                        };
                    }

                    int audioRxCount = 0;
                    if (isSink)
                    {
                        _peerConnection.OnAudioFrameReceived += (frame) =>
                        {
                            audioRxCount++;
                            if (audioRxCount % 50 == 1)
                            {
                                Log($"[WebRTC] Received audio frame #{audioRxCount} from parent");
                            }
                            _audioEndPoint.GotEncodedMediaFrame(frame);
                        };
                    }

                    _peerConnection.OnAudioFormatsNegotiated += (formats) =>
                    {
                        var format = formats.First();
                        Log($"[WebRTC] Audio format negotiated: {format.FormatName} (ID: {format.FormatID})");
                        try
                        {
                            if (isSource)
                            {
                                _audioEndPoint.SetAudioSourceFormat(format);
                            }
                            if (isSink)
                            {
                                _audioEndPoint.SetAudioSinkFormat(format);
                            }
                            Log($"[WebRTC] Audio format set to {format.FormatName}.");
                        }
                        catch (Exception ex)
                        {
                            Log($"[WebRTC] Error setting audio format: {ex.Message}");
                        }
                    };

                    try
                    {
                        await _audioEndPoint.StartAudio();
                        Log($"[WebRTC] Audio endpoint started (isSource={isSource}, isSink={isSink}).");
                    }
                    catch (Exception ex)
                    {
                        Log($"[WebRTC] Error in _audioEndPoint.StartAudio(): {ex.Message}");
                    }
                }
                catch (Exception ex)
                {
                    Log($"[WebRTC] Warning setting up audio: {ex.Message}");
                }

                // 2. Setup Video — Flutter sends RecvOnly → agent must be SendOnly
                if (streamType != "audio_only" && streamType != "ptt")
                {
                    try
                    {
                        var videoFormats = new List<VideoFormat>
                        {
                            new VideoFormat(VideoCodecsEnum.VP8, 96, 90000),
                            new VideoFormat(VideoCodecsEnum.VP8, 98, 90000),
                            new VideoFormat(VideoCodecsEnum.VP8, 100, 90000),
                            new VideoFormat(VideoCodecsEnum.VP8, 120, 90000),
                            new VideoFormat(VideoCodecsEnum.H264, 97, 90000),
                            new VideoFormat(VideoCodecsEnum.H264, 102, 90000)
                        };
                        var videoTrack = new MediaStreamTrack(videoFormats, MediaStreamStatusEnum.SendOnly);
                        _peerConnection.addTrack(videoTrack);

                        _peerConnection.OnVideoFormatsNegotiated += (formats) =>
                        {
                            var format = formats.First();
                            Log($"[WebRTC] Video format negotiated: {format.Codec} (Payload ID: {format.FormatID})");
                            if (_videoEndPoint != null)
                            {
                                _videoEndPoint.SetVideoSourceFormat(format);
                                Log("[WebRTC] Configured webcam endpoint with negotiated video format.");
                            }
                        };

                        if (streamType == "camera")
                        {
                            try
                            {
                                var videoEncoder = new VpxVideoEncoder();
                                _videoEndPoint = new WindowsVideoEndPoint(videoEncoder);
                                int camFrameCount = 0;
                                _videoEndPoint.OnVideoSourceEncodedSample += (duration, sample) =>
                                {
                                    camFrameCount++;
                                    if (camFrameCount % 30 == 1)
                                    {
                                        Log($"[WebRTC] Encoded and sent webcam frame #{camFrameCount}, size={sample.Length} bytes");
                                    }
                                    if (_peerConnection != null)
                                    {
                                        _peerConnection.SendVideo(duration, sample);
                                    }
                                };
                                await _videoEndPoint.StartVideo();
                                Log("[WebRTC] Webcam stream started.");
                            }
                            catch (Exception ex)
                            {
                                Log($"[WebRTC] Webcam unavailable, falling back to desktop screen: {ex.Message}");
                                StartScreenCaptureStream();
                            }
                        }
                        else
                        {
                            StartScreenCaptureStream();
                        }
                    }
                    catch (Exception ex)
                    {
                        Log($"[WebRTC] Warning setting up video endpoint: {ex.Message}");
                    }
                }

                // 3. Set Remote Description (Offer)
                var offerInit = new RTCSessionDescriptionInit
                {
                    type = RTCSdpType.offer,
                    sdp = sdpOffer
                };
                var setRemoteRes = _peerConnection.setRemoteDescription(offerInit);
                if (setRemoteRes != SetDescriptionResultEnum.OK)
                {
                    Log($"[WebRTC] Failed to set remote description: {setRemoteRes}");
                    await SendStreamErrorAsync(fromParent, "فشل تعيين إعدادات البث (SDP Remote)");
                    return;
                }

                // 4. Create and Set Local Answer
                if (_peerConnection == null)
                {
                    Log("[WebRTC] PeerConnection is null before creating answer!");
                    await SendStreamErrorAsync(fromParent, "فشل إنشاء الاتصال (PeerConnection is null)");
                    return;
                }

                var answer = _peerConnection.createAnswer(null);
                if (answer == null)
                {
                    Log("[WebRTC] createAnswer returned null!");
                    await SendStreamErrorAsync(fromParent, "فشل إنشاء الرد (createAnswer returned null)");
                    return;
                }

                await _peerConnection.setLocalDescription(answer);

                Log($"[WebRTC] Created and set local answer successfully. Dispatching to parent...");

                if (OnSendSignalingMessage != null)
                {
                    var answerPayload = new
                    {
                        sdp = answer.sdp,
                        type = "answer",
                        stream_type = streamType
                    };
                    await OnSendSignalingMessage("RTC_ANSWER", answerPayload);
                }
            }
            catch (Exception ex)
            {
                Log($"[WebRTC] Exception handling remote offer: {ex.Message}");
                await SendStreamErrorAsync(fromParent, $"خطأ في بدء البث المباشر: {ex.Message}");
            }
        }

        public void HandleRemoteIceCandidate(JsonElement payload)
        {
            try
            {
                if (_peerConnection == null) return;

                string? candStr = null;
                string? sdpMid = null;
                ushort sdpMLineIndex = 0;

                if (payload.TryGetProperty("sdp", out var sdpProp)) candStr = sdpProp.GetString();
                if (payload.TryGetProperty("candidate", out var cProp)) candStr ??= cProp.GetString();
                if (payload.TryGetProperty("sdp_mid", out var midProp)) sdpMid = midProp.GetString();
                if (payload.TryGetProperty("sdp_mline_index", out var lineProp)) sdpMLineIndex = lineProp.GetUInt16();

                if (!string.IsNullOrEmpty(candStr))
                {
                    var init = new RTCIceCandidateInit
                    {
                        candidate = candStr,
                        sdpMid = sdpMid ?? "0",
                        sdpMLineIndex = sdpMLineIndex
                    };
                    _peerConnection.addIceCandidate(init);
                    Log("[WebRTC] Added remote ICE candidate successfully.");
                }
            }
            catch (Exception ex)
            {
                Log($"[WebRTC] Error adding ICE candidate: {ex.Message}");
            }
        }

        private void StartScreenCaptureStream()
        {
            _screenCts = new CancellationTokenSource();
            var token = _screenCts.Token;

            Task.Run(async () =>
            {
                Log("[WebRTC] Real-time desktop screen capture loop started (~15 FPS).");
                var vpxEncoder = new VpxVideoEncoder();
                int screenFrameCount = 0;
                int sentCount = 0;

                while (!token.IsCancellationRequested && _peerConnection != null)
                {
                    try
                    {
                        var (data, w, h) = ScreenCaptureService.CaptureScreenAsBgr(1280, 720);
                        if (data != null && data.Length > 0 && _peerConnection != null)
                        {
                            screenFrameCount++;
                            // Recreate encoder every 30 frames (~2 seconds) to force a clean VP8 keyframe (I-frame)
                            if (screenFrameCount % 30 == 1 && screenFrameCount > 1)
                            {
                                vpxEncoder = new VpxVideoEncoder();
                            }

                            var encoded = vpxEncoder.EncodeVideo(w, h, data, VideoPixelFormatsEnum.Bgr, VideoCodecsEnum.VP8);
                            if (encoded != null && encoded.Length > 0)
                            {
                                sentCount++;
                                if (sentCount % 30 == 1)
                                {
                                    Log($"[WebRTC] Encoded and sent screen frame #{sentCount} (Keyframe={screenFrameCount % 30 == 1}), size={encoded.Length} bytes ({w}x{h})");
                                }
                                // 90000 Hz / 15 FPS = 6000 RTP timestamp duration units!
                                _peerConnection.SendVideo(6000, encoded);
                            }
                            else if (screenFrameCount % 30 == 1)
                            {
                                Log($"[WebRTC] VpxVideoEncoder returned null or empty for frame #{screenFrameCount}");
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        Log($"[WebRTC] Screen capture/encode error: {ex.Message}");
                    }

                    try
                    {
                        await Task.Delay(66, token);
                    }
                    catch (OperationCanceledException)
                    {
                        break;
                    }
                }
                Log("[WebRTC] Desktop screen capture loop ended.");
            }, token);
        }

        private readonly SemaphoreSlim _closeLock = new(1, 1);

        public async Task CloseCurrentSessionAsync()
        {
            if (!await _closeLock.WaitAsync(3000)) return;
            try
            {
                _screenCts?.Cancel();
                _screenCts = null;
                if (_screenEncoderEndPoint != null)
                {
                    try { _screenEncoderEndPoint.Dispose(); } catch { }
                    _screenEncoderEndPoint = null;
                }

                if (_audioEndPoint != null)
                {
                    try { await _audioEndPoint.Close(); } catch { }
                    _audioEndPoint = null;
                }

                if (_videoEndPoint != null)
                {
                    try { await _videoEndPoint.Close(); } catch { }
                    _videoEndPoint = null;
                }

                if (_peerConnection != null)
                {
                    try { _peerConnection.close(); } catch { }
                    try { _peerConnection.Dispose(); } catch { }
                    _peerConnection = null;
                }

                Log("[WebRTC] Closed session and released media endpoints.");
            }
            catch (Exception ex)
            {
                Log($"[WebRTC] Error closing session: {ex.Message}");
            }
            finally
            {
                _closeLock.Release();
            }
        }

        private async Task SendStreamErrorAsync(string toRecipient, string error)
        {
            if (OnSendSignalingMessage != null)
            {
                await OnSendSignalingMessage("STREAM_ERROR", new { error = error });
            }
        }

        private void Log(string message)
        {
            var logPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "debug_log.txt");
            try { File.AppendAllText(logPath, $"{DateTime.Now}: {message}\n"); } catch { }
            Console.WriteLine(message);
        }
    }
}
