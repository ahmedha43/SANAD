package com.parentalcontrol.kidsagent.sync

import android.content.Context
import android.util.Log
import androidx.work.*
import com.google.gson.Gson
import com.parentalcontrol.kidsagent.KidsAgentApp
import com.parentalcontrol.kidsagent.data.db.AppDatabase
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

class OfflineSyncWorker(
    appContext: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {

    companion object {
        private const val TAG = "OfflineSyncWorker"
        private const val WORK_NAME_ONE_TIME = "OfflineSyncWork_OneTime"
        private const val WORK_NAME_PERIODIC = "OfflineSyncWork_Periodic"

        fun enqueue(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val request = OneTimeWorkRequestBuilder<OfflineSyncWorker>()
                .setConstraints(constraints)
                .setBackoffCriteria(
                    BackoffPolicy.EXPONENTIAL,
                    30,
                    TimeUnit.SECONDS
                )
                .build()

            WorkManager.getInstance(context).enqueueUniqueWork(
                WORK_NAME_ONE_TIME,
                ExistingWorkPolicy.REPLACE,
                request
            )
            Log.d(TAG, "OfflineSyncWorker one-time job enqueued")
        }

        fun schedulePeriodic(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val periodicRequest = PeriodicWorkRequestBuilder<OfflineSyncWorker>(
                15, TimeUnit.MINUTES,
                5, TimeUnit.MINUTES
            )
                .setConstraints(constraints)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME_PERIODIC,
                ExistingPeriodicWorkPolicy.KEEP,
                periodicRequest
            )
            Log.d(TAG, "OfflineSyncWorker periodic job scheduled (15 min interval)")
        }
    }

    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()

    private val gson = Gson()

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        val app = KidsAgentApp.instance
        val deviceId = app.prefs.getString(KidsAgentApp.KEY_DEVICE_ID, null)
        val serverUrl = app.prefs.getString(KidsAgentApp.KEY_SERVER_URL, null)

        if (deviceId.isNullOrEmpty() || serverUrl.isNullOrEmpty()) {
            Log.w(TAG, "Device not paired yet; skipping offline sync")
            return@withContext Result.success()
        }

        val db = AppDatabase.getInstance(applicationContext)
        val locDao = db.locationDao()
        val callDao = db.callLogDao()
        val riskDao = db.riskAlertDao()

        val pendingLocations = locDao.getPendingLocations(200)
        val pendingCalls = callDao.getPendingCallLogs(100)
        val pendingRisks = riskDao.getPendingRiskAlerts(100)

        if (pendingLocations.isEmpty() && pendingCalls.isEmpty() && pendingRisks.isEmpty()) {
            Log.d(TAG, "No pending offline records to sync.")
            return@withContext Result.success()
        }

        Log.i(
            TAG,
            "Starting offline batch sync: ${pendingLocations.size} locations, " +
                    "${pendingCalls.size} calls, ${pendingRisks.size} risks"
        )

        val payload = mapOf(
            "locations" to pendingLocations.map { it.toPayload() },
            "calls" to pendingCalls.map { it.toPayload() },
            "risk_alerts" to pendingRisks.map { it.toPayload() }
        )

        val jsonBody = gson.toJson(payload)
        val requestBody = jsonBody.toRequestBody("application/json; charset=utf-8".toMediaType())

        val request = Request.Builder()
            .url("$serverUrl/api/v1/devices/$deviceId/sync/offline")
            .post(requestBody)
            .build()

        try {
            val response = httpClient.newCall(request).execute()
            if (response.isSuccessful) {
                val respStr = response.body?.string() ?: ""
                Log.i(TAG, "Batch offline sync succeeded! Server response: $respStr")

                // Mark items as synced in Room
                if (pendingLocations.isNotEmpty()) {
                    locDao.markLocationsSynced(pendingLocations.map { it.id })
                }
                if (pendingCalls.isNotEmpty()) {
                    callDao.markCallLogsSynced(pendingCalls.map { it.id })
                }
                if (pendingRisks.isNotEmpty()) {
                    riskDao.markRiskAlertsSynced(pendingRisks.map { it.id })
                }

                // Purge old synced records (older than 7 days)
                val sevenDaysAgo = System.currentTimeMillis() - (7 * 24 * 60 * 60 * 1000L)
                locDao.purgeOldSyncedLocations(sevenDaysAgo)
                callDao.purgeOldSyncedCallLogs(sevenDaysAgo)
                riskDao.purgeOldSyncedRiskAlerts(sevenDaysAgo)

                // If there were more than 200 locations, enqueue another round
                if (pendingLocations.size >= 200) {
                    enqueue(applicationContext)
                }

                Result.success()
            } else {
                Log.e(TAG, "Batch sync failed with HTTP ${response.code}: ${response.message}")
                Result.retry()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Network exception during offline batch sync: ${e.message}")
            Result.retry()
        }
    }
}
