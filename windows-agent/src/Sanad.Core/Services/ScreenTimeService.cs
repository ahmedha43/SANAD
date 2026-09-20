using System;
using System.Net.Http;
using System.Net.Http.Json;
using System.Text.Json.Serialization;
using System.Threading;
using System.Threading.Tasks;
using Sanad.Core.Models;

namespace Sanad.Core.Services
{
    public class ScreenTimeService
    {
        private readonly ConfigService _configService;
        private readonly HttpClient _httpClient;
        private CancellationTokenSource? _cts;

        public event Action<string>? OnScreenTimeLimitExceeded;
        public event Action? OnScreenTimeAllowed;

        public ScreenTimeRuleModel? CurrentRule { get; private set; }
        public int TotalActiveMinutesToday { get; set; } = 0;
        private bool _isCurrentlyLockedByRule = false;

        public ScreenTimeService(ConfigService configService)
        {
            _configService = configService;
            _httpClient = new HttpClient { Timeout = TimeSpan.FromSeconds(10) };
        }

        public void Start()
        {
            Stop();
            _cts = new CancellationTokenSource();
            Task.Run(() => ScreenTimeLoopAsync(_cts.Token));
        }

        public void Stop()
        {
            _cts?.Cancel();
            _cts = null;
        }

        public void UpdateRule(ScreenTimeRuleModel rule)
        {
            CurrentRule = rule;
            Log($"[ScreenTime] Updated rule: DailyLimit={rule.DailyLimitMinutes}m, Downtime={rule.DowntimeStart}-{rule.DowntimeEnd}, Active={rule.IsActive}");
        }

        private async Task ScreenTimeLoopAsync(CancellationToken token)
        {
            // Initial delay
            await Task.Delay(5000, token);

            while (!token.IsCancellationRequested)
            {
                try
                {
                    var cfg = _configService.Current;
                    if (cfg.IsPaired && !string.IsNullOrEmpty(cfg.DeviceId))
                    {
                        // 1. Periodically fetch latest rule from backend
                        await FetchRuleFromServerAsync(cfg, token);

                        // 2. Evaluate rule against current time
                        EvaluateRule();
                    }
                }
                catch { }

                try
                {
                    await Task.Delay(30000, token); // Check every 30 seconds
                }
                catch (OperationCanceledException)
                {
                    break;
                }
            }
        }

        private async Task FetchRuleFromServerAsync(AgentConfig cfg, CancellationToken token)
        {
            try
            {
                var url = $"{cfg.ServerUrl}/api/v1/devices/{cfg.DeviceId}/screen-time-rules";
                var rule = await _httpClient.GetFromJsonAsync<ScreenTimeRuleModel>(url, token);
                if (rule != null)
                {
                    CurrentRule = rule;
                }
            }
            catch { }
        }

        private void EvaluateRule()
        {
            if (CurrentRule == null || !CurrentRule.IsActive)
            {
                if (_isCurrentlyLockedByRule)
                {
                    _isCurrentlyLockedByRule = false;
                    OnScreenTimeAllowed?.Invoke();
                }
                return;
            }

            var now = DateTime.Now;
            var currentTimeStr = now.ToString("HH:mm");

            // 1. Check Downtime / Bedtime schedule
            if (!string.IsNullOrEmpty(CurrentRule.DowntimeStart) && !string.IsNullOrEmpty(CurrentRule.DowntimeEnd))
            {
                bool isInDowntime = IsInTimeRange(currentTimeStr, CurrentRule.DowntimeStart, CurrentRule.DowntimeEnd);
                if (isInDowntime)
                {
                    if (!_isCurrentlyLockedByRule)
                    {
                        _isCurrentlyLockedByRule = true;
                        Log($"[ScreenTime] Bedtime downtime active ({CurrentRule.DowntimeStart} to {CurrentRule.DowntimeEnd}). Locking screen.");
                        OnScreenTimeLimitExceeded?.Invoke("حان موعد النوم! تم قفل الكمبيوتر للمحافظة على راحتك ونومك الهانئ.");
                    }
                    return;
                }
            }

            // 2. Check Daily Limit
            if (CurrentRule.DailyLimitMinutes > 0 && TotalActiveMinutesToday >= CurrentRule.DailyLimitMinutes)
            {
                if (!_isCurrentlyLockedByRule)
                {
                    _isCurrentlyLockedByRule = true;
                    Log($"[ScreenTime] Daily limit reached ({TotalActiveMinutesToday}/{CurrentRule.DailyLimitMinutes}m). Locking screen.");
                    OnScreenTimeLimitExceeded?.Invoke("انتهى وقت الشاشة المسموح به لهذا اليوم! يرجى أخذ قسط من الراحة.");
                }
                return;
            }

            // If previously locked by rule and now allowed
            if (_isCurrentlyLockedByRule)
            {
                _isCurrentlyLockedByRule = false;
                Log("[ScreenTime] Downtime/Limit ended. Unlocking screen.");
                OnScreenTimeAllowed?.Invoke();
            }
        }

        private bool IsInTimeRange(string current, string start, string end)
        {
            if (TimeSpan.TryParse(current, out var curTs) &&
                TimeSpan.TryParse(start, out var startTs) &&
                TimeSpan.TryParse(end, out var endTs))
            {
                if (startTs <= endTs)
                {
                    return curTs >= startTs && curTs <= endTs;
                }
                else
                {
                    // Overnight range, e.g. 21:00 to 07:00
                    return curTs >= startTs || curTs <= endTs;
                }
            }
            return false;
        }

        private void Log(string message)
        {
            var logPath = System.IO.Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "debug_log.txt");
            try { System.IO.File.AppendAllText(logPath, $"{DateTime.Now}: {message}\n"); } catch { }
            Console.WriteLine(message);
        }
    }

    public class ScreenTimeRuleModel
    {
        [JsonPropertyName("id")]
        public string? Id { get; set; }

        [JsonPropertyName("daily_limit_minutes")]
        public int DailyLimitMinutes { get; set; }

        [JsonPropertyName("downtime_start")]
        public string? DowntimeStart { get; set; }

        [JsonPropertyName("downtime_end")]
        public string? DowntimeEnd { get; set; }

        [JsonPropertyName("is_active")]
        public bool IsActive { get; set; } = true;
    }
}
