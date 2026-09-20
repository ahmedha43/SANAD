package com.parentalcontrol.kidsagent.service

import android.Manifest
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.os.UserManager
import android.util.Log

/**
 * DeviceOwnerManager
 * Manages Enterprise Anti-Tamper policies, Disallowing Uninstall, Disallowing Factory Reset,
 * Disallowing Safe Boot, and permanently locking runtime permissions.
 */
object DeviceOwnerManager {
    private const val TAG = "DeviceOwnerManager"

    fun getAdminComponent(context: Context): ComponentName {
        return ComponentName(context, AgentDeviceAdminReceiver::class.java)
    }

    fun isDeviceOwner(context: Context): Boolean {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager ?: return false
        return try {
            dpm.isDeviceOwnerApp(context.packageName)
        } catch (e: Exception) {
            Log.e(TAG, "Error checking device owner: ${e.message}")
            false
        }
    }

    fun isDeviceAdminActive(context: Context): Boolean {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager ?: return false
        val admin = getAdminComponent(context)
        return dpm.isAdminActive(admin)
    }

    /**
     * Applies full enterprise restrictions if app is Device Owner.
     */
    fun applyEnterpriseRestrictions(context: Context): Boolean {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager ?: return false
        val admin = getAdminComponent(context)

        if (!isDeviceOwner(context)) {
            Log.w(TAG, "App is not Device Owner. Cannot apply enterprise lockdown.")
            return false
        }

        try {
            // 1. Block Uninstall of Kids Agent completely
            dpm.setUninstallBlocked(admin, context.packageName, true)
            Log.i(TAG, "SUCCESS: Uninstall blocked for ${context.packageName}")

            // 2. Disallow Factory Reset
            dpm.addUserRestriction(admin, UserManager.DISALLOW_FACTORY_RESET)
            Log.i(TAG, "SUCCESS: Factory Reset disallowed")

            // 3. Disallow Safe Boot (prevent booting into Safe Mode to bypass agent)
            dpm.addUserRestriction(admin, UserManager.DISALLOW_SAFE_BOOT)
            Log.i(TAG, "SUCCESS: Safe Boot disallowed")

            // 4. Disallow Remove User / Multi-user bypass
            dpm.addUserRestriction(admin, UserManager.DISALLOW_REMOVE_USER)

            // 5. Disallow Apps Control (prevents Force Stop and Clear Data from App Info)
            dpm.addUserRestriction(admin, UserManager.DISALLOW_APPS_CONTROL)

            // 6. Permanently Grant & Lock Critical Permissions
            val permissionsToLock = mutableListOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.RECORD_AUDIO,
                Manifest.permission.CAMERA,
                Manifest.permission.READ_SMS,
                Manifest.permission.RECEIVE_SMS,
                Manifest.permission.READ_CALL_LOG,
                Manifest.permission.READ_CONTACTS
            )

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                permissionsToLock.add(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                permissionsToLock.add(Manifest.permission.POST_NOTIFICATIONS)
            }

            for (perm in permissionsToLock) {
                try {
                    dpm.setPermissionGrantState(
                        admin,
                        context.packageName,
                        perm,
                        DevicePolicyManager.PERMISSION_GRANT_STATE_GRANTED
                    )
                } catch (pe: Exception) {
                    Log.w(TAG, "Could not lock permission ${perm}: ${pe.message}")
                }
            }

            Log.i(TAG, "Enterprise Anti-Tamper restrictions applied successfully!")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to apply enterprise restrictions: ${e.message}", e)
            return false
        }
    }

    /**
     * Gathers current enterprise status to report to Parent Dashboard
     */
    fun getStatusMap(context: Context): Map<String, Any> {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager
        val admin = getAdminComponent(context)
        val isDO = isDeviceOwner(context)
        val isAdmin = dpm?.isAdminActive(admin) == true

        var uninstallBlocked = false
        if (isDO && dpm != null) {
            try {
                uninstallBlocked = dpm.isUninstallBlocked(admin, context.packageName)
            } catch (e: Exception) {}
        }

        return mapOf(
            "is_device_owner" to isDO,
            "is_device_admin" to isAdmin,
            "uninstall_blocked" to uninstallBlocked,
            "package_name" to context.packageName,
            "adb_command" to "adb shell dpm set-device-owner ${context.packageName}/com.parentalcontrol.kidsagent.service.AgentDeviceAdminReceiver"
        )
    }
}
