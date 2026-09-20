using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using Sanad.Core.Models;

namespace Sanad.Core.Services
{
    public class RiskDetectionService
    {
        [DllImport("user32.dll")]
        private static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll", SetLastError = true)]
        private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);

        private readonly ConfigService _configService;
        private CancellationTokenSource? _cts;
        private string _lastAnalyzedText = string.Empty;

        public event Func<string, string, string, string, Task>? OnRiskDetected;

        // Default safety risk patterns
        private readonly List<string> _riskKeywords = new()
        {
            "suicide", "kill myself", "انتحار", "قتل نفسي",
            "self harm", "hurt myself", "إيذاء النفس",
            "porn", "xxx", "sex", "اباحي", "جنس", "موقع اباحي",
            "hate", "bullying", "تنمر", "شتيمة",
            "drugs", "weed", "مخدرات", "حشيش"
        };

        private readonly HashSet<string> _whitelistedPatterns = new(StringComparer.OrdinalIgnoreCase);

        public RiskDetectionService(ConfigService configService)
        {
            _configService = configService;
        }

        public void Start()
        {
            Stop();
            _cts = new CancellationTokenSource();
            Task.Run(() => MonitoringLoopAsync(_cts.Token));
        }

        public void Stop()
        {
            _cts?.Cancel();
            _cts = null;
        }

        public void UpdateWhitelistedPatterns(IEnumerable<string> patterns)
        {
            _whitelistedPatterns.Clear();
            foreach (var p in patterns)
            {
                _whitelistedPatterns.Add(p.Trim());
            }
        }

        private string? _lastAnalyzedClipboard;

        private async Task MonitoringLoopAsync(CancellationToken token)
        {
            while (!token.IsCancellationRequested)
            {
                try
                {
                    CheckActiveWindowForRisks();
                    CheckClipboardForRisks();
                }
                catch { }

                try
                {
                    await Task.Delay(3000, token);
                }
                catch (OperationCanceledException)
                {
                    break;
                }
            }
        }

        private void CheckClipboardForRisks()
        {
            string? clipText = null;
            var t = new Thread(() =>
            {
                try
                {
                    if (Clipboard.ContainsText())
                    {
                        clipText = Clipboard.GetText();
                    }
                }
                catch { }
            });
            t.SetApartmentState(ApartmentState.STA);
            t.Start();
            t.Join(300);

            if (string.IsNullOrWhiteSpace(clipText) || clipText == _lastAnalyzedClipboard) return;
            _lastAnalyzedClipboard = clipText;

            AnalyzeContent(clipText, "Clipboard", "Clipboard Monitor");
        }

        private void CheckActiveWindowForRisks()
        {
            var hwnd = GetForegroundWindow();
            if (hwnd == IntPtr.Zero) return;

            var sb = new System.Text.StringBuilder(256);
            if (GetWindowText(hwnd, sb, 256) <= 0) return;

            var title = sb.ToString().Trim();
            if (string.IsNullOrEmpty(title) || title == _lastAnalyzedText) return;

            _lastAnalyzedText = title;

            GetWindowThreadProcessId(hwnd, out var pid);
            string appName = "Desktop";
            try
            {
                var proc = Process.GetProcessById((int)pid);
                appName = proc.ProcessName;
            }
            catch { }

            AnalyzeContent(title, appName, $"Window: '{title}'");
        }

        private void AnalyzeContent(string content, string sourceApp, string contextDescription)
        {
            var contentLower = content.ToLowerInvariant();

            foreach (var kw in _riskKeywords)
            {
                if (contentLower.Contains(kw.ToLowerInvariant()))
                {
                    if (_whitelistedPatterns.Any(w => contentLower.Contains(w.ToLowerInvariant())))
                    {
                        continue;
                    }

                    Log($"[RiskDetection] Risk keyword detected: '{kw}' in {contextDescription} (App: {sourceApp})");

                    string riskType = "SAFETY_ALERT";
                    string severity = "HIGH";

                    if (kw.Contains("porn") || kw.Contains("sex") || kw.Contains("اباحي") || kw.Contains("xxx"))
                    {
                        riskType = "ADULT_CONTENT";
                    }
                    else if (kw.Contains("suicide") || kw.Contains("انتحار") || kw.Contains("ازهاق"))
                    {
                        riskType = "SELF_HARM";
                        severity = "CRITICAL";
                    }
                    else if (kw.Contains("blood") || kw.Contains("die") || kw.Contains("قتل"))
                    {
                        riskType = "VIOLENCE";
                    }

                    _ = Task.Run(async () =>
                    {
                        if (OnRiskDetected != null)
                        {
                            await OnRiskDetected(riskType, kw, sourceApp, severity);
                        }
                    });

                    break;
                }
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
