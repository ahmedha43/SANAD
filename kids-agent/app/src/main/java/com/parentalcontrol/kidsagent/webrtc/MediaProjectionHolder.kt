package com.parentalcontrol.kidsagent.webrtc

import android.content.Intent

object MediaProjectionHolder {
    @Volatile
    var projectionIntent: Intent? = null

    val isGranted: Boolean
        get() = projectionIntent != null

    fun setProjection(data: Intent) {
        projectionIntent = data
    }

    fun clear() {
        projectionIntent = null
    }
}
