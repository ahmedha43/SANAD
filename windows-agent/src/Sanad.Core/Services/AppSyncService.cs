using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Net.Http.Json;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Win32;
using Sanad.Core.Models;

namespace Sanad.Core.Services
{
    public class AppSyncService
    {
        [DllImport("user32.dll")]
        private static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll", SetLastError = true)]
        private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

        private readonly ConfigService _configService;
        private readonly HttpClient _httpClient;
        private CancellationTokenSource? _cts;

        // Daily usage tracking: package_name -> seconds
        private readonly ConcurrentDictionary<string, int> _dailyUsage = new();
        private readonly ConcurrentDictionary<string, int> _openCounts = new();
        private string _lastActivePkg = string.Empty;

        public AppSyncService(ConfigService configService)
        {
            _configService = configService;
            _httpClient = new HttpClient { Timeout = TimeSpan.FromSeconds(15) };
        }

        public void Start()
        {
            Stop();
            _cts = new CancellationTokenSource();
            Task.Run(() => AppTrackingLoopAsync(_cts.Token));
        }

        public void Stop()
        {
            _cts?.Cancel();
            _cts = null;
        }

        public async Task SyncInstalledAppsAsync(AgentConfig cfg, CancellationToken token = default)
        {
            try
            {
                var apps = GetInstalledApps();
                Log($"[AppSync] Discovered {apps.Count} installed applications.");

                var postUrl = $"{cfg.ServerUrl}/api/v1/devices/{cfg.DeviceId}/apps/sync";
                var payload = new { apps = apps };

                var response = await _httpClient.PostAsJsonAsync(postUrl, payload, token);
                Log($"[AppSync] Synced apps to server: Status={response.StatusCode}");
            }
            catch (Exception ex)
            {
                Log($"[AppSync] Error syncing installed apps: {ex.Message}");
            }
        }

        public List<object> GetInstalledApps()
        {
            var appsMap = new Dictionary<string, (string name, bool isSystem)>(StringComparer.OrdinalIgnoreCase);

            // 1. Scan 64-bit and 32-bit registry uninstall keys
            ScanRegistryKey(Registry.LocalMachine, @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", appsMap);
            ScanRegistryKey(Registry.LocalMachine, @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall", appsMap);
            ScanRegistryKey(Registry.CurrentUser, @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", appsMap);

            // 2. Add common known applications if running or installed
            var commonPrograms = new (string pkg, string name)[]
            {
                ("chrome", "Google Chrome"),
                ("msedge", "Microsoft Edge"),
                ("firefox", "Mozilla Firefox"),
                ("discord", "Discord"),
                ("steam", "Steam"),
                ("robloxplayerbeta", "Roblox"),
                ("spotify", "Spotify"),
                ("telegram", "Telegram Desktop"),
                ("whatsapp", "WhatsApp"),
                ("epicgameslauncher", "Epic Games Launcher"),
                ("minecraft", "Minecraft Launcher"),
                ("notepad", "Notepad"),
                ("calc", "Calculator"),
                ("explorer", "Windows Explorer")
            };

            foreach (var (pkg, name) in commonPrograms)
            {
                if (!appsMap.ContainsKey(pkg))
                {
                    appsMap[pkg] = (name, false);
                }
            }

            var cfg = _configService.Current;
            var result = new List<object>();

            foreach (var kvp in appsMap)
            {
                var isBlocked = cfg.BlockedProcesses.Contains(kvp.Key, StringComparer.OrdinalIgnoreCase);
                result.Add(new
                {
                    package_name = kvp.Key,
                    app_name = kvp.Value.name,
                    is_system_app = kvp.Value.isSystem,
                    is_blocked = isBlocked
                });
            }

            return result;
        }

        private void ScanRegistryKey(RegistryKey root, string subKeyPath, Dictionary<string, (string name, bool isSystem)> map)
        {
            try
            {
                using var key = root.OpenSubKey(subKeyPath);
                if (key == null) return;

                foreach (var subKeyName in key.GetSubKeyNames())
                {
                    try
                    {
                        using var subKey = key.OpenSubKey(subKeyName);
                        if (subKey == null) continue;

                        var displayName = subKey.GetValue("DisplayName") as string;
                        if (string.IsNullOrWhiteSpace(displayName)) continue;

                        var systemComponent = subKey.GetValue("SystemComponent") as int?;
                        if (systemComponent.HasValue && systemComponent.Value == 1) continue;

                        var parentKey = subKey.GetValue("ParentKeyName") as string;
                        if (!string.IsNullOrEmpty(parentKey)) continue;

                        // Create clean package identifier
                        var pkg = CleanPackageName(displayName);
                        if (string.IsNullOrEmpty(pkg) || pkg.Length < 2) continue;

                        if (!map.ContainsKey(pkg))
                        {
                            map[pkg] = (displayName.Trim(), false);
                        }
                    }
                    catch { }
                }
            }
            catch { }
        }

        private string CleanPackageName(string displayName)
        {
            var clean = Regex.Replace(displayName, @"[^a-zA-Z0-9_\-\.]", "").ToLowerInvariant();
            if (clean.Length > 50) clean = clean.Substring(0, 50);
            return clean;
        }

        private async Task AppTrackingLoopAsync(CancellationToken token)
        {
            // Initial sync of installed apps
            await Task.Delay(3000, token);
            var cfg = _configService.Current;
            if (cfg.IsPaired && !string.IsNullOrEmpty(cfg.DeviceId))
            {
                await SyncInstalledAppsAsync(cfg, token);
            }

            var usageFlushCounter = 0;

            while (!token.IsCancellationRequested)
            {
                try
                {
                    // Check active foreground window every 2 seconds
                    TrackActiveWindow();

                    usageFlushCounter += 2;
                    if (usageFlushCounter >= 60) // Flush usage every 60 seconds
                    {
                        usageFlushCounter = 0;
                        await FlushDailyUsageAsync(token);
                    }
                }
                catch { }

                try
                {
                    await Task.Delay(2000, token);
                }
                catch (OperationCanceledException)
                {
                    break;
                }
            }
        }

        private void TrackActiveWindow()
        {
            try
            {
                var hwnd = GetForegroundWindow();
                if (hwnd == IntPtr.Zero) return;

                GetWindowThreadProcessId(hwnd, out var pid);
                if (pid == 0) return;

                Process proc;
                try
                {
                    proc = Process.GetProcessById((int)pid);
                }
                catch
                {
                    return;
                }

                var procName = proc.ProcessName?.ToLowerInvariant();

                if (!string.IsNullOrEmpty(procName))
                {
                    _dailyUsage.AddOrUpdate(procName, 2, (k, v) => v + 2);

                    if (procName != _lastActivePkg)
                    {
                        _lastActivePkg = procName;
                        _openCounts.AddOrUpdate(procName, 1, (k, v) => v + 1);
                    }
                }
            }
            catch { }
        }

        private async Task FlushDailyUsageAsync(CancellationToken token)
        {
            var cfg = _configService.Current;
            if (!cfg.IsPaired || string.IsNullOrEmpty(cfg.DeviceId) || _dailyUsage.IsEmpty) return;

            try
            {
                var today = DateTime.UtcNow.ToString("yyyy-MM-dd");
                var items = new List<object>();

                foreach (var kvp in _dailyUsage)
                {
                    var count = _openCounts.TryGetValue(kvp.Key, out var c) ? c : 1;
                    items.Add(new
                    {
                        package_name = kvp.Key,
                        date = today,
                        usage_duration_seconds = kvp.Value,
                        open_count = count
                    });
                }

                if (items.Count > 0)
                {
                    var postUrl = $"{cfg.ServerUrl}/api/v1/devices/{cfg.DeviceId}/usage";
                    await _httpClient.PostAsJsonAsync(postUrl, items, token);
                }
            }
            catch (Exception ex)
            {
                Log($"[AppSync] Error flushing daily usage: {ex.Message}");
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
    }
}
