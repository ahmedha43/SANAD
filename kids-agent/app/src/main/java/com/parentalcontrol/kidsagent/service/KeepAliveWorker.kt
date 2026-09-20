package com.parentalcontrol.kidsagent.service

import android.content.Context
import android.util.Log
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.parentalcontrol.kidsagent.KidsAgentApp

class KeepAliveWorker(
    private val context: Context,
    workerParams: WorkerParameters
) : Worker(context, workerParams) {

    companion object {
        private const val TAG = "KeepAliveWorker"
    }

    override fun doWork(): Result {
        Log.d(TAG, "KeepAlive check executing...")

        if (KidsAgentApp.instance.isPaired()) {
            if (!ForegroundSyncService.isServiceRunning) {
                Log.w(TAG, "ForegroundSyncService was not running! Reviving service now...")
                ForegroundSyncService.start(context)
            } else {
                Log.d(TAG, "ForegroundSyncService is alive and healthy.")
            }
        }

        return Result.success()
    }
}
