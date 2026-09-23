package com.parentalcontrol.kidsagent.service

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import com.google.gson.Gson
import com.parentalcontrol.kidsagent.KidsAgentApp
import com.parentalcontrol.kidsagent.data.db.AppDatabase
import com.parentalcontrol.kidsagent.data.db.OfflineRiskAlertEntity
import com.parentalcontrol.kidsagent.data.model.NotificationPayload
import com.parentalcontrol.kidsagent.sync.OfflineSyncWorker
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

class AgentNotificationListener : NotificationListenerService() {

    companion object {
        private const val TAG = "AgentNotifListener"
        var instance: AgentNotificationListener? = null
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        instance = this
        Log.i(TAG, "AgentNotificationListener connected")
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        if (instance == this) instance = null
        Log.i(TAG, "AgentNotificationListener disconnected")
    }

    private val httpClient = OkHttpClient()
    private val gson = Gson()
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        if (ForegroundSyncService.isMonitoringPaused) return

        val packageName = sbn.packageName ?: ""
        if (packageName == applicationContext.packageName) return // Ignore own notifications
        if (sbn.isOngoing) return // Ignore persistent ongoing notifications (e.g. charging, foreground services)
        if (packageName == "com.android.systemui") return // Ignore system UI noise

        val extras = sbn.notification.extras ?: return
        val title = extras.getCharSequence("android.title")?.toString()
            ?: extras.getCharSequence("android.title.big")?.toString()
            ?: ""
        val text = extras.getCharSequence("android.text")?.toString()
            ?: extras.getCharSequence("android.bigText")?.toString()
            ?: ""

        if (title.isNotEmpty() || text.isNotEmpty()) {
            val pm = packageManager
            val appName = try {
                val appInfo = pm.getApplicationInfo(packageName, 0)
                pm.getApplicationLabel(appInfo).toString()
            } catch (e: Exception) {
                packageName
            }

            val payload = NotificationPayload(
                appName = appName,
                packageName = packageName,
                title = title,
                content = text,
                timestamp = if (sbn.postTime > 0) sbn.postTime else System.currentTimeMillis()
            )

            Log.d(TAG, "Forwarding notification from $appName: $title - $text")

            // 1. Forward via ForegroundSyncService's primary WebSocket connection
            ForegroundSyncService.instance?.sendNotificationForward(payload)

            // 2. Immediate REST API fallback for guaranteed PostgreSQL persistence
            scope.launch {
                try {
                    val app = KidsAgentApp.instance
                    val deviceId = app.prefs.getString(KidsAgentApp.KEY_DEVICE_ID, null)
                    val serverUrl = app.prefs.getString(KidsAgentApp.KEY_SERVER_URL, null)
                    if (deviceId != null && serverUrl != null) {
                        val body = gson.toJson(payload).toRequestBody("application/json".toMediaType())
                        val req = Request.Builder()
                            .url("$serverUrl/api/v1/devices/$deviceId/notifications")
                            .post(body)
                            .build()
                        httpClient.newCall(req).execute().close()
                        Log.d(TAG, "Notification saved via REST API for $appName")
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "REST notification fallback failed: ${e.message}")
                }
            }

            // 3. AI Smart Content Risk Scan on Notification
            try {
                val fullText = "$title $text"
                val alert = com.parentalcontrol.kidsagent.safety.RiskDetector.scan(fullText, "NOTIFICATION: $appName")
                if (alert != null) {
                    Log.w(TAG, "AI Risk detected in notification from $appName: ${alert.category} / ${alert.severity}")
                    val sent = ForegroundSyncService.instance?.sendRiskAlert(alert) ?: false

                    scope.launch {
                        try {
                            val db = AppDatabase.getInstance(applicationContext)
                            val entity = OfflineRiskAlertEntity.fromPayload(alert, isSynced = sent)
                            db.riskAlertDao().insertRiskAlert(entity)
                        } catch (e: Exception) {
                            Log.e(TAG, "Error saving risk alert offline: ${e.message}")
                        }
                    }

                    if (!sent) {
                        OfflineSyncWorker.enqueue(applicationContext)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Risk scan error: ${e.message}")
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
    }
}
