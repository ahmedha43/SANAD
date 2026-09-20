package com.parentalcontrol.kidsagent.data.network

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.util.Log
import com.google.gson.Gson
import com.parentalcontrol.kidsagent.KidsAgentApp
import com.parentalcontrol.kidsagent.data.model.BatteryPayload
import com.parentalcontrol.kidsagent.data.model.WSMessage
import kotlinx.coroutines.*
import okhttp3.*
import java.util.concurrent.TimeUnit

class AgentWebSocketClient(
    private val context: Context,
    private val onMessageReceived: (WSMessage) -> Unit
) {
    companion object {
        private const val TAG = "AgentWSClient"
        private const val HEARTBEAT_INTERVAL_MS = 30_000L
    }

    private val gson = Gson()
    private val client = OkHttpClient.Builder()
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .pingInterval(20, TimeUnit.SECONDS)
        .build()

    private var webSocket: WebSocket? = null
    var isConnected = false
        private set
    var isConnecting = false
        private set
    private var shouldReconnect = true
    private var reconnectAttempts = 0

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var heartbeatJob: Job? = null
    private var reconnectJob: Job? = null

    @Synchronized
    fun connect() {
        if (!shouldReconnect) return
        if (isConnected || isConnecting) {
            Log.d(TAG, "Already connected or connecting, skipping connect()")
            return
        }

        val app = KidsAgentApp.instance
        val deviceId = app.prefs.getString(KidsAgentApp.KEY_DEVICE_ID, null) ?: return
        val secret = app.prefs.getString(KidsAgentApp.KEY_PAIRING_SECRET, null) ?: return
        var serverUrl = app.prefs.getString(KidsAgentApp.KEY_SERVER_URL, "ws://192.168.1.106:8080") ?: "ws://192.168.1.106:8080"

        // Convert http(s) to ws(s) if user pasted http
        serverUrl = serverUrl.replace("http://", "ws://").replace("https://", "wss://")
        val wsUrl = "$serverUrl/ws?device_id=$deviceId&device_secret=$secret"

        isConnecting = true
        reconnectJob?.cancel()
        reconnectJob = null

        Log.w(TAG, "Connecting to WebSocket: $wsUrl")

        val oldWs = webSocket
        webSocket = null
        try {
            oldWs?.cancel()
        } catch (e: Exception) {
            // Ignored
        }

        val request = Request.Builder()
            .url(wsUrl)
            .build()

        webSocket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(ws: WebSocket, response: Response) {
                if (ws != webSocket) {
                    try { ws.cancel() } catch (_: Exception) {}
                    return
                }
                Log.w(TAG, "WebSocket Connected successfully!")
                isConnecting = false
                isConnected = true
                reconnectAttempts = 0
                reconnectJob?.cancel()
                reconnectJob = null
                startHeartbeat()
            }

            override fun onMessage(ws: WebSocket, text: String) {
                if (ws != webSocket) return
                try {
                    Log.w(TAG, "Received incoming WS message: $text")
                    val msg = gson.fromJson(text, WSMessage::class.java)
                    onMessageReceived(msg)
                } catch (e: Exception) {
                    Log.e(TAG, "Error parsing incoming WS message: ${e.message}")
                }
            }

            override fun onClosed(ws: WebSocket, code: Int, reason: String) {
                if (ws != webSocket) return
                Log.w(TAG, "WebSocket Closed: $reason ($code)")
                isConnecting = false
                isConnected = false
                stopHeartbeat()
                scheduleReconnect()
            }

            override fun onFailure(ws: WebSocket, t: Throwable, response: Response?) {
                if (ws != webSocket) return
                Log.e(TAG, "WebSocket Failure: ${t.message}")
                isConnecting = false
                isConnected = false
                stopHeartbeat()
                scheduleReconnect()
            }
        })
    }

    fun sendMessage(type: String, payload: Any?): Boolean {
        if (!isConnected || webSocket == null) {
            Log.w(TAG, "Cannot send message $type: socket not connected")
            return false
        }

        val app = KidsAgentApp.instance
        val deviceId = app.prefs.getString(KidsAgentApp.KEY_DEVICE_ID, "")
        val familyId = app.prefs.getString(KidsAgentApp.KEY_FAMILY_ID, "")

        val jsonPayload = if (payload != null) gson.toJsonTree(payload) else null
        val msg = WSMessage(
            type = type,
            from = deviceId,
            familyId = familyId,
            payload = jsonPayload
        )

        val jsonStr = gson.toJson(msg)
        val sent = webSocket?.send(jsonStr) ?: false
        if (sent) {
            Log.w(TAG, "Sent WS message: $type")
        } else {
            Log.e(TAG, "Failed to send WS message: $type")
        }
        return sent
    }


    private fun startHeartbeat() {
        stopHeartbeat()
        heartbeatJob = scope.launch {
            while (isActive && isConnected) {
                sendHeartbeat()
                delay(HEARTBEAT_INTERVAL_MS)
            }
        }
    }

    private fun stopHeartbeat() {
        heartbeatJob?.cancel()
        heartbeatJob = null
    }

    private fun sendHeartbeat() {
        try {
            val batteryInfo = getBatteryStatus()
            sendMessage("HEARTBEAT_PING", batteryInfo)
        } catch (e: Exception) {
            Log.e(TAG, "Error sending heartbeat: ${e.message}")
        }
    }

    private fun getBatteryStatus(): BatteryPayload {
        var batteryPct = 100
        var isCharging = false
        try {
            val batteryStatusIntent = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED), Context.RECEIVER_NOT_EXPORTED)
            } else {
                context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            }

            val level = batteryStatusIntent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale = batteryStatusIntent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
            batteryPct = if (level >= 0 && scale > 0) (level * 100) / scale else 100

            val status = batteryStatusIntent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
            isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                         status == BatteryManager.BATTERY_STATUS_FULL
        } catch (e: Exception) {
            Log.w(TAG, "Error reading battery status: ${e.message}")
        }

        val networkType = getNetworkType()

        return BatteryPayload(
            batteryLevel = batteryPct,
            isCharging = isCharging,
            networkType = networkType
        )
    }

    private fun getNetworkType(): String {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return "UNKNOWN"
        val network = cm.activeNetwork ?: return "NONE"
        val caps = cm.getNetworkCapabilities(network) ?: return "NONE"

        return when {
            caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "WIFI"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "CELLULAR"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ETHERNET"
            else -> "OTHER"
        }
    }

    @Synchronized
    private fun scheduleReconnect() {
        if (!shouldReconnect || isConnected || isConnecting) return
        if (reconnectJob?.isActive == true) return

        reconnectJob = scope.launch {
            val backoffMs = Math.max(3000L, (Math.min(30, (1 shl Math.min(reconnectAttempts, 5))) * 1000L))
            reconnectAttempts++
            Log.d(TAG, "Scheduling reconnect attempt in ${backoffMs / 1000} seconds...")
            delay(backoffMs)
            if (shouldReconnect && !isConnected && !isConnecting) {
                connect()
            }
        }
    }

    fun disconnect() {
        shouldReconnect = false
        isConnecting = false
        reconnectJob?.cancel()
        reconnectJob = null
        stopHeartbeat()
        webSocket?.close(1000, "App closed")
        webSocket = null
        isConnected = false
    }
}
