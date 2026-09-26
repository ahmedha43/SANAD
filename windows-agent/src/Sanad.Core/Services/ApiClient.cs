using System;
using System.Net.Http;
using System.Net.Http.Json;
using System.Threading.Tasks;
using Sanad.Core.Models;

namespace Sanad.Core.Services
{
    public class ApiClient
    {
        private readonly HttpClient _httpClient;
        private readonly ConfigService _configService;

        public ApiClient(ConfigService configService)
        {
            _configService = configService;
            _httpClient = new HttpClient
            {
                Timeout = TimeSpan.FromSeconds(15)
            };
        }

        public static string CleanUrl(string? url)
        {
            if (string.IsNullOrWhiteSpace(url)) return "http://192.168.88.54:8080";

            var sb = new System.Text.StringBuilder();
            foreach (char c in url.Trim())
            {
                // Only keep printable ASCII characters (strip BOM, LRM, RLM, zero-width chars)
                if (c >= 0x21 && c <= 0x7E)
                {
                    sb.Append(c);
                }
            }

            var clean = sb.ToString().TrimEnd('/');
            if (!clean.StartsWith("http://", StringComparison.OrdinalIgnoreCase) &&
                !clean.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
            {
                clean = "http://" + clean;
            }
            return clean;
        }

        public static string NormalizeDigits(string? input)
        {
            if (string.IsNullOrWhiteSpace(input)) return string.Empty;

            var sb = new System.Text.StringBuilder();
            foreach (char c in input)
            {
                if (c >= '0' && c <= '9')
                {
                    sb.Append(c);
                }
                else if (c >= '\u0660' && c <= '\u0669') // Arabic-Indic digits ٠-٩
                {
                    sb.Append((char)('0' + (c - '\u0660')));
                }
                else if (c >= '\u06F0' && c <= '\u06F9') // Eastern Arabic-Indic digits ۰-۹
                {
                    sb.Append((char)('0' + (c - '\u06F0')));
                }
            }
            return sb.ToString();
        }

        public async Task<(bool success, string message)> PairDeviceAsync(string code, string? customServerUrl = null)
        {
            try
            {
                var cleanCode = NormalizeDigits(code);
                if (string.IsNullOrEmpty(cleanCode) || cleanCode.Length < 4)
                {
                    return (false, "يرجى إدخال كود اقتران صالح مكون من 6 أرقام");
                }

                var cfg = _configService.Current;
                if (!string.IsNullOrWhiteSpace(customServerUrl))
                {
                    cfg.ServerUrl = CleanUrl(customServerUrl);
                    var wsHost = cfg.ServerUrl.Replace("http://", "ws://").Replace("https://", "wss://");
                    cfg.WsUrl = $"{wsHost}/ws";
                }
                else
                {
                    cfg.ServerUrl = CleanUrl(cfg.ServerUrl);
                    var wsHost = cfg.ServerUrl.Replace("http://", "ws://").Replace("https://", "wss://");
                    cfg.WsUrl = $"{wsHost}/ws";
                }

                var pairUrl = $"{cfg.ServerUrl}/api/v1/devices/pair";
                var req = new PairDeviceRequest
                {
                    Code = cleanCode,
                    DeviceUid = cfg.DeviceUid,
                    DeviceName = cfg.DeviceName,
                    Model = cfg.Model,
                    OSVersion = cfg.OSVersion,
                    AppVersion = cfg.AppVersion,
                    OSType = "windows",
                    FCMToken = string.Empty
                };

                var response = await _httpClient.PostAsJsonAsync(pairUrl, req);
                if (!response.IsSuccessStatusCode)
                {
                    var err = await response.Content.ReadAsStringAsync();
                    return (false, $"فشل الاقتران ({response.StatusCode}): {err}");
                }

                var pairResp = await response.Content.ReadFromJsonAsync<PairDeviceResponse>();
                if (pairResp == null || string.IsNullOrEmpty(pairResp.DeviceId) || string.IsNullOrEmpty(pairResp.PairingSecret))
                {
                    return (false, "استجابة السيرفر غير صالحة");
                }

                cfg.DeviceId = pairResp.DeviceId;
                cfg.PairingSecret = pairResp.PairingSecret;
                cfg.FamilyId = pairResp.FamilyId;
                cfg.ChildId = pairResp.ChildId;

                _configService.Save(cfg);
                return (true, "تم إقران هذا الكمبيوتر بنجاح بمنظومة سَنَد!");
            }
            catch (Exception ex)
            {
                return (false, $"خطأ في الاتصال بالسيرفر: {ex.Message}");
            }
        }
    }
}
