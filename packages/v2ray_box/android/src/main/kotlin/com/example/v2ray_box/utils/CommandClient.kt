package com.example.v2ray_box.utils

import android.net.TrafficStats
import android.util.Log
import com.example.v2ray_box.Settings
import com.example.v2ray_box.constant.CoreEngine
import com.example.v2ray_box.xray.XrayCoreController
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.net.HttpURLConnection
import java.net.URL

open class CommandClient(
    private val scope: CoroutineScope,
    private val connectionType: ConnectionType,
    private val handler: Handler
) {

    companion object {
        private const val TAG = "V2Ray/CommandClient"
        private const val POLL_INTERVAL_MS = 500L
        private const val SINGBOX_API = "http://127.0.0.1:9090"
        var activeCoreController: XrayCoreController? = null
    }

    enum class ConnectionType {
        Status, Log
    }

    interface Handler {
        fun onConnected() {}
        fun onDisconnected() {}
        fun updateStatus(uplink: Long, downlink: Long, uplinkTotal: Long, downlinkTotal: Long) {}
        fun clearLog() {}
        fun appendLogs(messages: List<String>) {}
    }

    private var pollingJob: Job? = null
    private var totalUplink = 0L
    private var totalDownlink = 0L
    private var xrayLastTxBytes = -1L
    private var xrayLastRxBytes = -1L

    fun connect() {
        disconnect()
        when (connectionType) {
            ConnectionType.Status -> startStatsPolling()
            ConnectionType.Log -> {
                handler.onConnected()
            }
        }
    }

    fun disconnect() {
        pollingJob?.cancel()
        pollingJob = null
        handler.onDisconnected()
    }

    private fun startStatsPolling() {
        pollingJob = scope.launch(Dispatchers.IO) {
            handler.onConnected()
            syncDeviceTrafficSnapshot()
            if (Settings.effectiveCoreEngine() == CoreEngine.SINGBOX && SingboxProcess.isRunning) {
                delay(1500)
                pollSingboxStats()
            } else {
                pollXrayStatsLoop()
            }
        }
    }

    private suspend fun pollXrayStatsLoop() {
        while (pollingJob?.isActive == true) {
            try {
                val controller = activeCoreController
                if (controller != null && controller.isRunning) {
                    var uplink = controller.queryStats("proxy", "uplink")
                    var downlink = controller.queryStats("proxy", "downlink")

                    if (uplink == 0L && downlink == 0L) {
                        readDeviceTrafficDelta()?.let { (txDelta, rxDelta) ->
                            uplink = txDelta
                            downlink = rxDelta
                        }
                    } else {
                        // Keep fallback baseline aligned when native stats become available again.
                        syncDeviceTrafficSnapshot()
                    }

                    totalUplink += uplink
                    totalDownlink += downlink

                    val uplinkPerSec = (uplink * 1000) / POLL_INTERVAL_MS
                    val downlinkPerSec = (downlink * 1000) / POLL_INTERVAL_MS

                    handler.updateStatus(uplinkPerSec, downlinkPerSec, totalUplink, totalDownlink)
                }
            } catch (e: Exception) {
                Log.w(TAG, "Xray stats polling error: ${e.message}")
            }
            delay(POLL_INTERVAL_MS)
        }
    }

    private var lastSingboxUpload = 0L
    private var lastSingboxDownload = 0L

    private suspend fun pollSingboxStats() {
        Log.d(TAG, "Starting sing-box stats polling via Clash API")
        var logCounter = 0
        while (pollingJob?.isActive == true) {
            try {
                val conn = URL("$SINGBOX_API/connections").openConnection() as HttpURLConnection
                conn.connectTimeout = 1000
                conn.readTimeout = 1000
                conn.requestMethod = "GET"

                val code = conn.responseCode
                if (code == 200) {
                    val body = conn.inputStream.bufferedReader().readText()
                    conn.disconnect()

                    val uploadTotal = extractJsonLong(body, "uploadTotal")
                    val downloadTotal = extractJsonLong(body, "downloadTotal")

                    if (logCounter++ % 10 == 0) {
                        Log.d(TAG, "sing-box stats: up=$uploadTotal down=$downloadTotal")
                    }

                    val uploadDelta = if (uploadTotal >= lastSingboxUpload) uploadTotal - lastSingboxUpload else uploadTotal
                    val downloadDelta = if (downloadTotal >= lastSingboxDownload) downloadTotal - lastSingboxDownload else downloadTotal

                    if (lastSingboxUpload > 0 || lastSingboxDownload > 0) {
                        totalUplink += uploadDelta
                        totalDownlink += downloadDelta
                        val uplinkPerSec = (uploadDelta * 1000) / POLL_INTERVAL_MS
                        val downlinkPerSec = (downloadDelta * 1000) / POLL_INTERVAL_MS
                        handler.updateStatus(uplinkPerSec, downlinkPerSec, totalUplink, totalDownlink)
                    }

                    lastSingboxUpload = uploadTotal
                    lastSingboxDownload = downloadTotal
                } else {
                    Log.w(TAG, "sing-box connections API returned $code")
                    conn.disconnect()
                }
            } catch (e: Exception) {
                Log.w(TAG, "sing-box stats poll error: ${e.message}")
            }
            delay(POLL_INTERVAL_MS)
        }
    }

    private fun extractJsonLong(json: String, key: String): Long {
        val pattern = "\"$key\"\\s*:\\s*(\\d+)".toRegex()
        return pattern.find(json)?.groupValues?.get(1)?.toLongOrNull() ?: 0L
    }

    private fun readDeviceTrafficTotals(): Pair<Long, Long>? {
        val tx = TrafficStats.getTotalTxBytes()
        val rx = TrafficStats.getTotalRxBytes()
        val unsupported = TrafficStats.UNSUPPORTED.toLong()
        if (tx <= unsupported || rx <= unsupported) return null
        return tx to rx
    }

    private fun syncDeviceTrafficSnapshot() {
        val totals = readDeviceTrafficTotals() ?: return
        xrayLastTxBytes = totals.first
        xrayLastRxBytes = totals.second
    }

    private fun readDeviceTrafficDelta(): Pair<Long, Long>? {
        val totals = readDeviceTrafficTotals() ?: return null
        if (xrayLastTxBytes < 0L || xrayLastRxBytes < 0L) {
            xrayLastTxBytes = totals.first
            xrayLastRxBytes = totals.second
            return 0L to 0L
        }

        val txDelta = (totals.first - xrayLastTxBytes).coerceAtLeast(0L)
        val rxDelta = (totals.second - xrayLastRxBytes).coerceAtLeast(0L)
        xrayLastTxBytes = totals.first
        xrayLastRxBytes = totals.second
        return txDelta to rxDelta
    }

    fun resetTotals() {
        totalUplink = 0L
        totalDownlink = 0L
        lastSingboxUpload = 0L
        lastSingboxDownload = 0L
        xrayLastTxBytes = -1L
        xrayLastRxBytes = -1L
    }
}
