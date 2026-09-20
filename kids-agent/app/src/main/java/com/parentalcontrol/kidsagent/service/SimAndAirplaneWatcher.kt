package com.parentalcontrol.kidsagent.service

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.media.ToneGenerator
import android.provider.Settings
import android.telephony.TelephonyManager
import android.util.Log

class SimAndAirplaneWatcher(private val context: Context) {
    companion object {
        private const val TAG = "SimAndAirplaneWatcher"
        private const val PREFS_SECURITY = "security_prefs"
        private const val KEY_ORIGINAL_OPERATOR = "original_sim_operator"
    }

    private var receiver: BroadcastReceiver? = null
    private var isAirplaneAlertFired = false

    fun startWatching() {
        if (receiver != null) return

        saveInitialSimInfo()

        receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                val action = intent.action ?: return
                Log.d(TAG, "Received broadcast action: $action")

                if (action == Intent.ACTION_AIRPLANE_MODE_CHANGED) {
                    checkAirplaneMode()
                } else if (action == "android.intent.action.SIM_STATE_CHANGED" ||
                    action == "android.telephony.action.SIM_CARD_STATE_CHANGED"
                ) {
                    checkSimCardChange()
                }
            }
        }

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_AIRPLANE_MODE_CHANGED)
            addAction("android.intent.action.SIM_STATE_CHANGED")
            addAction("android.telephony.action.SIM_CARD_STATE_CHANGED")
        }

        try {
            context.registerReceiver(receiver, filter)
            Log.i(TAG, "SimAndAirplaneWatcher registered successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register SimAndAirplaneWatcher: ${e.message}")
        }
    }

    fun stopWatching() {
        receiver?.let {
            try {
                context.unregisterReceiver(it)
            } catch (e: Exception) {}
            receiver = null
        }
    }

    private fun checkAirplaneMode() {
        val isAirplaneModeOn = Settings.Global.getInt(
            context.contentResolver,
            Settings.Global.AIRPLANE_MODE_ON,
            0
        ) != 0

        Log.w(TAG, "Airplane mode state changed: $isAirplaneModeOn")

        if (isAirplaneModeOn) {
            if (!isAirplaneAlertFired) {
                isAirplaneAlertFired = true
                triggerAirplaneAlert()
            }
        } else {
            isAirplaneAlertFired = false
        }
    }

    private fun triggerAirplaneAlert() {
        Log.e(TAG, "ALERT: Airplane Mode was turned ON on kid device!")

        try {
            val tone = ToneGenerator(AudioManager.STREAM_ALARM, 85)
            tone.startTone(ToneGenerator.TONE_PROP_BEEP2, 600)
        } catch (e: Exception) {}

        val payload = mapOf(
            "category" to "AIRPLANE_MODE",
            "severity" to "HIGH",
            "snippet" to "تم تفعيل وضع الطيران (Airplane Mode) على هاتف الطفل لمحاولة قطع الاتصال والمراقبة",
            "timestamp" to System.currentTimeMillis()
        )
        ForegroundSyncService.instance?.sendWsMessage("AIRPLANE_MODE_ALERT", payload)
        ForegroundSyncService.reportTamperAlert(context, "تم تفعيل وضع الطيران على هاتف الطفل لمحاولة قطع الاتصال والمراقبة", "AIRPLANE_MODE")
    }

    private fun checkSimCardChange() {
        val tm = context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager ?: return
        val currentSimState = tm.simState
        val currentOperator = tm.simOperatorName ?: ""

        val prefs = context.getSharedPreferences(PREFS_SECURITY, Context.MODE_PRIVATE)
        val originalOperator = prefs.getString(KEY_ORIGINAL_OPERATOR, null)

        if (currentSimState == TelephonyManager.SIM_STATE_ABSENT) {
            Log.e(TAG, "ALERT: SIM Card removed from device!")
            val payload = mapOf(
                "category" to "SIM_REMOVED",
                "severity" to "CRITICAL",
                "snippet" to "تمت إزالة شريحة الاتصال (SIM Card) من هاتف الطفل!",
                "operator" to "بدون شريحة",
                "timestamp" to System.currentTimeMillis()
            )
            ForegroundSyncService.instance?.sendWsMessage("SIM_SWAP_ALERT", payload)
            ForegroundSyncService.reportTamperAlert(context, "تمت إزالة شريحة الاتصال من هاتف الطفل!", "SIM_REMOVED")
            return
        }

        if (currentSimState == TelephonyManager.SIM_STATE_READY) {
            if (originalOperator != null && originalOperator.isNotEmpty() && currentOperator.isNotEmpty()) {
                if (originalOperator != currentOperator) {
                    Log.e(TAG, "ALERT: SIM Card swapped! Original: $originalOperator, Current: $currentOperator")
                    val payload = mapOf(
                        "category" to "SIM_SWAPPED",
                        "severity" to "CRITICAL",
                        "snippet" to "تم تبديل شريحة الاتصال! المشغل السابق: $originalOperator، المشغل الجديد: $currentOperator",
                        "old_operator" to originalOperator,
                        "new_operator" to currentOperator,
                        "timestamp" to System.currentTimeMillis()
                    )
                    ForegroundSyncService.instance?.sendWsMessage("SIM_SWAP_ALERT", payload)
                    ForegroundSyncService.reportTamperAlert(context, "تم تبديل شريحة الاتصال في الهاتف إلى: $currentOperator", "SIM_SWAPPED")
                }
            }
        }
    }

    private fun saveInitialSimInfo() {
        val tm = context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager ?: return
        val prefs = context.getSharedPreferences(PREFS_SECURITY, Context.MODE_PRIVATE)
        if (!prefs.contains(KEY_ORIGINAL_OPERATOR)) {
            val operator = tm.simOperatorName
            if (!operator.isNullOrEmpty()) {
                prefs.edit().putString(KEY_ORIGINAL_OPERATOR, operator).apply()
                Log.i(TAG, "Saved initial SIM operator: $operator")
            }
        }
    }
}
