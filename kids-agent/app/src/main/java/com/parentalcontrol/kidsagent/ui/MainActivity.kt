package com.parentalcontrol.kidsagent.ui

import android.Manifest
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.widget.*
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.google.gson.Gson
import com.parentalcontrol.kidsagent.KidsAgentApp
import com.parentalcontrol.kidsagent.service.AgentAccessibilityService
import com.parentalcontrol.kidsagent.service.AgentDeviceAdminReceiver
import com.parentalcontrol.kidsagent.service.AgentNotificationListener
import com.parentalcontrol.kidsagent.service.ForegroundSyncService
import com.parentalcontrol.kidsagent.usage.UsageTracker
import com.parentalcontrol.kidsagent.webrtc.MediaProjectionHolder
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
        const val REQUEST_PERMS_BATCH = 101
        const val REQUEST_PERMS_LOCATION = 102
        const val REQUEST_PERMS_CAMERA_MIC = 103
        const val REQUEST_PERMS_CALLS_SMS = 104
    }

    private val httpClient = OkHttpClient()
    private val gson = Gson()

    private var permissionsContainer: LinearLayout? = null
    private var healthSummaryView: TextView? = null
    private var healthProgressBar: ProgressBar? = null
    private var accessibilityWarningCard: LinearLayout? = null

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

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        try {
            refreshPermissionCards()
        } catch (e: Throwable) {
            android.util.Log.e("MainActivity", "Error in onRequestPermissionsResult: ${e.message}", e)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_SCREEN_CAPTURE) {
            if (resultCode == RESULT_OK && data != null) {
                MediaProjectionHolder.setProjection(data)
                ForegroundSyncService.onScreenCapturePermissionGranted(data)
                refreshPermissionCards()
                Toast.makeText(this, "تم تفعيل بث ومراقبة الشاشة بنجاح!", Toast.LENGTH_SHORT).show()
            } else {
                Toast.makeText(this, "تم إلغاء إذن بث الشاشة", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun makeShape(bgColor: Int, strokeColor: Int = 0, cornerRadiusDp: Float = 12f): GradientDrawable {
        val density = resources.displayMetrics.density
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(bgColor)
            cornerRadius = cornerRadiusDp * density
            if (strokeColor != 0) {
                setStroke((1.5f * density).toInt(), strokeColor)
            }
        }
    }

    private fun renderUI() {
        val scrollView = ScrollView(this).apply {
            setBackgroundColor(0xFF0F172A.toInt()) // Slate 900
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(36, 48, 36, 60)
        }
        scrollView.addView(root)

        // 1. App Header
        val titleView = TextView(this).apply {
            text = "🛡️ SANAD Protection"
            textSize = 22f
            setTypeface(null, Typeface.BOLD)
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
        }
        root.addView(titleView)

        val isPaired = KidsAgentApp.instance.isPaired()
        val statusView = TextView(this).apply {
            text = if (isPaired) "● محمي ومتصل بالحماية الأسرية" else "○ غير مقترن بالحماية الأسرية"
            textSize = 14f
            setTypeface(null, Typeface.BOLD)
            setTextColor(if (isPaired) 0xFF22C55E.toInt() else 0xFFEF4444.toInt())
            setPadding(0, 10, 0, 24)
            gravity = Gravity.CENTER
        }
        root.addView(statusView)

        // 2. Unpaired vs Paired Top Actions
        if (!isPaired) {
            // Pairing Card
            val pairingCard = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                background = makeShape(0xFF1E293B.toInt(), 0xFF334155.toInt(), 14f)
                setPadding(32, 28, 32, 32)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { bottomMargin = 32 }
            }

            val pairTitle = TextView(this).apply {
                text = "🔗 ربط الجهاز بحساب الوالدين"
                textSize = 16f
                setTypeface(null, Typeface.BOLD)
                setTextColor(0xFF38BDF8.toInt())
                setPadding(0, 0, 0, 12)
            }
            pairingCard.addView(pairTitle)

            val serverInput = EditText(this).apply {
                hint = "عنوان سيرفر سَنَد (Backend Server URL)"
                val savedUrl = KidsAgentApp.instance.prefs.getString(KidsAgentApp.KEY_SERVER_URL, null)
                setText(if (!savedUrl.isNullOrBlank()) savedUrl else "http://192.168.88.54:8080")
                setTextColor(Color.WHITE)
                setHintTextColor(0xFF94A3B8.toInt())
                background = makeShape(0xFF0F172A.toInt(), 0xFF475569.toInt(), 8f)
                setPadding(28, 24, 28, 24)
            }
            pairingCard.addView(serverInput)

            val codeInput = EditText(this).apply {
                hint = "أدخل رمز الاقتران المكون من 6 أرقام"
                setTextColor(Color.WHITE)
                setHintTextColor(0xFF94A3B8.toInt())
                background = makeShape(0xFF0F172A.toInt(), 0xFF475569.toInt(), 8f)
                setPadding(28, 24, 28, 24)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { topMargin = 20 }
            }
            pairingCard.addView(codeInput)

            val pairButton = Button(this).apply {
                text = "⚡ إتمام الاقتران وربط الجهاز"
                background = makeShape(0xFF2563EB.toInt(), 0, 10f)
                setTextColor(Color.WHITE)
                setTypeface(null, Typeface.BOLD)
                textSize = 15f
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { topMargin = 24 }
                setOnClickListener {
                    val code = codeInput.text.toString().trim()
                    val server = serverInput.text.toString().trim()
                    if (code.length == 6 && server.isNotEmpty()) {
                        performPairing(code, server)
                    } else {
                        Toast.makeText(this@MainActivity, "يرجى إدخال الرمز المكون من 6 أرقام وعنوان السيرفر", Toast.LENGTH_SHORT).show()
                    }
                }
            }
            pairingCard.addView(pairButton)
            root.addView(pairingCard)
        } else {
            // SOS Emergency Button
            val sosButton = Button(this).apply {
                text = "🚨 زر الاستغاثة للطوارئ (SOS EMERGENCY) 🚨"
                background = makeShape(0xFFDC2626.toInt(), 0xFFFCA5A5.toInt(), 12f)
                setTextColor(Color.WHITE)
                textSize = 15f
                setTypeface(null, Typeface.BOLD)
                setPadding(20, 32, 20, 32)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { bottomMargin = 24 }
                setOnClickListener {
                    triggerSOSAlert()
                }
            }
            root.addView(sosButton)
        }

        // 3. Permissions & System Health Dashboard (ALWAYS VISIBLE!)
        val permSectionHeader = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, 8, 0, 16)
        }

        val sectionTitle = TextView(this).apply {
            text = "📋 مركز الصلاحيات وحالة الحماية"
            textSize = 18f
            setTypeface(null, Typeface.BOLD)
            setTextColor(0xFF38BDF8.toInt())
        }
        permSectionHeader.addView(sectionTitle)

        val subtitle = TextView(this).apply {
            text = "يرجى تفعيل كافة الصلاحيات أدناه لضمان عمل الحماية الكاملة (لقطات الشاشة، حظر التطبيقات، البث المباشر، وتتبع الموقع):"
            textSize = 12f
            setTextColor(0xFF94A3B8.toInt())
            setPadding(0, 6, 0, 12)
        }
        permSectionHeader.addView(subtitle)
        root.addView(permSectionHeader)

        // Health Summary Card (Progress & Count)
        val healthCard = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = makeShape(0xFF1E293B.toInt(), 0xFF334155.toInt(), 12f)
            setPadding(28, 20, 28, 20)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = 20 }
        }

        healthSummaryView = TextView(this).apply {
            text = "جاري فحص حالة الصلاحيات..."
            textSize = 14f
            setTypeface(null, Typeface.BOLD)
            setTextColor(Color.WHITE)
        }
        healthCard.addView(healthSummaryView)

        healthProgressBar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 11
            progress = 0
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                (14 * resources.displayMetrics.density).toInt()
            ).apply { topMargin = 12 }
        }
        healthCard.addView(healthProgressBar)
        root.addView(healthCard)

        // Accessibility Specific Alert Card (appears when accessibility is off)
        accessibilityWarningCard = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = makeShape(0x22EF4444.toInt(), 0xFFEF4444.toInt(), 12f)
            setPadding(24, 20, 24, 20)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = 20 }
            visibility = View.GONE
        }

        val accWarnTitle = TextView(this).apply {
            text = "⚠️ خدمة إمكانية الوصول (Accessibility) غير مفعلة!"
            textSize = 14f
            setTypeface(null, Typeface.BOLD)
            setTextColor(0xFFFCA5A5.toInt())
        }
        accessibilityWarningCard?.addView(accWarnTitle)

        val accWarnDesc = TextView(this).apply {
            text = "لن تعمل لقطات الشاشة عن بُعد الصامتة، حظر التطبيقات، أو درع الأمان حتى يتم تفعيل الخدمة من إعدادات الجهاز."
            textSize = 12f
            setTextColor(0xFFE2E8F0.toInt())
            setPadding(0, 6, 0, 12)
        }
        accessibilityWarningCard?.addView(accWarnDesc)

        val btnFixAcc = Button(this).apply {
            text = "⚙️ تفعيل خدمة الوصول الآن"
            background = makeShape(0xFFDC2626.toInt(), 0, 8f)
            setTextColor(Color.WHITE)
            setTypeface(null, Typeface.BOLD)
            textSize = 13f
            setOnClickListener {
                startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
            }
        }
        accessibilityWarningCard?.addView(btnFixAcc)
        root.addView(accessibilityWarningCard)

        // Android 13/14 Restricted Settings Guide Card
        val restrictedCard = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = makeShape(0xFF1E293B.toInt(), 0xFF0284C7.toInt(), 12f)
            setPadding(24, 20, 24, 20)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = 20 }
        }

        val restTitle = TextView(this).apply {
            text = "ℹ️ لمستخدمي أندرويد 13 وأندرويد 14 (الإعدادات المقيدة):"
            textSize = 13f
            setTypeface(null, Typeface.BOLD)
            setTextColor(0xFF38BDF8.toInt())
        }
        restrictedCard.addView(restTitle)

        val restDesc = TextView(this).apply {
            text = "إذا ظهرت خدمة إمكانية الوصول أو الإشعارات باللون الرمادي مع عبارة 'إعداد مقيد' (Restricted Setting):\n" +
                    "1. اضغط على الزر أدناه لفتح صفحة 'معلومات التطبيق'.\n" +
                    "2. اضغط على النقاط الثلاث (⋮) بأعلى الشاشة.\n" +
                    "3. اختر 'السماح بالإعدادات المقيدة' (Allow restricted settings).\n" +
                    "4. ارجع إلى هنا وفعّل خدمة إمكانية الوصول."
            textSize = 11.5f
            setTextColor(0xFFCBD5E1.toInt())
            setPadding(0, 8, 0, 14)
            setLineSpacing(4f, 1f)
        }
        restrictedCard.addView(restDesc)

        val btnOpenAppInfo = Button(this).apply {
            text = "🔓 فتح معلومات التطبيق لفك التقييد (App Info)"
            background = makeShape(0xFF0284C7.toInt(), 0, 8f)
            setTextColor(Color.WHITE)
            setTypeface(null, Typeface.BOLD)
            textSize = 12.5f
            setOnClickListener {
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
            }
        }
        restrictedCard.addView(btnOpenAppInfo)
        root.addView(restrictedCard)

        // One-Click Batch Grant Button
        val batchButton = Button(this).apply {
            text = "⚡ طلب ومنح الصلاحيات الأساسية دفعة واحدة"
            background = makeShape(0xFF2563EB.toInt(), 0, 10f)
            setTextColor(Color.WHITE)
            setTypeface(null, Typeface.BOLD)
            textSize = 14f
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = 24 }
            setOnClickListener {
                requestBatchRuntimePermissions()
            }
        }
        root.addView(batchButton)

        // Container for all 10 individual permission cards
        permissionsContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }
        root.addView(permissionsContainer)

        // Initial render of permission cards
        refreshPermissionCards()

        // 4. Paired-Only Management Actions (Sync & Re-Pair)
        if (isPaired) {
            val syncButton = Button(this).apply {
                text = "🔄 مزامنة بيانات الحماية الآن (Sync Now)"
                background = makeShape(0xFF10B981.toInt(), 0, 10f)
                setTextColor(Color.WHITE)
                setTypeface(null, Typeface.BOLD)
                textSize = 14f
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { topMargin = 24; bottomMargin = 16 }
                setOnClickListener {
                    ForegroundSyncService.start(this@MainActivity)
                    Toast.makeText(this@MainActivity, "تم بدء مزامنة بيانات الجهاز مع لوحة الوالدين!", Toast.LENGTH_SHORT).show()
                }
            }
            root.addView(syncButton)

            val serverUrl = KidsAgentApp.instance.prefs.getString(KidsAgentApp.KEY_SERVER_URL, "") ?: ""
            val deviceId = KidsAgentApp.instance.prefs.getString(KidsAgentApp.KEY_DEVICE_ID, "") ?: ""

            val infoCard = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                background = makeShape(0xFF1E293B.toInt(), 0xFF334155.toInt(), 12f)
                setPadding(28, 20, 28, 20)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { topMargin = 16; bottomMargin = 16 }
            }

            val infoTitle = TextView(this).apply {
                text = "معلومات الاتصال والاقتران الحالي"
                textSize = 14f
                setTypeface(null, Typeface.BOLD)
                setTextColor(0xFF38BDF8.toInt())
            }
            infoCard.addView(infoTitle)

            val infoDetails = TextView(this).apply {
                text = "السيرفر: $serverUrl\nمعرف الجهاز: ${if (deviceId.length > 8) deviceId.substring(0, 8) + "..." else deviceId}"
                textSize = 12f
                setTextColor(0xFF94A3B8.toInt())
                setPadding(0, 8, 0, 0)
            }
            infoCard.addView(infoDetails)
            root.addView(infoCard)

            val changeServerButton = Button(this).apply {
                text = "🌐 تعديل عنوان السيرفر (Change Server IP)"
                background = makeShape(0xFF0284C7.toInt(), 0, 10f)
                setTextColor(Color.WHITE)
                setTypeface(null, Typeface.BOLD)
                textSize = 13f
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { bottomMargin = 12 }
                setOnClickListener {
                    val currentUrl = KidsAgentApp.instance.prefs.getString(KidsAgentApp.KEY_SERVER_URL, "http://192.168.88.54:8080") ?: "http://192.168.88.54:8080"
                    val input = EditText(this@MainActivity).apply {
                        setText(currentUrl)
                        setTextColor(Color.BLACK)
                        setPadding(32, 24, 32, 24)
                    }
                    AlertDialog.Builder(this@MainActivity)
                        .setTitle("تحديث عنوان سيرفر سَنَد")
                        .setMessage("أدخل عنوان الـ IP الجديد للكمبيوتر/السيرفر (مثال: http://192.168.88.54:8080):")
                        .setView(input)
                        .setPositiveButton("حفظ وتحديث الاتصال") { _, _ ->
                            val newUrl = input.text.toString().trim()
                            if (newUrl.isNotBlank()) {
                                val formattedUrl = if (!newUrl.startsWith("http://") && !newUrl.startsWith("https://")) "http://$newUrl" else newUrl
                                KidsAgentApp.instance.prefs.edit().putString(KidsAgentApp.KEY_SERVER_URL, formattedUrl).apply()
                                Toast.makeText(this@MainActivity, "تم تحديث السيرفر إلى: $formattedUrl", Toast.LENGTH_SHORT).show()
                                ForegroundSyncService.start(this@MainActivity)
                                renderUI()
                            }
                        }
                        .setNegativeButton("إلغاء", null)
                        .show()
                }
            }
            root.addView(changeServerButton)

            val unpairButton = Button(this).apply {
                text = "🔄 تغيير الاقتران / ربط بكود جديد (Re-Pair)"
                background = makeShape(0xFF475569.toInt(), 0, 10f)
                setTextColor(Color.WHITE)
                setTypeface(null, Typeface.BOLD)
                textSize = 13f
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { bottomMargin = 40 }
                setOnClickListener {
                    AlertDialog.Builder(this@MainActivity)
                        .setTitle("تغيير الاقتران / فك الارتباط")
                        .setMessage("هل أنت متأكد من رغبتك في فك اقتران هذا الجهاز؟ سيتيح لك هذا إدخال كود اقتران جديد وربطه بحساب أو طفل مختلف.")
                        .setPositiveButton("نعم، فك الاقتران") { _, _ ->
                            try {
                                val svcIntent = Intent(this@MainActivity, ForegroundSyncService::class.java)
                                stopService(svcIntent)
                            } catch (_: Throwable) {}
                            KidsAgentApp.instance.clearPairing()
                            Toast.makeText(this@MainActivity, "تم فك الاقتران بنجاح. يمكنك الآن إدخال كود جديد.", Toast.LENGTH_LONG).show()
                            renderUI()
                        }
                        .setNegativeButton("إلغاء", null)
                        .show()
                }
            }
            root.addView(unpairButton)
        }

        setContentView(scrollView)
    }

    private fun refreshPermissionCards() {
        val container = permissionsContainer ?: return
        container.removeAllViews()

        var grantedCount = 0
        val totalCount = 11

        // 1. Accessibility Service
        val accessOk = isAccessibilityServiceEnabled()
        if (accessOk) grantedCount++
        container.addView(buildPermissionCard(
            title = "1. خدمة إمكانية الوصول (Accessibility)",
            desc = "ضرورية لالتقاط لقطات الشاشة عن بُعد الصامتة، فحص الروابط والمواقع، حظر التطبيقات، ومنع حذف التطبيق.",
            isGranted = accessOk,
            actionLabel = "⚙️ تفعيل خدمة الوصول",
            onAction = {
                startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
            }
        ))

        // Update accessibility warning card visibility
        accessibilityWarningCard?.visibility = if (accessOk) View.GONE else View.VISIBLE

        // 2. Notification Access (Listener)
        val notifListenerOk = isNotificationListenerEnabled()
        if (notifListenerOk) grantedCount++
        container.addView(buildPermissionCard(
            title = "2. الوصول إلى الإشعارات (Notification Access)",
            desc = "لقراءة إشعارات واتساب، تلغرام، والرسائل، وتطبيق المسح الذكي للكشف عن الكلمات الخادشة أو الخطرة فوراً.",
            isGranted = notifListenerOk,
            actionLabel = "🔔 تفعيل قراءة الإشعارات",
            onAction = {
                startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
            }
        ))

        // 3. Usage Stats
        val usageTracker = UsageTracker(this)
        val usageOk = usageTracker.hasUsagePermission()
        if (usageOk) grantedCount++
        container.addView(buildPermissionCard(
            title = "3. بيانات استخدام التطبيقات (Usage Access)",
            desc = "لحساب وقت الشاشة اليومي، التطبيقات الأكثر استخداماً، وتطبيق حدود الاستخدام والجدول الزمني.",
            isGranted = usageOk,
            actionLabel = "📊 تفعيل إحصائيات الاستخدام",
            onAction = {
                startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
            }
        ))

        // 4. Draw Over Other Apps
        val overlayOk = hasOverlayPermission()
        if (overlayOk) grantedCount++
        container.addView(buildPermissionCard(
            title = "4. الظهور فوق التطبيقات (Display Over Apps)",
            desc = "لعرض شاشة قفل الوالدين ومنع تشغيل التطبيقات المحظورة فوراً على كامل الشاشة.",
            isGranted = overlayOk,
            actionLabel = "🔲 تفعيل الظهور فوق التطبيقات",
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

        // 5. Device Administrator
        val adminOk = isDeviceAdminActive()
        if (adminOk) grantedCount++
        container.addView(buildPermissionCard(
            title = "5. مدير ومسؤول الجهاز (Device Administrator)",
            desc = "لتمكين القفل الفوري لشاشة الهاتف عتادياً عن بُعد من خلال ضغطة زر واحدة في لوحة الوالدين.",
            isGranted = adminOk,
            actionLabel = "🛡️ تفعيل مدير الجهاز",
            onAction = {
                val adminComponent = ComponentName(this, AgentDeviceAdminReceiver::class.java)
                val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
                    putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent)
                    putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, "يسمح لوالديك بقفل الشاشة فورياً للحماية الأسرية.")
                }
                startActivity(intent)
            }
        ))

        // 6. Location (GPS)
        val locOk = hasLocationPermission()
        if (locOk) grantedCount++
        container.addView(buildPermissionCard(
            title = "6. الموقع الجغرافي المباشر (GPS Location)",
            desc = "لتتبع مكان الطفل على الخريطة وسجل التنقلات والمناطق الآمنة (Geofencing) في الوقت الفعلي.",
            isGranted = locOk,
            actionLabel = "📍 منح صلاحية الموقع",
            onAction = {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
                    REQUEST_PERMS_LOCATION
                )
            }
        ))

        // 7. Camera & Microphone
        val camMicOk = hasCameraAndMicPermission()
        if (camMicOk) grantedCount++
        container.addView(buildPermissionCard(
            title = "7. الكاميرا والصوت المباشر (Camera & Audio)",
            desc = "للبث المباشر للصوت والصورة عبر WebRTC والاستماع للمحيط في الحالات الطارئة.",
            isGranted = camMicOk,
            actionLabel = "🎙️ منح صلاحية الكاميرا والمايك",
            onAction = {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO),
                    REQUEST_PERMS_CAMERA_MIC
                )
            }
        ))

        // 8. Calls, SMS & Contacts
        val callsSmsOk = hasCallsAndSmsPermission()
        if (callsSmsOk) grantedCount++
        container.addView(buildPermissionCard(
            title = "8. سجل المكالمات والرسائل وجهات الاتصال",
            desc = "لمزامنة سجل المكالمات والرسائل النصية والأسماء لاكتشاف الأرقام المجهولة والتواصل الخطر.",
            isGranted = callsSmsOk,
            actionLabel = "📞 منح صلاحية المكالمات والرسائل",
            onAction = {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(
                        Manifest.permission.READ_CALL_LOG,
                        Manifest.permission.READ_SMS,
                        Manifest.permission.RECEIVE_SMS,
                        Manifest.permission.READ_CONTACTS
                    ),
                    REQUEST_PERMS_CALLS_SMS
                )
            }
        ))

        // 9. Battery Optimization
        val batteryOk = isIgnoringBatteryOptimizations()
        if (batteryOk) grantedCount++
        container.addView(buildPermissionCard(
            title = "9. استثناء توفير الطاقة (Battery Optimization)",
            desc = "لضمان استمرار الحماية ومزامنة البيانات 24/7 بالخلفية دون أن يوقف نظام أندرويد التطبيق.",
            isGranted = batteryOk,
            actionLabel = "🔋 استثناء من توفير الطاقة",
            onAction = {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        data = Uri.parse("package:$packageName")
                    }
                    startActivity(intent)
                }
            }
        ))

        // 10. Screen Streaming & Mirroring
        val screenOk = MediaProjectionHolder.isGranted
        if (screenOk) grantedCount++
        container.addView(buildPermissionCard(
            title = "10. بث ومشاركة الشاشة (Screen Mirroring)",
            desc = "لمشاهدة ومراقبة شاشة الجهاز مباشرة عبر تقنية WebRTC من لوحة الوالدين.",
            isGranted = screenOk,
            actionLabel = "📺 تفعيل بث الشاشة",
            onAction = {
                val mgr = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as? MediaProjectionManager
                if (mgr != null) {
                    try {
                        startActivityForResult(mgr.createScreenCaptureIntent(), REQUEST_SCREEN_CAPTURE)
                    } catch (e: Exception) {
                        Toast.makeText(this, "فشل طلب مشاركة الشاشة: ${e.message}", Toast.LENGTH_SHORT).show()
                    }
                } else {
                    Toast.makeText(this, "مشاركة الشاشة غير مدعومة على هذا الجهاز", Toast.LENGTH_SHORT).show()
                }
            }
        ))

        // 11. Storage & Files Access
        val storageOk = hasAllFilesPermission()
        if (storageOk) grantedCount++
        container.addView(buildPermissionCard(
            title = "11. الوصول إلى الملفات والمعرض (Files & Media Access)",
            desc = "لتصفح ونقل ملفات الجهاز، استعراض معرض الصور والفيديوهات، ومعاينة وتحميل المستندات عن بُعد.",
            isGranted = storageOk,
            actionLabel = "📁 تفعيل الوصول لكافة الملفات",
            onAction = {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    try {
                        val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                    } catch (_: Exception) {
                        val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                        startActivity(intent)
                    }
                } else {
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE, Manifest.permission.WRITE_EXTERNAL_STORAGE),
                        105
                    )
                }
            }
        ))

        // Update Health Summary Header
        val pct = (grantedCount * 100) / totalCount
        healthProgressBar?.progress = grantedCount
        val statusText = if (grantedCount == totalCount) {
            "✅ درع الحماية مكتمل بنسبة 100% (جميع الصلاحيات الـ $totalCount مفعلة)"
        } else {
            "⚠️ تم تفعيل $grantedCount من أصل $totalCount صلاحيات ($pct%) - يرجى إكمال المتبقي"
        }
        healthSummaryView?.text = statusText
        healthSummaryView?.setTextColor(if (grantedCount == totalCount) 0xFF22C55E.toInt() else 0xFFF59E0B.toInt())
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
            background = makeShape(
                0xFF1E293B.toInt(),
                if (isGranted) 0x3322C55E else 0x33F59E0B,
                12f
            )
            setPadding(28, 22, 28, 22)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = 16 }
        }

        val topRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val titleTv = TextView(this).apply {
            text = title
            textSize = 14.5f
            setTypeface(null, Typeface.BOLD)
            setTextColor(Color.WHITE)
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        topRow.addView(titleTv)

        val statusTv = TextView(this).apply {
            text = if (isGranted) "مفعلة ✅" else "غير مفعلة ⚠️"
            textSize = 12f
            setTypeface(null, Typeface.BOLD)
            setTextColor(if (isGranted) 0xFF22C55E.toInt() else 0xFFF59E0B.toInt())
            setPadding(16, 6, 16, 6)
            background = makeShape(
                if (isGranted) 0x2222C55E else 0x22F59E0B,
                if (isGranted) 0xFF22C55E.toInt() else 0xFFF59E0B.toInt(),
                6f
            )
        }
        topRow.addView(statusTv)
        card.addView(topRow)

        val descTv = TextView(this).apply {
            text = desc
            textSize = 12f
            setTextColor(0xFF94A3B8.toInt())
            setPadding(0, 10, 0, 14)
            setLineSpacing(2f, 1f)
        }
        card.addView(descTv)

        if (!isGranted) {
            val btn = Button(this).apply {
                text = actionLabel
                textSize = 13f
                setTypeface(null, Typeface.BOLD)
                background = makeShape(0xFF2563EB.toInt(), 0, 8f)
                setTextColor(Color.WHITE)
                setOnClickListener { onAction() }
            }
            card.addView(btn)
        } else {
            val okLabel = TextView(this).apply {
                text = "✓ الصلاحية نشطة وتعمل بكفاءة"
                textSize = 11.5f
                setTextColor(0xFF22C55E.toInt())
            }
            card.addView(okLabel)
        }

        return card
    }

    private fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
    }

    private fun hasCameraAndMicPermission(): Boolean {
        val cam = ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
        val mic = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        return cam && mic
    }

    private fun hasCallsAndSmsPermission(): Boolean {
        val call = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) == PackageManager.PERMISSION_GRANTED
        val sms = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
        val contacts = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED
        return call && sms && contacts
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
        if (AgentAccessibilityService.instance != null) return true
        val expected = ComponentName(this, AgentAccessibilityService::class.java).flattenToString()
        val enabled = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: ""
        return enabled.contains(expected)
    }

    private fun isNotificationListenerEnabled(): Boolean {
        if (AgentNotificationListener.instance != null) return true
        val listeners = NotificationManagerCompat.getEnabledListenerPackages(this)
        return listeners.contains(packageName)
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
            return pm?.isIgnoringBatteryOptimizations(packageName) ?: false
        }
        return true
    }

    private fun hasAllFilesPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            android.os.Environment.isExternalStorageManager()
        } else {
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestBatchRuntimePermissions() {
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
            perms.add(Manifest.permission.RECEIVE_SMS)
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
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_VIDEO) != PackageManager.PERMISSION_GRANTED) {
                perms.add(Manifest.permission.READ_MEDIA_VIDEO)
            }
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                perms.add(Manifest.permission.READ_MEDIA_AUDIO)
            }
        } else {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                perms.add(Manifest.permission.READ_EXTERNAL_STORAGE)
            }
        }
        if (perms.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, perms.toTypedArray(), REQUEST_PERMS_BATCH)
        } else {
            Toast.makeText(this, "جميع الصلاحيات الأساسية ممنوحة بالفعل!", Toast.LENGTH_SHORT).show()
        }
    }

    private fun requestRuntimePermissionsIfNeeded() {
        requestBatchRuntimePermissions()
    }

    private fun triggerSOSAlert() {
        val app = KidsAgentApp.instance
        if (!app.isPaired()) {
            Toast.makeText(this, "يجب إقران الجهاز أولاً لتفعيل الاستغاثة", Toast.LENGTH_SHORT).show()
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
        } catch (_: Exception) {}

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
                            Toast.makeText(this@MainActivity, "تم ربط الجهاز بالأسرة بنجاح!", Toast.LENGTH_LONG).show()
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
                            Toast.makeText(this@MainActivity, "استجابة غير صالحة من السيرفر", Toast.LENGTH_LONG).show()
                        }
                    }
                } else {
                    withContext(Dispatchers.Main) {
                        Toast.makeText(this@MainActivity, "فشل الاقتران: $respBody", Toast.LENGTH_LONG).show()
                    }
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    Toast.makeText(this@MainActivity, "خطأ في الاتصال بالشبكة: ${e.message}", Toast.LENGTH_LONG).show()
                }
            }
        }
    }
}
