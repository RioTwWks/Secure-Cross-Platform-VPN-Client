package com.example.v2ray_box.bg

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.lifecycle.MutableLiveData
import com.example.v2ray_box.Settings
import com.example.v2ray_box.V2rayBoxPlugin
import com.example.v2ray_box.constant.Action
import com.example.v2ray_box.constant.Status
import com.example.v2ray_box.utils.CommandClient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.withContext

class ServiceNotification(
    private val status: MutableLiveData<Status>,
    private val service: Service
) : BroadcastReceiver(), CommandClient.Handler {

    companion object {
        private const val notificationId = 1
        private const val notificationChannel = "v2ray_box_service"
        private val flags =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0

        fun checkPermission(): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                return true
            }
            return V2rayBoxPlugin.notificationManager?.areNotificationsEnabled() ?: false
        }
    }

    @Suppress("DEPRECATION")
    private val commandClient =
        CommandClient(GlobalScope, CommandClient.ConnectionType.Status, this)
    private var receiverRegistered = false

    private val notificationBuilder by lazy {
        val context = V2rayBoxPlugin.applicationContext ?: service
        val stopButtonText = Settings.notificationStopButtonText.takeIf { it.isNotBlank() } ?: "Stop"
        val iconResId = getNotificationIcon(context)
        NotificationCompat.Builder(service, notificationChannel)
            .setShowWhen(false)
            .setOngoing(true)
            .setContentTitle("V2Ray Box")
            .setOnlyAlertOnce(true)
            .setSmallIcon(iconResId)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW).apply {
                addAction(
                    NotificationCompat.Action.Builder(
                        0, stopButtonText, PendingIntent.getBroadcast(
                            service,
                            0,
                            Intent(Action.SERVICE_CLOSE).setPackage(service.packageName),
                            flags
                        )
                    ).build()
                )
            }
    }

    private fun getNotificationIcon(context: Context): Int {
        val customIconName = Settings.notificationIconName.takeIf { it.isNotBlank() }
        if (customIconName != null) {
            val customIconResId = context.resources.getIdentifier(
                customIconName, "drawable", context.packageName
            )
            if (customIconResId != 0) {
                return customIconResId
            }
        }
        val appIconResId = context.applicationInfo.icon
        if (appIconResId != 0) {
            return appIconResId
        }
        return android.R.drawable.ic_dialog_info
    }

    fun show(profileName: String, contentText: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            V2rayBoxPlugin.notificationManager?.createNotificationChannel(
                NotificationChannel(
                    notificationChannel, "V2Ray Box Service", NotificationManager.IMPORTANCE_LOW
                )
            )
        }
        val title = Settings.notificationTitle.takeIf { it.isNotBlank() }
            ?: profileName.takeIf { it.isNotBlank() }
            ?: "V2Ray Box"
        service.startForeground(
            notificationId, notificationBuilder
                .setContentTitle(title)
                .setContentText(contentText).build()
        )
    }

    suspend fun start() {
        if (Settings.dynamicNotification) {
            commandClient.connect()
            withContext(Dispatchers.Main) {
                registerReceiver()
            }
        }
    }

    private fun registerReceiver() {
        service.registerReceiver(this, IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        })
        receiverRegistered = true
    }

    override fun updateStatus(uplink: Long, downlink: Long, uplinkTotal: Long, downlinkTotal: Long) {
        val content = formatBytes(uplink) + "/s ↑\t" + formatBytes(downlink) + "/s ↓"
        V2rayBoxPlugin.notificationManager?.notify(
            notificationId,
            notificationBuilder.setContentText(content).build()
        )
        Settings.updateTrafficStats(uplinkTotal, downlinkTotal)
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_SCREEN_ON -> commandClient.connect()
            Intent.ACTION_SCREEN_OFF -> commandClient.disconnect()
        }
    }

    fun close() {
        commandClient.disconnect()
        ServiceCompat.stopForeground(service, ServiceCompat.STOP_FOREGROUND_REMOVE)
        if (receiverRegistered) {
            service.unregisterReceiver(this)
            receiverRegistered = false
        }
        Settings.resetTrackingState()
    }

    private fun formatBytes(bytes: Long): String {
        if (bytes < 1024) return "$bytes B"
        val kb = bytes / 1024.0
        if (kb < 1024) return String.format("%.1f KB", kb)
        val mb = kb / 1024.0
        if (mb < 1024) return String.format("%.1f MB", mb)
        val gb = mb / 1024.0
        return String.format("%.2f GB", gb)
    }
}
