package com.parentalcontrol.kidsagent.usage

import android.app.AppOpsManager
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Process
import com.parentalcontrol.kidsagent.data.model.AppItem
import com.parentalcontrol.kidsagent.data.model.DailyUsageItem
import java.text.SimpleDateFormat
import java.util.*

class UsageTracker(private val context: Context) {

    fun hasUsagePermission(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            context.packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    fun getInstalledApps(): List<AppItem> {
        val pm = context.packageManager
        val packages = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        val appList = mutableListOf<AppItem>()

        for (appInfo in packages) {
            // Ignore current app
            if (appInfo.packageName == context.packageName) continue

            val appName = pm.getApplicationLabel(appInfo).toString()
            val isSystem = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0

            appList.add(
                AppItem(
                    packageName = appInfo.packageName,
                    appName = appName,
                    isSystemApp = isSystem
                )
            )
        }

        return appList.sortedBy { it.appName }
    }

    fun getTodayUsageStats(): List<DailyUsageItem> {
        if (!hasUsagePermission()) return emptyList()

        val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return emptyList()

        val calendar = Calendar.getInstance()
        val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(calendar.time)

        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        val startOfDay = calendar.timeInMillis
        val now = System.currentTimeMillis()

        val queryUsageStats: List<UsageStats> = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            startOfDay,
            now
        ) ?: emptyList()

        val usageMap = mutableMapOf<String, Long>()
        for (stat in queryUsageStats) {
            val totalTimeSec = stat.totalTimeInForeground / 1000
            if (totalTimeSec > 0) {
                usageMap[stat.packageName] = (usageMap[stat.packageName] ?: 0L) + totalTimeSec
            }
        }

        val result = mutableListOf<DailyUsageItem>()
        for ((pkg, durationSec) in usageMap) {
            result.add(
                DailyUsageItem(
                    packageName = pkg,
                    date = todayStr,
                    usageDurationSeconds = durationSec
                )
            )
        }

        return result.sortedByDescending { it.usageDurationSeconds }
    }
}
