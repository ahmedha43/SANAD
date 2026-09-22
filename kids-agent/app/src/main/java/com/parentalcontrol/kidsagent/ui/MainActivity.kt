package com.parentalcontrol.kidsagent.ui

import android.Manifest
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.gson.Gson
import com.parentalcontrol.kidsagent.KidsAgentApp
import com.parentalcontrol.kidsagent.service.AgentAccessibilityService
import com.parentalcontrol.kidsagent.service.AgentDeviceAdminReceiver
import com.parentalcontrol.kidsagent.service.ForegroundSyncService
import com.parentalcontrol.kidsagent.usage.UsageTracker
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

class MainActivity : AppCompatActivity() {

    companion object {
        const val REQUEST_SCREEN_CAPTURE = 2002
    }

    private val httpClient = OkHttpClient()
    private val gson = Gson()
    private var permissionsContainer: LinearLayout? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            renderUI()
            requestRuntimePermissionsIfNeeded()
        } catch (e: Throwable) {
            android.util.Log.e("MainActivity", "Error in onCreate: ${e.message}", e)
        }
    }

    override fun onResume() {
        super.onResume()
        try {
            refreshPermissionCards()
            if (KidsAgentApp.instance.isPaired()) {
                ForegroundSyncService.start(this)
            }
        } catch (e: Throwable) {
            android.util.Log.e("MainActivity", "Error in onResume: ${e.message}", e)
        }
    }

    private fun renderUI() {
        val scrollView = ScrollView(this).apply {
            setBackgroundColor(0xFF0F172A.toInt())
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(40, 60, 40, 60)
        }
        scrollView.addView(root)

        // 1. Header
        val titleView = TextView(this).apply {
            text = "Kids Agent Protection"
            textSize = 24f
            setTypeface(null, Typeface.BOLD)
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
        }
        root.addView(titleView)

        val isPaired = KidsAgentApp.instance.isPaired()
        val statusView = TextView(this).apply {
            text = if (isPaired) "● Protected & Connected to Family" else "○ Not Paired with Family"
            textSize = 14f
            setTextColor(if (isPaired) 0xFF22C55E.toInt() else 0xFFEF4444.toInt())
            setPadding(0, 16, 0, 30)
            gravity = Gravity.CENTER
        }
        root.addView(statusView)

        if (!isPaired) {
            // Pairing Inputs
            val serverInput = EditText(this).apply {
                hint = "Backend Server URL"
                setText("http://192.168.1.110:8080")
                setTextColor(Color.WHITE)
                setHintTextColor(0xFF94A3B8.toInt())
                setBackgroundColor(0xFF1E293B.toInt())
                setPadding(30, 30, 30, 30)
            }
            root.addView(serverInput)

            val codeInput = EditText(this).apply {
                hint = "Enter 6-Digit Pairing Code"
                setTextColor(Color.WHITE)
                setHintTextColor(0xFF94A3B8.toInt())
                setBackgroundColor(0xFF1E293B.toInt())
                setPadding(30, 30, 30, 30)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { topMargin = 20 }
            }
            root.addView(codeInput)

            val pairButton = Button(this).apply {
                text = "Pair Device with Family"
                setBackgroundColor(0xFF2563EB.toInt())
                setTextColor(Color.WHITE)
                setTypeface(null, Typeface.BOLD)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { topMargin = 30 }
                setOnClickListener {
                    val code = codeInput.text.toString().trim()
                    val server = serverInput.text.toString().trim()
                    if (code.length == 6 && server.isNotEmpty()) {
                        performPairing(code, server)
                    } else {
                        Toast.makeText(this@MainActivity, "Enter 6-digit code and server URL", Toast.LENGTH_SHORT).show()
                    }
                }
            }
            root.addView(pairButton)
        } else {
            // SOS Emergency Button
            val sosButton = Button(this).apply {
                text = "🚨 زر الاستغاثة للطوارئ (SOS EMERGENCY) 🚨"
                setBackgroundColor(0xFFDC2626.toInt())
                setTextColor(Color.WHITE)
                textSize = 16f
                setTypeface(null, Typeface.BOLD)
                setPadding(20, 35, 20, 35)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { bottomMargin = 30 }
                setOnClickListener {
                    triggerSOSAlert()
                }
            }
            root.addView(sosButton)

            // Permissions Management Center
            val sectionTitle = TextView(this).apply {
                text = "Protection Permissions (صلاحيات الحماية والوصول)"
                textSize = 18f
                setTypeface(null, Typeface.BOLD)
                setTextColor(0xFF38BDF8.toInt())
                setPadding(0, 10, 0, 20)
            }
            root.addView(sectionTitle)

            val subtitle = TextView(this).apply {
                text = "Grant all items below so remote camera, GPS, app blocking, contacts, messages, and device lock function properly:"
                textSize = 13f
                setTextColor(0xFF94A3B8.toInt())
                setPadding(0, 0, 0, 24)
            }
            root.addView(subtitle)

            permissionsContainer = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
            }
            root.addView(permissionsContainer)

            refreshPermissionCards()

            // Sync Now Button
            val syncButton = Button(this).apply {
                text = "Sync Device Status Now"
                setBackgroundColor(0xFF10B981.toInt())
                setTextColor(Color.WHITE)
                setTypeface(null, Typeface.BOLD)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { topMargin = 40 }
                setOnClickListener {
                    ForegroundSyncService.start(this@MainActivity)
                    Toast.makeText(this@MainActivity, "Device data synced with parents!", Toast.LENGTH_SHORT).show()
                }
            }
            root.addView(syncButton)
        }

        setContentView(scrollView)
    }

    private fun refreshPermissionCards() {
        val container = permissionsContainer ?: return
        container.removeAllViews()

        // 1. Core Sensors: GPS, Camera, Mic, Notifications
        val runtimeOk = hasRuntimePermissions()
        container.addView(buildPermissionCard(
            title = "1. Core Sensors (الموقع، الكاميرا، الصوت)",
            desc = "Allows GPS tracking, live remote camera, and audio.",
            isGranted = runtimeOk,
            actionLabel = "Grant Permissions",
            onAction = { requestRuntimePermissionsIfNeeded() }
        ))

        // 2. Usage Stats
        val usageTracker = UsageTracker(this)
        val usageOk = usageTracker.hasUsagePermission()
        container.addView(buildPermissionCard(
            title = "2. App Usage Access (بيانات استخدام التطبيقات)",
            desc = "Enables app limits, app inventory, and screen time reports.",
            isGranted = usageOk,
            actionLabel = "Enable Usage Access",
            onAction = {
                startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
            }
        ))

        // 3. Draw Over Other Apps
        val overlayOk = hasOverlayPermission()
        container.addView(buildPermissionCard(
            title = "3. Display Over Apps (شاشة القفل فوق التطبيقات)",
            desc = "Enables full-screen parental lock when device is locked.",
            isGranted = overlayOk,
            actionLabel = "Enable Overlay",
            onAction = {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:$packageName")
                    )
                    startActivity(intent)
                }
            }
        ))

        // 4. Device Administrator
        val adminOk = isDeviceAdminActive()
        container.addView(buildPermissionCard(
            title = "4. Device Administrator (مدير الجهاز للقفل الفوري)",
            desc = "Allows instant remote hardware screen locking.",
            isGranted = adminOk,
            actionLabel = "Activate Admin",
            onAction = {
                val adminComponent = ComponentName(this, AgentDeviceAdminReceiver::class.java)
                val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
                    putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent)
                    putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, "Enables parental remote lock.")
                }
                startActivity(intent)
            }
        ))

        // 5. Accessibility Service
        val accessOk = isAccessibilityServiceEnabled()
        container.addView(buildPermissionCard(
            title = "5. Accessibility Service (لقطة الشاشة الفورية، حظر التطبيقات، الحماية)",
            desc = "Allows instant silent remote screenshots, safe web filtering, app blocking, and anti-uninstall shield.",
            isGranted = accessOk,
            actionLabel = "Enable Accessibility",
            onAction = {
                startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
            }
        ))

        // 6. Battery Optimization
        val batteryOk = isIgnoringBatteryOptimizations()
        container.addView(buildPermissionCard(
            title = "6. Background Keep-Alive (استثناء توفير الطاقة)",
            desc = "Keeps Kids Agent running 24/7 in the background without being killed.",
            isGranted = batteryOk,
            actionLabel = "Ignore Optimization",
            onAction = {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        data = Uri.parse("package:$packageName")
                    }
                    startActivity(intent)
                }
            }
        ))

        // 7. Screen Streaming & Mirroring
        val screenOk = com.parentalcontrol.kidsagent.webrtc.MediaProjectionHolder.isGranted
        container.addView(buildPermissionCard(
            title = "7. Screen Mirroring (بث ومراقبة الشاشة المباشر)",
            desc = "Allows instant live remote screen streaming to the parent app and web dashboard.",
            isGranted = screenOk,
            actionLabel = "Enable Screen Mirroring",
            onAction = {
                val mgr = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as? android.media.projection.MediaProjectionManager
                if (mgr != null) {
                    try {
                        startActivityForResult(mgr.createScreenCaptureIntent(), REQUEST_SCREEN_CAPTURE)
                    } catch (e: Exception) {
                        Toast.makeText(this, "Failed to request screen capture: ${e.message}", Toast.LENGTH_SHORT).show()
                    }
                } else {
                    Toast.makeText(this, "MediaProjection not supported on this device", Toast.LENGTH_SHORT).show()
                }
            }
        ))
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_SCREEN_CAPTURE) {
            if (resultCode == RESULT_OK && data != null) {
                com.parentalcontrol.kidsagent.webrtc.MediaProjectionHolder.setProjection(data)
                ForegroundSyncService.onScreenCapturePermissionGranted(data)
                refreshPermissionCards()
                Toast.makeText(this, "تم تفعيل بث ومراقبة الشاشة بنجاح!", Toast.LENGTH_SHORT).show()
            } else {
                Toast.makeText(this, "تم إلغاء إذن بث الشاشة", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun buildPermissionCard(
        title: String,
        desc: String,
        isGranted: Boolean,
        actionLabel: String,
        onAction: () -> Unit
    ): View {
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(0xFF1E293B.toInt())
            setPadding(30, 24, 30, 24)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = 20 }
        }

        val topRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val titleTv = TextView(this).apply {
            text = title
            textSize = 15f
            setTypeface(null, Typeface.BOLD)
            setTextColor(Color.WHITE)
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        topRow.addView(titleTv)

        val statusTv = TextView(this).apply {
            text = if (isGranted) "✓ Granted" else "⚠ Required"
            textSize = 12f
            setTypeface(null, Typeface.BOLD)
            setTextColor(if (isGranted) 0xFF22C55E.toInt() else 0xFFF59E0B.toInt())
            setPadding(16, 6, 16, 6)
            setBackgroundColor(if (isGranted) 0x2222C55E else 0x22F59E0B)
        }
        topRow.addView(statusTv)
        card.addView(topRow)

        val descTv = TextView(this).apply {
            text = desc
            textSize = 12f
            setTextColor(0xFF94A3B8.toInt())
            setPadding(0, 10, 0, 16)
        }
        card.addView(descTv)

        if (!isGranted) {
            val btn = Button(this).apply {
                text = actionLabel
                textSize = 13f
                setBackgroundColor(0xFF3B82F6.toInt())
                setTextColor(Color.WHITE)
                setOnClickListener { onAction() }
            }
            card.addView(btn)
        }

        return card
    }

    private fun hasRuntimePermissions(): Boolean {
        val fineLoc = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val cam = ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
        val mic = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        val contacts = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED
        val sms = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
        val callLog = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) == PackageManager.PERMISSION_GRANTED
        val notif = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        } else true
        return fineLoc && cam && mic && contacts && sms && callLog && notif
    }

    private fun requestRuntimePermissionsIfNeeded() {
        val perms = mutableListOf<String>()
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            perms.add(Manifest.permission.ACCESS_FINE_LOCATION)
            perms.add(Manifest.permission.ACCESS_COARSE_LOCATION)
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            perms.add(Manifest.permission.CAMERA)
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            perms.add(Manifest.permission.RECORD_AUDIO)
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
            perms.add(Manifest.permission.READ_CONTACTS)
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
            perms.add(Manifest.permission.READ_SMS)
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) != PackageManager.PERMISSION_GRANTED) {
            perms.add(Manifest.permission.READ_CALL_LOG)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                perms.add(Manifest.permission.POST_NOTIFICATIONS)
            }
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_IMAGES) != PackageManager.PERMISSION_GRANTED) {
                perms.add(Manifest.permission.READ_MEDIA_IMAGES)
            }
        } else {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                perms.add(Manifest.permission.READ_EXTERNAL_STORAGE)
            }
        }
        if (perms.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, perms.toTypedArray(), 101)
        }
    }

    private fun triggerSOSAlert() {
        val app = KidsAgentApp.instance
        if (!app.isPaired()) {
            Toast.makeText(this, "Device must be paired first", Toast.LENGTH_SHORT).show()
            return
        }

        val locManager = getSystemService(Context.LOCATION_SERVICE) as? android.location.LocationManager
        var lat = 0.0
        var lon = 0.0
        try {
            val lastLoc = locManager?.getLastKnownLocation(android.location.LocationManager.GPS_PROVIDER)
                ?: locManager?.getLastKnownLocation(android.location.LocationManager.NETWORK_PROVIDER)
            if (lastLoc != null) {
                lat = lastLoc.latitude
                lon = lastLoc.longitude
            }
        } catch (e: Exception) {
            // Ignored
        }

        val bm = getSystemService(Context.BATTERY_SERVICE) as? android.os.BatteryManager
        val battery = bm?.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: 100

        val payload = com.parentalcontrol.kidsagent.data.model.SOSAlertPayload(
            latitude = lat,
            longitude = lon,
            batteryLevel = battery,
            timestamp = System.currentTimeMillis()
        )

        val wsClient = com.parentalcontrol.kidsagent.data.network.AgentWebSocketClient(this) {}
        wsClient.connect()
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            wsClient.sendMessage("SOS_ALERT", payload)
            Toast.makeText(this, "🚨 تم إرسال نداء الاستغاثة والموقع لوالديك بنجاح!", Toast.LENGTH_LONG).show()
        }, 800L)
    }

    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else true
    }

    private fun isDeviceAdminActive(): Boolean {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager
        val adminComponent = ComponentName(this, AgentDeviceAdminReceiver::class.java)
        return dpm?.isAdminActive(adminComponent) ?: false
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expected = ComponentName(this, AgentAccessibilityService::class.java).flattenToString()
        val enabled = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: ""
        return enabled.contains(expected)
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
            return pm?.isIgnoringBatteryOptimizations(packageName) ?: false
        }
        return true
    }

    private fun performPairing(code: String, serverUrl: String) {
        val deviceUid = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
        val deviceName = "${Build.MANUFACTURER} ${Build.MODEL}"

        val pairPayload = mapOf(
            "code" to code,
            "device_uid" to deviceUid,
            "device_name" to deviceName,
            "model" to Build.MODEL,
            "os_version" to Build.VERSION.RELEASE,
            "app_version" to "1.0.0"
        )

        CoroutineScope(Dispatchers.IO).launch {
            try {
                val json = gson.toJson(pairPayload)
                val body = json.toRequestBody("application/json".toMediaType())
                val request = Request.Builder()
                    .url("$serverUrl/api/v1/devices/pair")
                    .post(body)
                    .build()

                val response = httpClient.newCall(request).execute()
                val respBody = response.body?.string() ?: ""

                if (response.isSuccessful) {
                    val respMap = gson.fromJson(respBody, Map::class.java)
                    val deviceId = respMap["device_id"]?.toString() ?: ""
                    val familyId = respMap["family_id"]?.toString() ?: ""
                    val childId = respMap["child_id"]?.toString() ?: ""
                    val secret = respMap["pairing_secret"]?.toString() ?: ""

                    if (deviceId.isNotEmpty() && secret.isNotEmpty()) {
                        KidsAgentApp.instance.savePairing(deviceId, familyId, childId, secret, serverUrl)

                        withContext(Dispatchers.Main) {
                            Toast.makeText(this@MainActivity, "Device paired successfully!", Toast.LENGTH_LONG).show()
                            try {
                                ForegroundSyncService.start(this@MainActivity)
                            } catch (e: Throwable) {
                                android.util.Log.e("MainActivity", "Failed to start service: ${e.message}")
                            }
                            try {
                                renderUI()
                            } catch (e: Throwable) {
                                android.util.Log.e("MainActivity", "Failed to renderUI: ${e.message}")
                            }
                        }
                    } else {
                        withContext(Dispatchers.Main) {
                            Toast.makeText(this@MainActivity, "Invalid pairing response from server", Toast.LENGTH_LONG).show()
                        }
                    }
                } else {
                    withContext(Dispatchers.Main) {
                        Toast.makeText(this@MainActivity, "Pairing failed: $respBody", Toast.LENGTH_LONG).show()
                    }
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    Toast.makeText(this@MainActivity, "Network error: ${e.message}", Toast.LENGTH_LONG).show()
                }
            }
        }
    }
}
