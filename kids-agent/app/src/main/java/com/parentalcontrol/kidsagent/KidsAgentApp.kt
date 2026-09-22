package com.parentalcontrol.kidsagent

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import com.parentalcontrol.kidsagent.service.KeepAliveWorker
import java.util.concurrent.TimeUnit

class KidsAgentApp : Application() {

    companion object {
        const val CHANNEL_ID = "kids_agent_persistent_channel"
        const val CHANNEL_NAME = "Protection & Supervision"
        lateinit var instance: KidsAgentApp
            private set
        
        const val PREFS_NAME = "kids_agent_prefs"
        const val KEY_DEVICE_ID = "device_id"
        const val KEY_FAMILY_ID = "family_id"
        const val KEY_CHILD_ID = "child_id"
        const val KEY_PAIRING_SECRET = "pairing_secret"
        const val KEY_SERVER_URL = "server_url"
    }

    val prefs: SharedPreferences by lazy {
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    override fun onCreate() {
        super.onCreate()
        instance = this

        createNotificationChannel()
        scheduleKeepAliveWorker()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                description = "Protection service running quietly"
                setShowBadge(false)
                enableVibration(false)
                enableLights(false)
                setSound(null, null)
            }

            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun scheduleKeepAliveWorker() {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val keepAliveRequest = PeriodicWorkRequestBuilder<KeepAliveWorker>(15, TimeUnit.MINUTES)
            .setConstraints(constraints)
            .build()

        WorkManager.getInstance(this).enqueueUniquePeriodicWork(
            "KidsAgentKeepAlive",
            ExistingPeriodicWorkPolicy.KEEP,
            keepAliveRequest
        )
    }

    fun isPaired(): Boolean {
        return prefs.getString(KEY_DEVICE_ID, null) != null &&
               prefs.getString(KEY_PAIRING_SECRET, null) != null
    }

    fun savePairing(deviceId: String, familyId: String, childId: String, secret: String, serverUrl: String) {
        prefs.edit()
            .putString(KEY_DEVICE_ID, deviceId)
            .putString(KEY_FAMILY_ID, familyId)
            .putString(KEY_CHILD_ID, childId)
            .putString(KEY_PAIRING_SECRET, secret)
            .putString(KEY_SERVER_URL, serverUrl)
            .apply()
    }

    fun clearPairing() {
        val serverUrl = prefs.getString(KEY_SERVER_URL, null)
        prefs.edit().clear().apply()
        if (!serverUrl.isNullOrBlank()) {
            prefs.edit().putString(KEY_SERVER_URL, serverUrl).apply()
        }
    }
}
