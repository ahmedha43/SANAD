package com.parentalcontrol.kidsagent.data.model

import com.google.gson.JsonElement
import com.google.gson.annotations.SerializedName

data class WSMessage(
    @SerializedName("type") val type: String,
    @SerializedName("id") val id: String = java.util.UUID.randomUUID().toString(),
    @SerializedName("from") val from: String? = null,
    @SerializedName("to") val to: String? = null,
    @SerializedName("family_id") val familyId: String? = null,
    @SerializedName("timestamp") val timestamp: Long = System.currentTimeMillis(),
    @SerializedName("payload") val payload: JsonElement? = null
)

data class BatteryPayload(
    @SerializedName("battery_level") val batteryLevel: Int,
    @SerializedName("is_charging") val isCharging: Boolean,
    @SerializedName("network_type") val networkType: String
)

data class LocationPayload(
    @SerializedName("latitude") val latitude: Double,
    @SerializedName("longitude") val longitude: Double,
    @SerializedName("accuracy") val accuracy: Float,
    @SerializedName("altitude") val altitude: Double,
    @SerializedName("speed") val speed: Float,
    @SerializedName("bearing") val bearing: Float,
    @SerializedName("timestamp") val timestamp: Long = System.currentTimeMillis()
)

data class CommandRequest(
    @SerializedName("command_id") val commandId: String,
    @SerializedName("action") val action: String, // LOCK, UNLOCK, ALARM, BLOCK_APP
    @SerializedName("params") val params: Map<String, Any>? = null
)

data class CommandAck(
    @SerializedName("command_id") val commandId: String,
    @SerializedName("success") val success: Boolean,
    @SerializedName("error") val error: String? = null
)

data class AppItem(
    @SerializedName("package_name") val packageName: String,
    @SerializedName("app_name") val appName: String,
    @SerializedName("icon_url") val iconUrl: String? = null,
    @SerializedName("is_system_app") val isSystemApp: Boolean = false,
    @SerializedName("is_blocked") val isBlocked: Boolean = false
)

data class DailyUsageItem(
    @SerializedName("package_name") val packageName: String,
    @SerializedName("date") val date: String,
    @SerializedName("usage_duration_seconds") val usageDurationSeconds: Long,
    @SerializedName("open_count") val openCount: Int = 0
)

data class NotificationPayload(
    @SerializedName("app_name") val appName: String,
    @SerializedName("package_name") val packageName: String,
    @SerializedName("title") val title: String,
    @SerializedName("content") val content: String,
    @SerializedName("timestamp") val timestamp: Long = System.currentTimeMillis()
)

data class ScreenTimeRulePayload(
    @SerializedName("daily_limit_minutes") val dailyLimitMinutes: Int = 180,
    @SerializedName("downtime_start") val downtimeStart: String? = "21:00",
    @SerializedName("downtime_end") val downtimeEnd: String? = "07:00",
    @SerializedName("is_active") val isActive: Boolean = true
)

data class SOSAlertPayload(
    @SerializedName("latitude") val latitude: Double,
    @SerializedName("longitude") val longitude: Double,
    @SerializedName("battery_level") val batteryLevel: Int,
    @SerializedName("timestamp") val timestamp: Long = System.currentTimeMillis()
)

data class LowBatteryAlertPayload(
    @SerializedName("battery_level") val batteryLevel: Int,
    @SerializedName("is_charging") val isCharging: Boolean,
    @SerializedName("timestamp") val timestamp: Long = System.currentTimeMillis()
)

data class KidContactItem(
    @SerializedName("name") val name: String,
    @SerializedName("phone_number") val phoneNumber: String
)

data class KidSmsItem(
    @SerializedName("sender") val sender: String,
    @SerializedName("body") val body: String,
    @SerializedName("is_incoming") val isIncoming: Boolean = true,
    @SerializedName("timestamp") val timestamp: Long = System.currentTimeMillis()
)

data class KidFileItem(
    @SerializedName("file_name") val fileName: String,
    @SerializedName("file_path") val filePath: String,
    @SerializedName("file_size") val fileSize: Long,
    @SerializedName("mime_type") val mimeType: String,
    @SerializedName("thumbnail_base64") val thumbnailBase64: String? = null,
    @SerializedName("timestamp") val timestamp: Long = System.currentTimeMillis()
)

data class KidCallLogItem(
    @SerializedName("number") val number: String,
    @SerializedName("name") val name: String? = null,
    @SerializedName("call_type") val callType: String,
    @SerializedName("duration_seconds") val durationSeconds: Int = 0,
    @SerializedName("timestamp") val timestamp: Long = System.currentTimeMillis()
)

data class RiskAlertPayload(
    @SerializedName("category") val category: String,
    @SerializedName("severity") val severity: String,
    @SerializedName("snippet") val snippet: String,
    @SerializedName("source") val source: String,
    @SerializedName("matched_reason") val matchedReason: String = "",
    @SerializedName("is_safe") val isSafe: Boolean = false,
    @SerializedName("timestamp") val timestamp: Long = System.currentTimeMillis()
)

data class ScreenshotPayload(
    @SerializedName("image_base64") val imageBase64: String? = null,
    @SerializedName("error") val error: String? = null,
    @SerializedName("timestamp") val timestamp: Long = System.currentTimeMillis()
)

data class FileDataResultPayload(
    @SerializedName("file_path") val filePath: String,
    @SerializedName("file_base64") val fileBase64: String?,
    @SerializedName("file_name") val fileName: String? = null,
    @SerializedName("file_size") val fileSize: Long = 0L,
    @SerializedName("mime_type") val mimeType: String? = null,
    @SerializedName("error") val error: String? = null
)

data class FetchFileDataPayload(
    @SerializedName("file_path") val filePath: String
)

data class FileExplorerItem(
    @SerializedName("name") val name: String,
    @SerializedName("path") val path: String,
    @SerializedName("is_directory") val isDirectory: Boolean,
    @SerializedName("size") val size: Long = 0L,
    @SerializedName("last_modified") val lastModified: Long = 0L,
    @SerializedName("extension") val extension: String = "",
    @SerializedName("mime_type") val mimeType: String = ""
)

data class DirectoryListResultPayload(
    @SerializedName("current_path") val currentPath: String,
    @SerializedName("parent_path") val parentPath: String?,
    @SerializedName("items") val items: List<FileExplorerItem>,
    @SerializedName("error") val error: String? = null
)

