using System;
using System.Text.Json.Serialization;

namespace Sanad.Core.Models
{
    public class PairDeviceRequest
    {
        [JsonPropertyName("code")]
        public string Code { get; set; } = string.Empty;

        [JsonPropertyName("device_uid")]
        public string DeviceUid { get; set; } = string.Empty;

        [JsonPropertyName("device_name")]
        public string DeviceName { get; set; } = string.Empty;

        [JsonPropertyName("model")]
        public string Model { get; set; } = string.Empty;

        [JsonPropertyName("os_version")]
        public string OSVersion { get; set; } = string.Empty;

        [JsonPropertyName("app_version")]
        public string AppVersion { get; set; } = string.Empty;

        [JsonPropertyName("fcm_token")]
        public string FCMToken { get; set; } = string.Empty;

        [JsonPropertyName("os_type")]
        public string OSType { get; set; } = "windows";
    }

    public class PairDeviceResponse
    {
        [JsonPropertyName("device_id")]
        public string DeviceId { get; set; } = string.Empty;

        [JsonPropertyName("family_id")]
        public string FamilyId { get; set; } = string.Empty;

        [JsonPropertyName("child_id")]
        public string ChildId { get; set; } = string.Empty;

        [JsonPropertyName("pairing_secret")]
        public string PairingSecret { get; set; } = string.Empty;

        [JsonPropertyName("server_time")]
        public long ServerTime { get; set; }
    }

    public class WsMessage
    {
        [JsonPropertyName("type")]
        public string Type { get; set; } = string.Empty;

        [JsonPropertyName("payload")]
        public object? Payload { get; set; }
    }

    public class CommandRequestPayload
    {
        [JsonPropertyName("command_id")]
        public string CommandId { get; set; } = string.Empty;

        [JsonPropertyName("action")]
        public string Action { get; set; } = string.Empty;

        [JsonPropertyName("params")]
        public System.Text.Json.JsonElement? Params { get; set; }
    }

    public class CommandAckPayload
    {
        [JsonPropertyName("command_id")]
        public string CommandId { get; set; } = string.Empty;

        [JsonPropertyName("success")]
        public bool Success { get; set; }

        [JsonPropertyName("error")]
        public string? Error { get; set; }
    }

    public class HeartbeatPayload
    {
        [JsonPropertyName("device_id")]
        public string DeviceId { get; set; } = string.Empty;

        [JsonPropertyName("battery_level")]
        public int BatteryLevel { get; set; } = 100;

        [JsonPropertyName("is_charging")]
        public bool IsCharging { get; set; } = true;

        [JsonPropertyName("network_type")]
        public string NetworkType { get; set; } = "Ethernet/Wi-Fi";

        [JsonPropertyName("active_app")]
        public string ActiveApp { get; set; } = string.Empty;

        [JsonPropertyName("status")]
        public string Status { get; set; } = "online";
    }
}
