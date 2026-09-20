using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Net.Http.Json;
using System.Text.Json.Serialization;
using System.Threading.Tasks;
using Microsoft.Data.Sqlite;
using Sanad.Core.Models;

namespace Sanad.Core.Services
{
    public class BrowserHistoryItem
    {
        [JsonPropertyName("browser")]
        public string Browser { get; set; } = string.Empty;

        [JsonPropertyName("url")]
        public string Url { get; set; } = string.Empty;

        [JsonPropertyName("title")]
        public string Title { get; set; } = string.Empty;

        [JsonPropertyName("visit_count")]
        public int VisitCount { get; set; } = 1;

        [JsonPropertyName("duration_seconds")]
        public int DurationSeconds { get; set; } = 0;

        [JsonPropertyName("timestamp")]
        public long Timestamp { get; set; }
    }

    public class BrowserHistoryService
    {
        private readonly ConfigService _configService;
        private readonly HttpClient _httpClient;
        private readonly HashSet<string> _syncedUrls = new(StringComparer.OrdinalIgnoreCase);

        public BrowserHistoryService(ConfigService configService)
        {
            _configService = configService;
            _httpClient = new HttpClient
            {
                Timeout = TimeSpan.FromSeconds(20)
            };
        }

        public async Task<int> CollectAndSyncHistoryAsync()
        {
            var cfg = _configService.Current;
            if (string.IsNullOrEmpty(cfg.DeviceId) || string.IsNullOrEmpty(cfg.PairingSecret) || cfg.IsMonitoringPaused)
            {
                return 0;
            }

            var allItems = new List<BrowserHistoryItem>();

            // 1. Google Chrome
            try
            {
                var chromeItems = ReadChromiumHistory("chrome", Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    "Google", "Chrome", "User Data", "Default", "History"
                ));
                allItems.AddRange(chromeItems);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[BrowserHistory] Chrome read error: {ex.Message}");
            }

            // 2. Microsoft Edge
            try
            {
                var edgeItems = ReadChromiumHistory("edge", Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    "Microsoft", "Edge", "User Data", "Default", "History"
                ));
                allItems.AddRange(edgeItems);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[BrowserHistory] Edge read error: {ex.Message}");
            }

            // 3. Mozilla Firefox
            try
            {
                var firefoxItems = ReadFirefoxHistory();
                allItems.AddRange(firefoxItems);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[BrowserHistory] Firefox read error: {ex.Message}");
            }

            // Filter already synced URLs in current runtime session
            var newItems = new List<BrowserHistoryItem>();
            foreach (var item in allItems)
            {
                var key = $"{item.Browser}|{item.Url}|{item.Timestamp}";
                if (!_syncedUrls.Contains(key))
                {
                    newItems.Add(item);
                    _syncedUrls.Add(key);
                }
            }

            if (newItems.Count == 0)
            {
                return 0;
            }

            // Send to backend
            try
            {
                var endpoint = $"{cfg.ServerUrl.TrimEnd('/')}/api/v1/agent/{cfg.DeviceId}/browser-history";
                var req = new HttpRequestMessage(HttpMethod.Post, endpoint)
                {
                    Content = JsonContent.Create(new { items = newItems })
                };
                req.Headers.Add("X-Device-Secret", cfg.PairingSecret);

                var resp = await _httpClient.SendAsync(req);
                if (resp.IsSuccessStatusCode)
                {
                    Console.WriteLine($"[BrowserHistory] Successfully synced {newItems.Count} history items to SANAD Cloud");
                    return newItems.Count;
                }
                else
                {
                    Console.WriteLine($"[BrowserHistory] Server returned {resp.StatusCode}");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[BrowserHistory] Sync request error: {ex.Message}");
            }

            return 0;
        }

        private List<BrowserHistoryItem> ReadChromiumHistory(string browserName, string historyDbPath)
        {
            var results = new List<BrowserHistoryItem>();
            if (!File.Exists(historyDbPath)) return results;

            var tempFile = Path.Combine(Path.GetTempPath(), $"sanad_{browserName}_{Guid.NewGuid():N}.db");
            try
            {
                File.Copy(historyDbPath, tempFile, true);

                using var conn = new SqliteConnection($"Data Source={tempFile};Mode=ReadOnly");
                conn.Open();

                using var cmd = conn.CreateCommand();
                cmd.CommandText = "SELECT url, title, visit_count, last_visit_time FROM urls WHERE last_visit_time > 0 ORDER BY last_visit_time DESC LIMIT 40;";

                using var reader = cmd.ExecuteReader();
                var webkitEpoch = new DateTime(1601, 1, 1, 0, 0, 0, DateTimeKind.Utc);

                while (reader.Read())
                {
                    var url = reader.IsDBNull(0) ? "" : reader.GetString(0);
                    var title = reader.IsDBNull(1) ? "" : reader.GetString(1);
                    var count = reader.IsDBNull(2) ? 1 : reader.GetInt32(2);
                    var webkitTime = reader.IsDBNull(3) ? 0L : reader.GetInt64(3);

                    if (string.IsNullOrWhiteSpace(url) || url.StartsWith("chrome://") || url.StartsWith("edge://") || url.StartsWith("about:"))
                        continue;

                    long unixSeconds = 0;
                    if (webkitTime > 0)
                    {
                        try
                        {
                            var visitUtc = webkitEpoch.AddTicks(webkitTime * 10);
                            unixSeconds = ((DateTimeOffset)visitUtc).ToUnixTimeSeconds();
                        }
                        catch { }
                    }

                    results.Add(new BrowserHistoryItem
                    {
                        Browser = browserName,
                        Url = url,
                        Title = title,
                        VisitCount = count,
                        Timestamp = unixSeconds
                    });
                }
            }
            finally
            {
                try { if (File.Exists(tempFile)) File.Delete(tempFile); } catch { }
            }

            return results;
        }

        private List<BrowserHistoryItem> ReadFirefoxHistory()
        {
            var results = new List<BrowserHistoryItem>();
            var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            var profilesDir = Path.Combine(appData, "Mozilla", "Firefox", "Profiles");
            if (!Directory.Exists(profilesDir)) return results;

            var profiles = Directory.GetDirectories(profilesDir);
            foreach (var prof in profiles)
            {
                var placesPath = Path.Combine(prof, "places.sqlite");
                if (!File.Exists(placesPath)) continue;

                var tempFile = Path.Combine(Path.GetTempPath(), $"sanad_firefox_{Guid.NewGuid():N}.db");
                try
                {
                    File.Copy(placesPath, tempFile, true);

                    using var conn = new SqliteConnection($"Data Source={tempFile};Mode=ReadOnly");
                    conn.Open();

                    using var cmd = conn.CreateCommand();
                    cmd.CommandText = "SELECT url, title, visit_count, last_visit_date FROM moz_places WHERE last_visit_date IS NOT NULL AND url NOT LIKE 'about:%' ORDER BY last_visit_date DESC LIMIT 40;";

                    using var reader = cmd.ExecuteReader();
                    while (reader.Read())
                    {
                        var url = reader.IsDBNull(0) ? "" : reader.GetString(0);
                        var title = reader.IsDBNull(1) ? "" : reader.GetString(1);
                        var count = reader.IsDBNull(2) ? 1 : reader.GetInt32(2);
                        var ffMicro = reader.IsDBNull(3) ? 0L : reader.GetInt64(3);

                        long unixSeconds = ffMicro > 0 ? ffMicro / 1_000_000L : DateTimeOffset.UtcNow.ToUnixTimeSeconds();

                        results.Add(new BrowserHistoryItem
                        {
                            Browser = "firefox",
                            Url = url,
                            Title = title,
                            VisitCount = count,
                            Timestamp = unixSeconds
                        });
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[BrowserHistory] Firefox profile read error: {ex.Message}");
                }
                finally
                {
                    try { if (File.Exists(tempFile)) File.Delete(tempFile); } catch { }
                }
            }

            return results;
        }
    }
}
