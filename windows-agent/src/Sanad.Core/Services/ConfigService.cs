using System;
using System.IO;
using System.Text.Json;
using Sanad.Core.Models;

namespace Sanad.Core.Services
{
    public class ConfigService
    {
        private static readonly string ConfigDirectory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
            "SANAD"
        );
        private static readonly string ConfigFilePath = Path.Combine(ConfigDirectory, "config.json");

        private AgentConfig _currentConfig;
        public AgentConfig Current => _currentConfig;

        public event Action<AgentConfig>? OnConfigChanged;

        public ConfigService()
        {
            _currentConfig = Load();
        }

        public AgentConfig Load()
        {
            try
            {
                if (!Directory.Exists(ConfigDirectory))
                {
                    Directory.CreateDirectory(ConfigDirectory);
                }

                if (File.Exists(ConfigFilePath))
                {
                    var json = File.ReadAllText(ConfigFilePath);
                    var cfg = JsonSerializer.Deserialize<AgentConfig>(json);
                    if (cfg != null)
                    {
                        if (string.IsNullOrEmpty(cfg.DeviceUid))
                        {
                            cfg.DeviceUid = GetOrCreateDeviceUid();
                        }
                        if (!string.IsNullOrEmpty(cfg.ServerUrl))
                        {
                            cfg.ServerUrl = ApiClient.CleanUrl(cfg.ServerUrl);
                            var wsHost = cfg.ServerUrl.Replace("http://", "ws://").Replace("https://", "wss://");
                            cfg.WsUrl = $"{wsHost}/ws";
                        }
                        _currentConfig = cfg;
                        return _currentConfig;
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[ConfigService] Error reading config: {ex.Message}");
            }

            _currentConfig = new AgentConfig
            {
                DeviceUid = GetOrCreateDeviceUid()
            };
            Save(_currentConfig);
            return _currentConfig;
        }

        public void Save(AgentConfig config)
        {
            try
            {
                if (!Directory.Exists(ConfigDirectory))
                {
                    Directory.CreateDirectory(ConfigDirectory);
                }

                if (!string.IsNullOrEmpty(config.ServerUrl))
                {
                    config.ServerUrl = ApiClient.CleanUrl(config.ServerUrl);
                    var wsHost = config.ServerUrl.Replace("http://", "ws://").Replace("https://", "wss://");
                    config.WsUrl = $"{wsHost}/ws";
                }

                var options = new JsonSerializerOptions { WriteIndented = true };
                var json = JsonSerializer.Serialize(config, options);
                File.WriteAllText(ConfigFilePath, json);
                _currentConfig = config;
                OnConfigChanged?.Invoke(_currentConfig);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[ConfigService] Error saving config: {ex.Message}");
            }
        }

        private string GetOrCreateDeviceUid()
        {
            return "WIN-" + Guid.NewGuid().ToString("N").Substring(0, 16).ToUpper();
        }
    }
}
