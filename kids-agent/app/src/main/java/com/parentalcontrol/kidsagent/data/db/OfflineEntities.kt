package com.parentalcontrol.kidsagent.data.db

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey
import com.parentalcontrol.kidsagent.data.model.KidCallLogItem
import com.parentalcontrol.kidsagent.data.model.LocationPayload
import com.parentalcontrol.kidsagent.data.model.RiskAlertPayload

@Entity(tableName = "offline_locations")
data class OfflineLocationEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val latitude: Double,
    val longitude: Double,
    val accuracy: Float,
    val altitude: Double,
    val speed: Float,
    val bearing: Float,
    val timestamp: Long,
    @ColumnInfo(name = "is_synced")
    val isSynced: Boolean = false
) {
    fun toPayload() = LocationPayload(
        latitude = latitude,
        longitude = longitude,
        accuracy = accuracy,
        altitude = altitude,
        speed = speed,
        bearing = bearing,
        timestamp = timestamp
    )

    companion object {
        fun fromPayload(payload: LocationPayload, isSynced: Boolean = false) = OfflineLocationEntity(
            latitude = payload.latitude,
            longitude = payload.longitude,
            accuracy = payload.accuracy,
            altitude = payload.altitude,
            speed = payload.speed,
            bearing = payload.bearing,
            timestamp = payload.timestamp,
            isSynced = isSynced
        )
    }
}

@Entity(tableName = "offline_call_logs")
data class OfflineCallLogEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val number: String,
    val name: String?,
    @ColumnInfo(name = "call_type")
    val callType: String,
    @ColumnInfo(name = "duration_seconds")
    val durationSeconds: Int,
    val timestamp: Long,
    @ColumnInfo(name = "is_synced")
    val isSynced: Boolean = false
) {
    fun toPayload() = KidCallLogItem(
        number = number,
        name = name,
        callType = callType,
        durationSeconds = durationSeconds,
        timestamp = timestamp
    )

    companion object {
        fun fromPayload(item: KidCallLogItem, isSynced: Boolean = false) = OfflineCallLogEntity(
            number = item.number,
            name = item.name,
            callType = item.callType,
            durationSeconds = item.durationSeconds,
            timestamp = item.timestamp,
            isSynced = isSynced
        )
    }
}

@Entity(tableName = "offline_risk_alerts")
data class OfflineRiskAlertEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val category: String,
    val severity: String,
    val snippet: String,
    val source: String,
    @ColumnInfo(name = "matched_reason", defaultValue = "''")
    val matchedReason: String = "",
    val timestamp: Long,
    @ColumnInfo(name = "is_synced")
    val isSynced: Boolean = false
) {
    fun toPayload() = RiskAlertPayload(
        category = category,
        severity = severity,
        snippet = snippet,
        source = source,
        matchedReason = matchedReason,
        timestamp = timestamp
    )

    companion object {
        fun fromPayload(alert: RiskAlertPayload, isSynced: Boolean = false) = OfflineRiskAlertEntity(
            category = alert.category,
            severity = alert.severity,
            snippet = alert.snippet,
            source = alert.source,
            matchedReason = alert.matchedReason,
            timestamp = alert.timestamp,
            isSynced = isSynced
        )
    }
}
