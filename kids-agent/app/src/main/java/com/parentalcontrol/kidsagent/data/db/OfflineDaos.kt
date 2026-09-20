package com.parentalcontrol.kidsagent.data.db

import androidx.room.*

@Dao
interface OfflineLocationDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertLocation(location: OfflineLocationEntity): Long

    @Query("SELECT * FROM offline_locations WHERE is_synced = 0 ORDER BY timestamp ASC LIMIT :limit")
    suspend fun getPendingLocations(limit: Int = 200): List<OfflineLocationEntity>

    @Query("UPDATE offline_locations SET is_synced = 1 WHERE id IN (:ids)")
    suspend fun markLocationsSynced(ids: List<Long>)

    @Query("DELETE FROM offline_locations WHERE is_synced = 1 AND timestamp < :olderThan")
    suspend fun purgeOldSyncedLocations(olderThan: Long)

    @Query("SELECT COUNT(*) FROM offline_locations WHERE is_synced = 0")
    suspend fun getPendingLocationsCount(): Int
}

@Dao
interface OfflineCallLogDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertCallLogs(calls: List<OfflineCallLogEntity>)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertCall(call: OfflineCallLogEntity): Long

    @Query("SELECT * FROM offline_call_logs WHERE is_synced = 0 ORDER BY timestamp ASC LIMIT :limit")
    suspend fun getPendingCallLogs(limit: Int = 100): List<OfflineCallLogEntity>

    @Query("UPDATE offline_call_logs SET is_synced = 1 WHERE id IN (:ids)")
    suspend fun markCallLogsSynced(ids: List<Long>)

    @Query("DELETE FROM offline_call_logs WHERE is_synced = 1 AND timestamp < :olderThan")
    suspend fun purgeOldSyncedCallLogs(olderThan: Long)
}

@Dao
interface OfflineRiskAlertDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertRiskAlert(alert: OfflineRiskAlertEntity): Long

    @Query("SELECT * FROM offline_risk_alerts WHERE is_synced = 0 ORDER BY timestamp ASC LIMIT :limit")
    suspend fun getPendingRiskAlerts(limit: Int = 100): List<OfflineRiskAlertEntity>

    @Query("UPDATE offline_risk_alerts SET is_synced = 1 WHERE id IN (:ids)")
    suspend fun markRiskAlertsSynced(ids: List<Long>)

    @Query("DELETE FROM offline_risk_alerts WHERE is_synced = 1 AND timestamp < :olderThan")
    suspend fun purgeOldSyncedRiskAlerts(olderThan: Long)
}
