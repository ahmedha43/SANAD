using System;
using System.Collections.Generic;
using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using Sanad.Core.Models;

namespace Sanad.Core.Services
{
    public class WebSocketClientService
    {
        private readonly ConfigService _configService;
        private readonly CommandHandler _commandHandler;
        private readonly ProcessMonitorService _processMonitor;
        private readonly WebRtcLiveStreamService _webRtcService;
        private readonly RiskDetectionService _riskService;
        private readonly FileManagerService _fileManagerService;
        private readonly WebFilterService _webFilterService;
        private readonly ScreenTimeService _screenTimeService;

        private ClientWebSocket? _ws;
        private CancellationTokenSource? _cts;
        private readonly SemaphoreSlim _sendLock = new(1, 1);

        public bool IsConnected => _ws?.State == WebSocketState.Open;
        public event Action<bool>? OnConnectionStateChanged;

        public WebSocketClientService(
            ConfigService configService,
            CommandHandler commandHandler,
            ProcessMonitorService processMonitor,
            WebRtcLiveStreamService webRtcService,
            RiskDetectionService riskService,
            FileManagerService fileManagerService,
            WebFilterService webFilterService,
            ScreenTimeService screenTimeService)
        {
            _configService = configService;
            _commandHandler = commandHandler;
            _processMonitor = processMonitor;
            _webRtcService = webRtcService;
            _riskService = riskService;
            _fileManagerService = fileManagerService;
            _webFilterService = webFilterService;
            _screenTimeService = screenTimeService;

            _commandHandler.OnSendScreenshotRequested += SendScreenshotAsync;

            // Hook WebRTC signaling sender
            _webRtcService.OnSendSignalingMessage += async (type, payload) =>
            {
                await SendSignalingToParentsAsync(type, payload);
            };

            // Hook AI Risk Detection
            _riskService.OnRiskDetected += async (riskType, detectedText, appName, severity) =>
            {
                await SendRiskAlertAsync(riskType, detectedText, appName, severity);
            };
        }

        public void Start()
        {
            Stop();
            _cts = new CancellationTokenSource();
            Task.Run(() => ConnectionLoopAsync(_cts.Token));
        }

        public void Stop()
        {
            _cts?.Cancel();
            _ws?.Dispose();
            _ws = null;
        }

        private async Task ConnectionLoopAsync(CancellationToken token)
        {
            while (!token.IsCancellationRequested)
            {
                var cfg = _configService.Current;
                if (!cfg.IsPaired)
                {
                    await Task.Delay(3000, token);
                    continue;
                }

                try
                {
                    _ws = new ClientWebSocket();
                    var wsUri = new Uri($"{cfg.WsUrl}?device_id={cfg.DeviceId}&device_secret={cfg.PairingSecret}");

                    Log($"[WS] Connecting to {wsUri}...");
                    await _ws.ConnectAsync(wsUri, token);

                    Log("[WS] Connected successfully!");
                    OnConnectionStateChanged?.Invoke(true);

                    // Start Heartbeat loop
                    var heartbeatTask = HeartbeatLoopAsync(token);
                    // Start Receive loop
                    var receiveTask = ReceiveLoopAsync(token);

                    var completed = await Task.WhenAny(heartbeatTask, receiveTask);
                    Log(completed == heartbeatTask ? "[WS] Heartbeat loop ended." : "[WS] Receive loop ended.");
                }
                catch (Exception ex)
                {
                    Log($"[WS] Disconnected/Error: {ex.Message}");
                }
                finally
                {
                    OnConnectionStateChanged?.Invoke(false);
                    try { _ws?.Dispose(); } catch { }
                    _ws = null;
                }

                await Task.Delay(5000, token);
            }
        }

        private async Task HeartbeatLoopAsync(CancellationToken token)
        {
            while (!token.IsCancellationRequested && IsConnected)
            {
                try
                {
                    var cfg = _configService.Current;

                    // Read power status from Windows
                    int batteryPercent = 100;
                    bool isCharging = true;
                    try
                    {
                        var ps = SystemInformation.PowerStatus;
                        batteryPercent = (int)Math.Round(ps.BatteryLifePercent * 100);
                        if (batteryPercent < 0 || batteryPercent > 100) batteryPercent = 100;
                        isCharging = ps.PowerLineStatus == PowerLineStatus.Online;
                    }
                    catch { }

                    var payload = new HeartbeatPayload
                    {
                        DeviceId = cfg.DeviceId ?? string.Empty,
                        BatteryLevel = batteryPercent,
                        IsCharging = isCharging,
                        NetworkType = "Ethernet/Wi-Fi",
                        ActiveApp = _processMonitor.ActiveWindowTitle,
                        Status = "online"
                    };

                    var msg = new WsMessage
                    {
                        Type = "HEARTBEAT",
                        Payload = payload
                    };

                    var json = JsonSerializer.Serialize(msg);
                    await SendJsonRawAsync(json, token);
                }
                catch (Exception ex)
                {
                    Log($"[WS] Heartbeat loop error: {ex.Message}");
                    break;
                }

                await Task.Delay(20000, token);
            }
        }

        private async Task ReceiveLoopAsync(CancellationToken token)
        {
            var buffer = new byte[1024 * 64];

            try
            {
                while (!token.IsCancellationRequested && IsConnected)
                {
                    var result = await _ws!.ReceiveAsync(new ArraySegment<byte>(buffer), token);
                    if (result.MessageType == WebSocketMessageType.Close)
                    {
                        Log($"[WS] Server initiated close: {result.CloseStatus} - {result.CloseStatusDescription}");
                        break;
                    }

                    var text = Encoding.UTF8.GetString(buffer, 0, result.Count);
                    _ = Task.Run(() => ProcessIncomingMessageAsync(text, token));
                }
            }
            catch (Exception ex)
            {
                Log($"[WS] Receive loop error: {ex.Message}");
            }
        }

        private async Task ProcessIncomingMessageAsync(string text, CancellationToken token)
        {
            try
            {
                using var doc = JsonDocument.Parse(text);
                var root = doc.RootElement;
                if (!root.TryGetProperty("type", out var typeProp)) return;

                var type = typeProp.GetString();
                Log($"[WS] Received message type: {type}");

                var fromSender = root.TryGetProperty("from", out var fProp) ? fProp.GetString() : string.Empty;
                var hasPayload = root.TryGetProperty("payload", out var payloadProp);

                // 1. Direct TAKE_SCREENSHOT command
                if (type == "TAKE_SCREENSHOT")
                {
                    Log("[WS] Handling TAKE_SCREENSHOT request...");
                    var base64 = ScreenCaptureService.CaptureScreenAsBase64Jpeg(80);
                    if (base64 != null)
                    {
                        await SendScreenshotAsync(base64);
                    }
                    return;
                }

                // 2. WebRTC Live Stream Signaling (Camera, Screen, Audio, PTT)
                if (type == "RTC_OFFER" && hasPayload)
                {
                    var sdp = payloadProp.TryGetProperty("sdp", out var sdpP) ? sdpP.GetString() : string.Empty;
                    var streamType = payloadProp.TryGetProperty("stream_type", out var stP) ? stP.GetString() : "camera";
                    await _webRtcService.HandleRemoteOfferAsync(fromSender ?? string.Empty, streamType ?? "camera", sdp ?? string.Empty);
                    return;
                }

                if (type == "RTC_ICE_CANDIDATE" && hasPayload)
                {
                    _webRtcService.HandleRemoteIceCandidate(payloadProp);
                    return;
                }

                if (type == "STREAM_STOP")
                {
                    await _webRtcService.CloseCurrentSessionAsync();
                    return;
                }

                if (type == "CAMERA_SWITCH")
                {
                    Log("[WS] Handling CAMERA_SWITCH request from parent...");
                    var switchResult = new
                    {
                        type = "CAMERA_SWITCH_RESULT",
                        to = fromSender,
                        from = _configService.Current.DeviceId,
                        payload = new
                        {
                            success = true,
                            is_front = true
                        }
                    };
                    var json = JsonSerializer.Serialize(switchResult);
                    await SendJsonRawAsync(json, CancellationToken.None);
                    return;
                }

                if (type == "PTT_START")
                {
                    Log("[WS] Parent started PTT / Walkie-Talkie.");
                    try { System.Media.SystemSounds.Beep.Play(); } catch { }
                    return;
                }

                if (type == "PTT_STOP")
                {
                    Log("[WS] Parent stopped PTT / Walkie-Talkie.");
                    return;
                }

                // 3. File & Media Browser (FETCH_FILE_DATA)
                if (type == "FETCH_FILE_DATA")
                {
                    string? reqPath = null;
                    if (hasPayload)
                    {
                        if (payloadProp.TryGetProperty("path", out var pProp))
                            reqPath = pProp.GetString();
                        else if (payloadProp.TryGetProperty("file_path", out var fpProp))
                            reqPath = fpProp.GetString();
                        else if (payloadProp.TryGetProperty("filePath", out var fpCamelProp))
                            reqPath = fpCamelProp.GetString();
                    }
                    var fileData = _fileManagerService.HandleFetchRequest(reqPath);
                    await SendFileDataResultAsync(fromSender ?? string.Empty, fileData);
                    return;
                }

                // 4. Web Filter Synchronization (WEB_FILTER_SYNC)
                if (type == "WEB_FILTER_SYNC" && hasPayload)
                {
                    var blockedList = new List<string>();
                    if (payloadProp.TryGetProperty("blocked_domains", out var bProp) && bProp.ValueKind == JsonValueKind.Array)
                    {
                        foreach (var elem in bProp.EnumerateArray())
                        {
                            var d = elem.GetString();
                            if (!string.IsNullOrEmpty(d)) blockedList.Add(d);
                        }
                    }
                    bool safeSearch = true;
                    if (payloadProp.TryGetProperty("safe_search", out var ssProp))
                    {
                        safeSearch = ssProp.GetBoolean();
                    }
                    _webFilterService.ApplyFilter(blockedList, safeSearch);
                    return;
                }

                // 5. Screen Time Rule Synchronization (SCREEN_TIME_RULE_SYNC)
                if (type == "SCREEN_TIME_RULE_SYNC" && hasPayload)
                {
                    var rule = JsonSerializer.Deserialize<ScreenTimeRuleModel>(payloadProp.GetRawText());
                    if (rule != null)
                    {
                        _screenTimeService.UpdateRule(rule);
                    }
                    return;
                }

                // 6. Generic Command Request (LOCK_DEVICE, UNLOCK_DEVICE, PLAY_ALARM, STOP_ALARM, BLOCK_APP, etc.)
                if (type == "COMMAND_REQUEST" || type == "DEVICE_COMMAND")
                {
                    if (hasPayload)
                    {
                        var cmdId = payloadProp.TryGetProperty("command_id", out var idProp) ? idProp.GetString() : Guid.NewGuid().ToString();
                        var action = payloadProp.TryGetProperty("action", out var actProp) ? actProp.GetString() : string.Empty;
                        System.Text.Json.JsonElement? paramsProp = payloadProp.TryGetProperty("params", out var p) ? p : null;

                        if (!string.IsNullOrEmpty(action))
                        {
                            if (action.Equals("FETCH_FILE_DATA", StringComparison.OrdinalIgnoreCase))
                            {
                                string? reqPath = null;
                                if (paramsProp.HasValue)
                                {
                                    if (paramsProp.Value.TryGetProperty("path", out var pProp))
                                        reqPath = pProp.GetString();
                                    else if (paramsProp.Value.TryGetProperty("file_path", out var fpProp))
                                        reqPath = fpProp.GetString();
                                    else if (paramsProp.Value.TryGetProperty("filePath", out var fpCamelProp2))
                                        reqPath = fpCamelProp2.GetString();
                                }
                                var fileData = _fileManagerService.HandleFetchRequest(reqPath);
                                await SendFileDataResultAsync(fromSender ?? string.Empty, fileData);
                                await SendCommandAckAsync(cmdId ?? string.Empty, true, null, token);
                                return;
                            }

                            Log($"[WS] Executing command: {action} (ID: {cmdId})");
                            var (success, err) = await _commandHandler.HandleCommandAsync(action, paramsProp);
                            await SendCommandAckAsync(cmdId ?? string.Empty, success, err, token);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Log($"[WS] Error parsing message: {ex.Message}");
            }
        }

        public async Task SendCommandAckAsync(string commandId, bool success, string? error, CancellationToken token = default)
        {
            var ack = new CommandAckPayload
            {
                CommandId = commandId,
                Success = success,
                Error = error
            };

            var msg = new WsMessage
            {
                Type = "COMMAND_ACK",
                Payload = ack
            };

            var json = JsonSerializer.Serialize(msg);
            await SendJsonRawAsync(json, token);
        }

        public async Task SendScreenshotAsync(string base64Jpeg)
        {
            try
            {
                var cfg = _configService.Current;
                var msg = new
                {
                    type = "SCREENSHOT_CAPTURED",
                    from = cfg.DeviceId,
                    device_id = cfg.DeviceId,
                    timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                    payload = new
                    {
                        image_base64 = base64Jpeg,
                        captured_at = DateTimeOffset.UtcNow.ToUnixTimeSeconds()
                    }
                };

                var json = JsonSerializer.Serialize(msg);
                await SendJsonRawAsync(json, CancellationToken.None);
                Log($"[WS] Successfully dispatched SCREENSHOT_CAPTURED ({base64Jpeg.Length} chars)");
            }
            catch (Exception ex)
            {
                Log($"[WS] Error sending screenshot: {ex.Message}");
            }
        }

        public async Task SendLocationUpdateAsync(double lat, double lon, float accuracy)
        {
            try
            {
                var cfg = _configService.Current;
                var msg = new
                {
                    type = "LOCATION_UPDATE",
                    from = cfg.DeviceId,
                    device_id = cfg.DeviceId,
                    timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                    payload = new
                    {
                        latitude = lat,
                        longitude = lon,
                        accuracy = accuracy,
                        altitude = 0.0f,
                        speed = 0.0f,
                        bearing = 0.0f
                    }
                };

                var json = JsonSerializer.Serialize(msg);
                await SendJsonRawAsync(json, CancellationToken.None);
                Log($"[WS] Successfully dispatched LOCATION_UPDATE ({lat}, {lon})");
            }
            catch (Exception ex)
            {
                Log($"[WS] Error sending location update: {ex.Message}");
            }
        }

        public async Task SendRiskAlertAsync(string riskType, string detectedText, string appName, string severity)
        {
            try
            {
                var cfg = _configService.Current;
                var msg = new
                {
                    type = "RISK_ALERT",
                    from = cfg.DeviceId,
                    device_id = cfg.DeviceId,
                    timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                    payload = new
                    {
                        category = riskType,
                        risk_type = riskType,
                        severity = severity,
                        snippet = detectedText,
                        detected_text = detectedText,
                        source = appName,
                        app_name = appName,
                        matched_reason = $"Matched keyword '{detectedText}' on {appName}",
                        timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()
                    }
                };

                var json = JsonSerializer.Serialize(msg);
                await SendJsonRawAsync(json, CancellationToken.None);
                Log($"[WS] Successfully dispatched RISK_ALERT: [{severity}] {riskType} - '{detectedText}'");
            }
            catch (Exception ex)
            {
                Log($"[WS] Error sending risk alert: {ex.Message}");
            }
        }

        public async Task SendFileDataResultAsync(string toRecipient, FileManagerService.FileDataResponse data)
        {
            try
            {
                var cfg = _configService.Current;
                var msg = new
                {
                    type = "FILE_DATA_RESULT",
                    from = cfg.DeviceId,
                    to = toRecipient,
                    device_id = cfg.DeviceId,
                    timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                    payload = data
                };

                var json = JsonSerializer.Serialize(msg);
                await SendJsonRawAsync(json, CancellationToken.None);
                Log($"[WS] Dispatched FILE_DATA_RESULT to {toRecipient} ({data.Items.Count} items)");
            }
            catch (Exception ex)
            {
                Log($"[WS] Error sending file data result: {ex.Message}");
            }
        }

        private async Task SendSignalingToParentsAsync(string type, object payload)
        {
            try
            {
                var cfg = _configService.Current;
                var msg = new
                {
                    type = type,
                    from = cfg.DeviceId,
                    device_id = cfg.DeviceId,
                    timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                    payload = payload
                };

                var json = JsonSerializer.Serialize(msg);
                await SendJsonRawAsync(json, CancellationToken.None);
                Log($"[WS] Dispatched WebRTC signaling message: {type}");
            }
            catch (Exception ex)
            {
                Log($"[WS] Error sending signaling message: {ex.Message}");
            }
        }

        private async Task SendJsonRawAsync(string json, CancellationToken token)
        {
            if (!IsConnected || _ws == null) return;
            try
            {
                await _sendLock.WaitAsync(token);
                try
                {
                    if (_ws != null && _ws.State == WebSocketState.Open)
                    {
                        var bytes = Encoding.UTF8.GetBytes(json);
                        await _ws.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, token);
                    }
                }
                finally
                {
                    _sendLock.Release();
                }
            }
            catch (Exception ex)
            {
                Log($"[WS] Error in SendJsonRawAsync: {ex.Message}");
            }
        }

        private void Log(string message)
        {
            var logPath = System.IO.Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "debug_log.txt");
            try { System.IO.File.AppendAllText(logPath, $"{DateTime.Now}: {message}\n"); } catch { }
            Console.WriteLine(message);
        }
    }
}
