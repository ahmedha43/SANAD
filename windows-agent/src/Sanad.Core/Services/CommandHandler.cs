using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using Sanad.Core.Models;

namespace Sanad.Core.Services
{
    public class CommandHandler
    {
        [DllImport("user32.dll")]
        public static extern bool LockWorkStation();

        private readonly ConfigService _configService;
        private readonly AudioAlarmService _audioAlarmService;

        public event Action? OnLockRequested;
        public event Action? OnUnlockRequested;
        public event Func<string, Task>? OnSendScreenshotRequested;

        public CommandHandler(ConfigService configService, AudioAlarmService audioAlarmService)
        {
            _configService = configService;
            _audioAlarmService = audioAlarmService;
        }

        public async Task<(bool success, string? error)> HandleCommandAsync(string action, System.Text.Json.JsonElement? parameters)
        {
            Console.WriteLine($"[CommandHandler] Executing action: {action}");

            switch (action.ToUpperInvariant())
            {
                case "LOCK_DEVICE":
                case "LOCK":
                    LockWorkStation();
                    _configService.Current.IsDeviceLocked = true;
                    _configService.Save(_configService.Current);
                    OnLockRequested?.Invoke();
                    return (true, null);

                case "UNLOCK_DEVICE":
                case "UNLOCK":
                    _configService.Current.IsDeviceLocked = false;
                    _configService.Save(_configService.Current);
                    OnUnlockRequested?.Invoke();
                    return (true, null);

                case "PLAY_ALARM":
                    _audioAlarmService.StartAlarm();
                    return (true, null);

                case "STOP_ALARM":
                    _audioAlarmService.StopAlarm();
                    return (true, null);

                case "TAKE_SCREENSHOT":
                case "SCREENSHOT":
                    var base64 = ScreenCaptureService.CaptureScreenAsBase64Jpeg();
                    if (base64 != null && OnSendScreenshotRequested != null)
                    {
                        await OnSendScreenshotRequested(base64);
                    }
                    return (true, null);

                case "REBOOT":
                    Process.Start("shutdown.exe", "/r /t 5 /c \"Restarting by SANAD\"");
                    return (true, null);

                case "SHUTDOWN":
                    Process.Start("shutdown.exe", "/s /t 5 /c \"Shutting down by SANAD\"");
                    return (true, null);

                case "PAUSE_MONITORING":
                    _configService.Current.IsMonitoringPaused = true;
                    _configService.Save(_configService.Current);
                    return (true, null);

                case "RESUME_MONITORING":
                    _configService.Current.IsMonitoringPaused = false;
                    _configService.Save(_configService.Current);
                    return (true, null);

                case "BLOCK_APP":
                    string? appName = null;
                    if (parameters.HasValue)
                    {
                        if (parameters.Value.TryGetProperty("package_name", out var pkgProp) ||
                            parameters.Value.TryGetProperty("package", out pkgProp))
                        {
                            appName = pkgProp.GetString();
                        }
                    }
                    if (!string.IsNullOrEmpty(appName) && !_configService.Current.BlockedProcesses.Contains(appName))
                    {
                        _configService.Current.BlockedProcesses.Add(appName);
                        _configService.Save(_configService.Current);
                    }
                    return (true, null);

                case "UNBLOCK_APP":
                    string? unpkgName = null;
                    if (parameters.HasValue)
                    {
                        if (parameters.Value.TryGetProperty("package_name", out var unpkgProp) ||
                            parameters.Value.TryGetProperty("package", out unpkgProp))
                        {
                            unpkgName = unpkgProp.GetString();
                        }
                    }
                    if (!string.IsNullOrEmpty(unpkgName))
                    {
                        _configService.Current.BlockedProcesses.Remove(unpkgName);
                        _configService.Save(_configService.Current);
                    }
                    return (true, null);

                default:
                    return (true, null);
            }
        }
    }
}
