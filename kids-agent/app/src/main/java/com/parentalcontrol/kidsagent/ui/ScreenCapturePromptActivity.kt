package com.parentalcontrol.kidsagent.ui

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Bundle
import android.util.Log
import com.parentalcontrol.kidsagent.service.ForegroundSyncService
import com.parentalcontrol.kidsagent.webrtc.MediaProjectionHolder

class ScreenCapturePromptActivity : Activity() {

    companion object {
        private const val TAG = "ScreenCapturePrompt"
        const val REQUEST_CODE_SCREEN_CAPTURE = 2002
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val mgr = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as? MediaProjectionManager
        if (mgr != null) {
            try {
                startActivityForResult(mgr.createScreenCaptureIntent(), REQUEST_CODE_SCREEN_CAPTURE)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to launch screen capture intent: ${e.message}")
                ForegroundSyncService.onScreenCapturePermissionDenied()
                finish()
            }
        } else {
            Log.e(TAG, "MediaProjectionManager not available")
            ForegroundSyncService.onScreenCapturePermissionDenied()
            finish()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_SCREEN_CAPTURE) {
            if (resultCode == RESULT_OK && data != null) {
                Log.i(TAG, "MediaProjection permission granted by user")
                MediaProjectionHolder.setProjection(data)
                ForegroundSyncService.onScreenCapturePermissionGranted(data)
            } else {
                Log.w(TAG, "MediaProjection permission denied by user")
                ForegroundSyncService.onScreenCapturePermissionDenied()
            }
        }
        finish()
    }
}
