package com.parentalcontrol.kidsagent.service

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.parentalcontrol.kidsagent.KidsAgentApp

class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.d(TAG, "Boot event received: $action")

        if (KidsAgentApp.instance.isPaired()) {
            Log.d(TAG, "Device is paired. Starting ForegroundSyncService...")
            ForegroundSyncService.start(context)
        }
    }
}
