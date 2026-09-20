using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using Sanad.Core.Models;

namespace Sanad.Core.Services
{
    public class WebFilterService
    {
        private static readonly string HostsFilePath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.System),
            "drivers", "etc", "hosts"
        );

        private const string SanadHostsHeader = "# --- SANAD WEB FILTER START ---";
        private const string SanadHostsFooter = "# --- SANAD WEB FILTER END ---";

        private readonly ConfigService _configService;
        private readonly List<string> _blockedDomains = new();
        private bool _safeSearchEnabled = true;

        public WebFilterService(ConfigService configService)
        {
            _configService = configService;
            _blockedDomains.AddRange(_configService.Current.BlockedDomains);
        }

        public void ApplyFilter(List<string> blockedDomains, bool enableSafeSearch = true)
        {
            _blockedDomains.Clear();
            _blockedDomains.AddRange(blockedDomains.Distinct(StringComparer.OrdinalIgnoreCase));
            _safeSearchEnabled = enableSafeSearch;

            _configService.Current.BlockedDomains = new List<string>(_blockedDomains);
            _configService.Save(_configService.Current);

            ApplyToHostsFile();
        }

        public void AddBlockedDomain(string domain)
        {
            var clean = domain.Trim().ToLowerInvariant();
            if (!string.IsNullOrEmpty(clean) && !_blockedDomains.Contains(clean))
            {
                _blockedDomains.Add(clean);
                _configService.Current.BlockedDomains = new List<string>(_blockedDomains);
                _configService.Save(_configService.Current);
                ApplyToHostsFile();
            }
        }

        public void RemoveBlockedDomain(string domain)
        {
            var clean = domain.Trim().ToLowerInvariant();
            if (_blockedDomains.Remove(clean))
            {
                _configService.Current.BlockedDomains = new List<string>(_blockedDomains);
                _configService.Save(_configService.Current);
                ApplyToHostsFile();
            }
        }

        private void ApplyToHostsFile()
        {
            try
            {
                if (!File.Exists(HostsFilePath)) return;

                var lines = File.ReadAllLines(HostsFilePath).ToList();

                // Remove existing SANAD block
                int startIdx = lines.FindIndex(l => l.Contains(SanadHostsHeader));
                int endIdx = lines.FindIndex(l => l.Contains(SanadHostsFooter));

                if (startIdx >= 0 && endIdx >= startIdx)
                {
                    lines.RemoveRange(startIdx, endIdx - startIdx + 1);
                }

                // Add new SANAD rules
                var newRules = new List<string>
                {
                    SanadHostsHeader
                };

                // 1. Blocked domains
                foreach (var domain in _blockedDomains)
                {
                    newRules.Add($"127.0.0.1 {domain}");
                    newRules.Add($"127.0.0.1 www.{domain}");
                }

                // 2. SafeSearch VIP redirects (Google, Bing)
                if (_safeSearchEnabled)
                {
                    // forcesafesearch.google.com = 216.239.38.120
                    newRules.Add("216.239.38.120 www.google.com");
                    newRules.Add("216.239.38.120 google.com");
                    // strict.bing.com = 204.79.197.220
                    newRules.Add("204.79.197.220 www.bing.com");
                    newRules.Add("204.79.197.220 bing.com");
                }

                newRules.Add(SanadHostsFooter);
                lines.AddRange(newRules);

                File.WriteAllLines(HostsFilePath, lines, Encoding.UTF8);
                Log($"[WebFilter] Applied {_blockedDomains.Count} blocked domains and SafeSearch to hosts file.");
            }
            catch (Exception ex)
            {
                Log($"[WebFilter] Error updating hosts file (requires Admin): {ex.Message}");
            }
        }

        private void Log(string message)
        {
            var logPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "debug_log.txt");
            try { File.AppendAllText(logPath, $"{DateTime.Now}: {message}\n"); } catch { }
            Console.WriteLine(message);
        }
    }
}
