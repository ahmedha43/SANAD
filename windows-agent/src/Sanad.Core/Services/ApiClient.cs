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

        public async Task<(bool success, string message)> PairDeviceAsync(string code, string? customServerUrl = null)
        {
            try
            {
                var cfg = _configService.Current;
                if (!string.IsNullOrEmpty(customServerUrl))
                {
                    cfg.ServerUrl = customServerUrl.TrimEnd('/');
                    var wsHost = cfg.ServerUrl.Replace("http://", "ws://").Replace("https://", "wss://");
                    cfg.WsUrl = $"{wsHost}/ws";
                }

                var pairUrl = $"{cfg.ServerUrl}/api/v1/devices/pair";
                var req = new PairDeviceRequest
                {
                    Code = code.Trim(),
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
