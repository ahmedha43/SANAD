using System;
using System.Net.Http;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading;
using System.Threading.Tasks;
using Sanad.Core.Models;

namespace Sanad.Core.Services
{
    public class LocationSyncService
    {
        private readonly ConfigService _configService;
        private readonly HttpClient _httpClient;
        private CancellationTokenSource? _cts;
        private double _lastLat = 0;
        private double _lastLon = 0;

        public event Func<double, double, float, Task>? OnLocationUpdated;

        public LocationSyncService(ConfigService configService)
        {
            _configService = configService;
            _httpClient = new HttpClient { Timeout = TimeSpan.FromSeconds(10) };
        }

        public void Start()
        {
            Stop();
            _cts = new CancellationTokenSource();
            Task.Run(() => SyncLoopAsync(_cts.Token));
        }

        public void Stop()
        {
            _cts?.Cancel();
            _cts = null;
        }

        private async Task SyncLoopAsync(CancellationToken token)
        {
            // Initial delay to let WS connect
            await Task.Delay(2000, token);

            while (!token.IsCancellationRequested)
            {
                try
                {
                    var cfg = _configService.Current;
                    if (cfg.IsPaired && !string.IsNullOrEmpty(cfg.DeviceId))
                    {
                        await FetchAndSyncLocationAsync(cfg, token);
                    }
                }
                catch (Exception ex)
                {
                    Log($"[LocationSync] Error: {ex.Message}");
                }

                // Sync location every 60 seconds
                try
                {
                    await Task.Delay(60000, token);
                }
                catch (OperationCanceledException)
                {
                    break;
                }
            }
        }

        public async Task FetchAndSyncLocationAsync(AgentConfig cfg, CancellationToken token = default)
        {
            try
            {
                // 1. Fetch IP-based geolocation
                var ipGeo = await _httpClient.GetFromJsonAsync<IpApiResponse>("http://ip-api.com/json", token);
                if (ipGeo != null && ipGeo.Status == "success")
                {
                    _lastLat = ipGeo.Lat;
                    _lastLon = ipGeo.Lon;

                    Log($"[LocationSync] Detected location: {ipGeo.City}, {ipGeo.Country} ({ipGeo.Lat}, {ipGeo.Lon})");

                    // 2. Post to backend REST endpoint
                    var postUrl = $"{cfg.ServerUrl}/api/v1/devices/{cfg.DeviceId}/location";
                    var payload = new
                    {
                        latitude = ipGeo.Lat,
                        longitude = ipGeo.Lon,
                        accuracy = 50.0f,
                        altitude = 0.0f,
                        speed = 0.0f,
                        bearing = 0.0f
                    };

                    var response = await _httpClient.PostAsJsonAsync(postUrl, payload, token);
                    Log($"[LocationSync] Posted location to server: Status={response.StatusCode}");

                    // 3. Notify WebSocket client to broadcast real-time update
                    if (OnLocationUpdated != null)
                    {
                        await OnLocationUpdated(ipGeo.Lat, ipGeo.Lon, 50.0f);
                    }
                }
            }
            catch (Exception ex)
            {
                Log($"[LocationSync] Geolocation fetch error: {ex.Message}");
            }
        }

        private void Log(string message)
        {
            var logPath = System.IO.Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "debug_log.txt");
            try
            {
                System.IO.File.AppendAllText(logPath, $"{DateTime.Now}: {message}\n");
            }
            catch { }
            Console.WriteLine(message);
        }

        private class IpApiResponse
        {
            [JsonPropertyName("status")]
            public string Status { get; set; } = string.Empty;

            [JsonPropertyName("country")]
            public string Country { get; set; } = string.Empty;

            [JsonPropertyName("city")]
            public string City { get; set; } = string.Empty;

            [JsonPropertyName("lat")]
            public double Lat { get; set; }

            [JsonPropertyName("lon")]
            public double Lon { get; set; }
        }
    }
}
