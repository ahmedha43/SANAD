package com.parentalcontrol.kidsagent.service

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Toast
import com.parentalcontrol.kidsagent.ui.OverlayLockActivity

class AgentAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "AgentAccessibility"
        var instance: AgentAccessibilityService? = null
        var isAntiUninstallEnabled: Boolean = true
        var isBlockSettingsEnabled: Boolean = false
        @Volatile
        var isMonitoringPaused: Boolean = false

        private val BROWSER_PACKAGES = setOf(
            "com.android.chrome",
            "com.chrome.beta",
            "com.chrome.canary",
            "com.chrome.dev",
            "org.mozilla.firefox",
            "org.mozilla.firefox_beta",
            "org.mozilla.focus",
            "com.sec.android.app.sbrowser",
            "com.sec.android.app.sbrowser.beta",
            "com.microsoft.emmx",
            "com.opera.browser",
            "com.opera.mini.native",
            "com.opera.gx",
            "com.brave.browser",
            "com.duckduckgo.mobile.android",
            "com.transsion.phoenix",
            "com.kiwibrowser.browser",
            "com.cloudmosa.puffinFree",
            "com.vivaldi.browser",
            "com.ucmobile.intl"
        )

        private val ARABIC_DIACRITICS_REGEX = Regex("[\\u064B-\\u065F\\u0670]")

        fun normalizeArabic(input: String): String {
            if (input.isBlank()) return ""
            var text = input.lowercase()
            text = ARABIC_DIACRITICS_REGEX.replace(text, "")
            text = text.replace('أ', 'ا')
                .replace('إ', 'ا')
                .replace('آ', 'ا')
                .replace('ٱ', 'ا')
            text = text.replace('ة', 'ه')
            text = text.replace('ى', 'ي')
            return text
        }
    }

    private var currentActiveBrowserPackage: String = ""
    private var lastCapturedUrl: String = ""
    private var lastCapturedTime: Long = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        try {
            val prefs = getSharedPreferences("security_prefs", Context.MODE_PRIVATE)
            isAntiUninstallEnabled = prefs.getBoolean("anti_uninstall", true)
            isBlockSettingsEnabled = prefs.getBoolean("block_settings", false)
            isMonitoringPaused = prefs.getBoolean("is_monitoring_paused", false)
            ForegroundSyncService.loadBlockedPackages(this)
            ForegroundSyncService.loadMonitoringState(this)
            ForegroundSyncService.loadWebFilterRules(this)
        } catch (e: Exception) {
            Log.e(TAG, "Error loading security prefs: ${e.message}")
        }
        Log.i(TAG, "AgentAccessibilityService connected. AntiUninstall=$isAntiUninstallEnabled, BlockSettings=$isBlockSettingsEnabled, WebFilter=${ForegroundSyncService.isWebFilterEnabled}")
    }

    override fun onDestroy() {
        super.onDestroy()
        if (instance == this) instance = null
    }

    fun takeScreenshotSilently(callback: (android.graphics.Bitmap?, String?) -> Unit) {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            val executor = androidx.core.content.ContextCompat.getMainExecutor(this)
            takeScreenshot(
                android.view.Display.DEFAULT_DISPLAY,
                executor,
                object : TakeScreenshotCallback {
                    override fun onSuccess(screenshotResult: ScreenshotResult) {
                        try {
                            val hwBuffer = screenshotResult.hardwareBuffer
                            val colorSpace = screenshotResult.colorSpace
                            val bitmap = android.graphics.Bitmap.wrapHardwareBuffer(hwBuffer, colorSpace)
                            val softBmp = bitmap?.copy(android.graphics.Bitmap.Config.ARGB_8888, false)
                            hwBuffer.close()
                            if (softBmp != null) {
                                callback(softBmp, null)
                            } else if (bitmap != null) {
                                callback(bitmap, null)
                            } else {
                                callback(null, "فشل إنشاء صورة لقطة الشاشة من ذاكرة النظام")
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to extract screenshot bitmap: ${e.message}")
                            callback(null, "خطأ أثناء معالجة لقطة الشاشة: ${e.message}")
                        }
                    }

                    override fun onFailure(errorCode: Int) {
                        val reason = when (errorCode) {
                            1 -> "خطأ داخلي في نظام أندرويد (Internal Error)"
                            2 -> "صلاحية التقاط الشاشة غير مفعلة في خدمة الوصول (يرجى إعادة تفعيل الخدمة)"
                            3 -> "معدل طلبات سريع جداً (يرجى الانتظار بضع ثوانٍ بين اللقطات)"
                            4 -> "شاشة العرض غير متاحة أو مقفلة (Invalid Display)"
                            5 -> "النافذة غير صالحة للالتقاط حالياً (Invalid Window)"
                            else -> "فشل التقاط الشاشة برمز خطأ: $errorCode"
                        }
                        Log.e(TAG, "takeScreenshot failed with code $errorCode: $reason")
                        callback(null, reason)
                    }
                }
            )
        } else {
            callback(null, "نظام التشغيل أندرويد أقل من الإصدار 11 (API 30)، التقاط الشاشة الصامت يتطلب أندرويد 11 أو أحدث")
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (isMonitoringPaused || ForegroundSyncService.isMonitoringPaused) {
            return
        }

        val packageName = event.packageName?.toString() ?: return

        // 1. Check if application is in blocked list
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            if (ForegroundSyncService.blockedPackages.contains(packageName)) {
                Log.w(TAG, "Blocked app launched: $packageName - redirecting to HOME")
                performGlobalAction(GLOBAL_ACTION_HOME)
                Toast.makeText(
                    applicationContext,
                    "تم حظر هذا التطبيق بواسطة الوالدين\n(Blocked by Parents)",
                    Toast.LENGTH_LONG
                ).show()
                return
            }

            // 2. Block Android System Settings if enabled
            if (isBlockSettingsEnabled && packageName == "com.android.settings") {
                Log.w(TAG, "System settings accessed while BlockSettings is active. Redirecting to HOME.")
                performGlobalAction(GLOBAL_ACTION_HOME)
                Toast.makeText(
                    applicationContext,
                    "تم حظر الوصول إلى إعدادات الهاتف بواسطة الوالدين\n(Settings Blocked by Parents)",
                    Toast.LENGTH_SHORT
                ).show()
                return
            }

            // 3. Anti-Tamper & Anti-Uninstall Shield
            if (isAntiUninstallEnabled) {
                val className = event.className?.toString() ?: ""
                val text = event.text?.toString() ?: ""
                val isSettingsOrInstaller = packageName == "com.android.settings" ||
                        packageName.contains("packageinstaller") ||
                        packageName.contains("google.android.packageinstaller") ||
                        packageName.contains("vending")

                val isDevOptions = className.contains("DevelopmentSettings", ignoreCase = true) ||
                        text.contains("Developer options", ignoreCase = true) ||
                        text.contains("خيارات المطور", ignoreCase = true)

                val isOurAppMentioned = text.contains("SANAD", ignoreCase = true) ||
                        text.contains("سَنَد", ignoreCase = true) ||
                        text.contains("Kids Agent", ignoreCase = true) ||
                        text.contains("com.parentalcontrol.kidsagent", ignoreCase = true) ||
                        text.contains("الرقابة", ignoreCase = true) ||
                        text.contains("مشرف الجهاز", ignoreCase = true) ||
                        text.contains("Device admin", ignoreCase = true)

                val isTamperAction = text.contains("Uninstall", ignoreCase = true) ||
                        text.contains("إلغاء التثبيت", ignoreCase = true) ||
                        text.contains("Disable", ignoreCase = true) ||
                        text.contains("تعطيل", ignoreCase = true) ||
                        text.contains("Force stop", ignoreCase = true) ||
                        text.contains("إيقاف إجباري", ignoreCase = true) ||
                        text.contains("Clear data", ignoreCase = true) ||
                        text.contains("مسح البيانات", ignoreCase = true) ||
                        text.contains("Deactivate", ignoreCase = true) ||
                        text.contains("إلغاء التفعيل", ignoreCase = true) ||
                        text.contains("إلغاء التنشيط", ignoreCase = true)

                if (isSettingsOrInstaller && (isDevOptions || (isOurAppMentioned && isTamperAction))) {
                    Log.w(TAG, "Anti-Uninstall triggered! devOptions=$isDevOptions, tamperAction=$isTamperAction. Blocking and locking screen.")
                    performGlobalAction(GLOBAL_ACTION_HOME)

                    // Launch Full Screen Lock Overlay
                    val lockIntent = Intent(applicationContext, OverlayLockActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        putExtra("EXTRA_REASON", "محاولة إزالة أو التلاعب بتطبيق سَنَد محظورة لحمايتك!\n(Protected by SANAD)")
                    }
                    startActivity(lockIntent)

                    Toast.makeText(
                        applicationContext,
                        "تم منع محاولة إزالة أو تعطيل تطبيق سَنَد وإبلاغ ولي الأمر فوراً!\n(SANAD Protection Active)",
                        Toast.LENGTH_LONG
                    ).show()

                    // Send alert to server & parents
                    ForegroundSyncService.reportTamperAlert(
                        applicationContext,
                        "تم رصد محاولة إزالة أو التلاعب بتطبيق سَنَد في إعدادات الهاتف",
                        "ANTI_UNINSTALL"
                    )
                    return
                }
            }
        }

        // 3. Safe Browsing & URL Inspection & History Logging
        if (BROWSER_PACKAGES.contains(packageName)) {
            currentActiveBrowserPackage = packageName
            if (isMonitoringPaused || ForegroundSyncService.isMonitoringPaused) {
                return
            }

            // A. Quick check directly on event text & contentDescription
            val eventTexts = event.text?.joinToString(" ") ?: ""
            val eventDesc = event.contentDescription?.toString() ?: ""
            val quickText = "$eventTexts $eventDesc"
            if (quickText.isNotBlank()) {
                if (checkTextForBlocked(quickText)) {
                    return
                }
            }

            // B. Check event source node
            val source = event.source
            if (source != null) {
                try {
                    if (inspectAndBlockUnsafeWeb(source)) {
                        return
                    }
                } finally {
                    source.recycle()
                }
            }

            // C. Check root in active window & record history
            val root = rootInActiveWindow
            if (root != null) {
                try {
                    val wasBlocked = inspectAndBlockUnsafeWeb(root)
                    if (!wasBlocked) {
                        val pair = findBrowserUrlAndTitle(root)
                        if (pair != null) {
                            maybeRecordHistory(packageName, pair.first, pair.second, false)
                        }
                    }
                } finally {
                    root.recycle()
                }
            }
        }
    }

    private fun checkTextForBlocked(raw: String): Boolean {
        if (raw.isBlank()) return false
        val lower = raw.lowercase()
        val normalized = normalizeArabic(raw)

        // 1. Check Domains
        val domains = ForegroundSyncService.activeBlockedDomains
        if (domains.isNotEmpty()) {
            for (domain in domains) {
                if (domain.isNotBlank() && lower.contains(domain)) {
                    Log.w(TAG, "Blocked domain detected in browser: '$domain'")
                    triggerWebBlock(domain, true)
                    return true
                }
            }
        }

        // 2. Check Keywords
        val keywords = ForegroundSyncService.activeBlockedKeywords
        if (keywords.isNotEmpty()) {
            for (keyword in keywords) {
                if (keyword.isBlank()) continue
                val normKw = normalizeArabic(keyword)
                val lowerKw = keyword.lowercase()
                if (normalized.contains(normKw) || lower.contains(lowerKw)) {
                    Log.w(TAG, "Unsafe keyword detected in browser: '$keyword'")
                    triggerWebBlock(keyword, false)
                    return true
                }
            }
        }
        return false
    }

    private fun inspectAndBlockUnsafeWeb(node: AccessibilityNodeInfo?): Boolean {
        if (node == null) return false
        if (!ForegroundSyncService.isWebFilterEnabled || isMonitoringPaused || ForegroundSyncService.isMonitoringPaused) {
            return false
        }

        val rawText = node.text?.toString() ?: ""
        val rawDesc = node.contentDescription?.toString() ?: ""
        val viewId = node.viewIdResourceName ?: ""
        val combined = "$rawText $rawDesc $viewId"

        if (checkTextForBlocked(combined)) {
            return true
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                val blocked = inspectAndBlockUnsafeWeb(child)
                child.recycle()
                if (blocked) return true
            }
        }
        return false
    }

    private fun triggerWebBlock(target: String, isDomain: Boolean) {
        performGlobalAction(GLOBAL_ACTION_HOME)
        val msg = if (isDomain) {
            "تم حظر موقع ($target) لحمايتك بواسطة منظومة سَنَد\n(Protected by SANAD)"
        } else {
            "تم حظر البحث عن ($target) لحمايتك بواسطة منظومة سَنَد\n(Protected by SANAD)"
        }
        Toast.makeText(applicationContext, msg, Toast.LENGTH_LONG).show()

        // Report alert to parents & server
        try {
            val alertDesc = if (isDomain) {
                "تم منع محاولة فتح موقع محظور: $target"
            } else {
                "تم منع محاولة البحث عن عبارة محظورة: $target"
            }
            ForegroundSyncService.reportTamperAlert(
                applicationContext,
                alertDesc,
                "WEB_FILTER_BLOCKED"
            )
            maybeRecordHistory(currentActiveBrowserPackage, target, alertDesc, true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to report web filter alert: ${e.message}")
        }
    }

    private fun findBrowserUrlAndTitle(node: AccessibilityNodeInfo?): Pair<String, String>? {
        if (node == null) return null

        var foundUrl: String? = null
        var foundTitle: String? = null

        fun traverse(n: AccessibilityNodeInfo?) {
            if (n == null || (foundUrl != null && foundTitle != null)) return

            val text = n.text?.toString()?.trim() ?: ""
            val viewId = n.viewIdResourceName?.lowercase() ?: ""

            val isUrlBar = viewId.contains("url_bar") ||
                    viewId.contains("location_bar") ||
                    viewId.contains("search_box") ||
                    viewId.contains("mozac_browser_toolbar") ||
                    viewId.contains("toolbar")

            if (isUrlBar && text.isNotBlank()) {
                foundUrl = text
            } else if (foundUrl == null && (text.startsWith("http://") || text.startsWith("https://") ||
                        (text.contains(".") && !text.contains(" ") && (text.contains(".com") || text.contains(".org") || text.contains(".net") || text.contains(".io") || text.contains(".edu") || text.contains(".gov") || text.contains(".me"))))) {
                foundUrl = text
            }

            if (foundTitle == null && text.isNotBlank() && !isUrlBar && text != foundUrl && text.length > 3) {
                foundTitle = text
            }

            for (i in 0 until n.childCount) {
                val child = n.getChild(i)
                if (child != null) {
                    traverse(child)
                    child.recycle()
                }
            }
        }

        traverse(node)
        return if (!foundUrl.isNullOrBlank()) Pair(foundUrl!!, foundTitle ?: foundUrl!!) else null
    }

    private fun maybeRecordHistory(packageName: String, url: String, title: String, isBlocked: Boolean = false) {
        val now = System.currentTimeMillis()
        if (url.isNotBlank() && (url != lastCapturedUrl || (now - lastCapturedTime) > 25000)) {
            lastCapturedUrl = url
            lastCapturedTime = now

            val browserName = when {
                packageName.contains("chrome") -> "Chrome"
                packageName.contains("firefox") -> "Firefox"
                packageName.contains("emmx") || packageName.contains("edge") -> "Edge"
                packageName.contains("sbrowser") -> "Samsung Browser"
                packageName.contains("opera") -> "Opera"
                packageName.contains("brave") -> "Brave"
                else -> "Android Browser"
            }

            ForegroundSyncService.recordBrowserVisit(applicationContext, browserName, url, title, isBlocked)
        }
    }

    override fun onInterrupt() {
        Log.w(TAG, "Accessibility Service interrupted")
    }
}
