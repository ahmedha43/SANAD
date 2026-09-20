package com.parentalcontrol.kidsagent.ui

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.view.Gravity
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

class OverlayLockActivity : AppCompatActivity() {

    private val unlockReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            finish()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Show over keyguard / lockscreen
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        )

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(0xFF0F172A.toInt())
            setPadding(60, 60, 60, 60)
        }

        val icon = TextView(this).apply {
            text = "🔒"
            textSize = 64f
            gravity = Gravity.CENTER
        }
        layout.addView(icon)

        val reason = intent.getStringExtra("EXTRA_REASON") ?: "تم قفل الجهاز بواسطة الوالدين"

        val title = TextView(this).apply {
            text = "تم قفل الجهاز بواسطة الوالدين\n(Device Locked by Parents)"
            textSize = 22f
            setTextColor(0xFFEF4444.toInt())
            gravity = Gravity.CENTER
            setPadding(0, 30, 0, 20)
        }
        layout.addView(title)

        val desc = TextView(this).apply {
            text = "$reason\n\nيرجى تسليم الهاتف لوالديك لفتحه.\n(Hand the phone to your parents to unlock)"
            textSize = 16f
            setTextColor(0xFFCBD5E1.toInt())
            gravity = Gravity.CENTER
            setLineSpacing(1.2f, 1.2f)
        }
        layout.addView(desc)

        setContentView(layout)

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(unlockReceiver, IntentFilter("ACTION_DISMISS_PARENTAL_LOCK"), Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(unlockReceiver, IntentFilter("ACTION_DISMISS_PARENTAL_LOCK"))
        }
    }

    override fun onBackPressed() {
        // Prevent dismissal by back button
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(unlockReceiver)
        } catch (e: Exception) {
            // Ignored
        }
    }
}
