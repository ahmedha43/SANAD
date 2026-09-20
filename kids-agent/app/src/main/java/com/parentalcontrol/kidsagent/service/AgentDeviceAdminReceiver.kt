package com.parentalcontrol.kidsagent.service

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class AgentDeviceAdminReceiver : DeviceAdminReceiver() {
    companion object {
        private const val TAG = "AgentDeviceAdmin"
    }

    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        Log.d(TAG, "Device Admin Enabled successfully")
        DeviceOwnerManager.applyEnterpriseRestrictions(context)
    }

    override fun onProfileProvisioningComplete(context: Context, intent: Intent) {
        super.onProfileProvisioningComplete(context, intent)
        Log.d(TAG, "Device Owner Provisioning Complete")
        DeviceOwnerManager.applyEnterpriseRestrictions(context)
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        Log.w(TAG, "Device Admin Disabled")
    }
}
