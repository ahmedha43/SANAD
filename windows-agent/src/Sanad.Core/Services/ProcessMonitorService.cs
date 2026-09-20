using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Sanad.Core.Models;

namespace Sanad.Core.Services
{
    public class ProcessMonitorService
    {
        [DllImport("user32.dll")]
        private static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);

        private readonly ConfigService _configService;
        private CancellationTokenSource? _cts;

        public string ActiveWindowTitle { get; private set; } = string.Empty;
        public event Action<string>? OnBlockedProcessKilled;

        public ProcessMonitorService(ConfigService configService)
        {
            _configService = configService;
        }

        public void Start()
        {
            Stop();
            _cts = new CancellationTokenSource();
            Task.Run(() => MonitorLoopAsync(_cts.Token));
        }

        public void Stop()
        {
            _cts?.Cancel();
            _cts = null;
        }

        private async Task MonitorLoopAsync(CancellationToken token)
        {
            while (!token.IsCancellationRequested)
            {
                try
                {
                    // 1. Update Active Window
                    UpdateActiveWindow();

                    // 2. Kill Blocked Processes if monitoring is not paused
                    var cfg = _configService.Current;
                    if (!cfg.IsMonitoringPaused && cfg.BlockedProcesses.Count > 0)
                    {
                        CheckAndKillBlockedProcesses(cfg);
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[ProcessMonitor] Error: {ex.Message}");
                }

                await Task.Delay(2000, token);
            }
        }

        private void UpdateActiveWindow()
        {
            try
            {
                var handle = GetForegroundWindow();
                if (handle != IntPtr.Zero)
                {
                    var sb = new StringBuilder(256);
                    if (GetWindowText(handle, sb, sb.Capacity) > 0)
                    {
                        ActiveWindowTitle = sb.ToString();
                    }
                }
            }
            catch { }
        }

        private void CheckAndKillBlockedProcesses(AgentConfig cfg)
        {
            var processes = Process.GetProcesses();
            foreach (var proc in processes)
            {
                try
                {
                    var procName = proc.ProcessName.ToLowerInvariant();
                    foreach (var blocked in cfg.BlockedProcesses)
                    {
                        if (procName.Contains(blocked.ToLowerInvariant()))
                        {
                            proc.Kill(true);
                            Console.WriteLine($"[ProcessMonitor] Blocked and killed process: {proc.ProcessName}");
                            OnBlockedProcessKilled?.Invoke(proc.ProcessName);
                            break;
                        }
                    }
                }
                catch { }
            }
        }
    }
}
