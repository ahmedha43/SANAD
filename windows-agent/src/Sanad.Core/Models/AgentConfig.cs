using System;
using System.Collections.Generic;

namespace Sanad.Core.Models
{
    public class AgentConfig
    {
        public string ServerUrl { get; set; } = "http://192.168.1.106:8080";
        public string WsUrl { get; set; } = "ws://192.168.1.106:8080/ws";
        public string DeviceUid { get; set; } = string.Empty;
        public string DeviceName { get; set; } = Environment.MachineName;
        public string Model { get; set; } = "Windows PC";
        public string OSVersion { get; set; } = Environment.OSVersion.VersionString;
        public string AppVersion { get; set; } = "1.0.0-PRO";
        public string OSType { get; set; } = "windows";

        public string? DeviceId { get; set; }
        public string? PairingSecret { get; set; }
        public string? FamilyId { get; set; }
        public string? ChildId { get; set; }
        public bool IsPaired => !string.IsNullOrEmpty(DeviceId) && !string.IsNullOrEmpty(PairingSecret);

        public bool IsMonitoringPaused { get; set; } = false;
        public bool IsDeviceLocked { get; set; } = false;
        public List<string> BlockedProcesses { get; set; } = new()
        {
            "discord", "robloxplayerbeta", "steam", "epicgameslauncher", "torrent", "utorrent"
        };
        public List<string> BlockedDomains { get; set; } = new();
    }
}
