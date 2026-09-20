package com.parentalcontrol.kidsagent.service

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.util.Log
import com.parentalcontrol.kidsagent.ui.MainActivity

/**
 * SecretCodeReceiver responds to dialer secret code: *#*#2026#*#*
 * When dialed on the child's phone, it unhides the launcher icon if needed
 * and immediately opens MainActivity.
 */
class SecretCodeReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        Log.i("SecretCodeReceiver", "Secret code 2026 received! Action: ${intent.action}")

        try {
            // Re-enable launcher component if it was hidden
            val p = context.packageManager
            val component = ComponentName(context, MainActivity::class.java)
            p.setComponentEnabledSetting(
                component,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )

            // Update preference
            val prefs = context.getSharedPreferences("security_prefs", Context.MODE_PRIVATE)
            prefs.edit().putBoolean("is_stealth_mode", false).apply()

            // Launch MainActivity
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            context.startActivity(launchIntent)
        } catch (e: Exception) {
            Log.e("SecretCodeReceiver", "Failed to launch MainActivity from secret code: ${e.message}")
        }
    }
}
