package com.example.v2ray_box

import android.content.Context
import android.util.Base64
import android.util.Log
import com.example.v2ray_box.bg.ProxyService
import com.example.v2ray_box.bg.VPNService
import com.example.v2ray_box.constant.CoreEngine
import com.example.v2ray_box.constant.PerAppProxyMode
import com.example.v2ray_box.constant.ServiceMode
import com.example.v2ray_box.constant.SettingsKey
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.ObjectInputStream
import java.io.ObjectOutputStream

object Settings {

    private var applicationContext: Context? = null

    fun init(context: Context) {
        applicationContext = context.applicationContext
    }

    private val preferences by lazy {
        applicationContext!!.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    }

    private const val LIST_IDENTIFIER = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu"

    var perAppProxyMode: String
        get() = preferences.getString(SettingsKey.PER_APP_PROXY_MODE, PerAppProxyMode.OFF)!!
        set(value) = preferences.edit().putString(SettingsKey.PER_APP_PROXY_MODE, value).apply()

    val perAppProxyEnabled: Boolean
        get() = perAppProxyMode != PerAppProxyMode.OFF

    val perAppProxyList: List<String>
        get() {
            val key = if (perAppProxyMode == PerAppProxyMode.INCLUDE) {
                SettingsKey.PER_APP_PROXY_INCLUDE_LIST
            } else {
                SettingsKey.PER_APP_PROXY_EXCLUDE_LIST
            }
            val stringValue = preferences.getString(key, "")!!
            Log.d("V2Ray/Settings", "perAppProxyList: mode=$perAppProxyMode, key=$key, hasPrefix=${stringValue.startsWith(LIST_IDENTIFIER)}")
            if (!stringValue.startsWith(LIST_IDENTIFIER)) {
                return emptyList()
            }
            val list = decodeListString(stringValue.substring(LIST_IDENTIFIER.length))
            Log.d("V2Ray/Settings", "perAppProxyList: decoded ${list.size} apps")
            return list
        }

    @Suppress("UNCHECKED_CAST")
    private fun decodeListString(listString: String): List<String> {
        return try {
            val stream = ObjectInputStream(ByteArrayInputStream(Base64.decode(listString, 0)))
            stream.readObject() as List<String>
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun encodeListString(list: List<String>): String {
        return try {
            val byteStream = ByteArrayOutputStream()
            val objectStream = ObjectOutputStream(byteStream)
            objectStream.writeObject(ArrayList(list))
            objectStream.flush()
            Base64.encodeToString(byteStream.toByteArray(), Base64.NO_WRAP)
        } catch (e: Exception) {
            ""
        }
    }

    fun setPerAppProxyList(list: List<String>, mode: String) {
        val encoded = LIST_IDENTIFIER + encodeListString(list)
        val key = if (mode == PerAppProxyMode.INCLUDE) {
            SettingsKey.PER_APP_PROXY_INCLUDE_LIST
        } else {
            SettingsKey.PER_APP_PROXY_EXCLUDE_LIST
        }
        Log.d("V2Ray/Settings", "Saving ${list.size} apps to $key for mode $mode")
        preferences.edit().putString(key, encoded).apply()
    }

    fun getPerAppProxyList(mode: String): List<String> {
        val key = if (mode == PerAppProxyMode.INCLUDE) {
            SettingsKey.PER_APP_PROXY_INCLUDE_LIST
        } else {
            SettingsKey.PER_APP_PROXY_EXCLUDE_LIST
        }
        val stringValue = preferences.getString(key, "")!!
        Log.d("V2Ray/Settings", "Reading from $key for mode $mode, hasPrefix=${stringValue.startsWith(LIST_IDENTIFIER)}")
        if (!stringValue.startsWith(LIST_IDENTIFIER)) {
            return emptyList()
        }
        val list = decodeListString(stringValue.substring(LIST_IDENTIFIER.length))
        Log.d("V2Ray/Settings", "Decoded ${list.size} apps")
        return list
    }

    var activeConfigPath: String
        get() = preferences.getString(SettingsKey.ACTIVE_CONFIG_PATH, "")!!
        set(value) = preferences.edit().putString(SettingsKey.ACTIVE_CONFIG_PATH, value).apply()

    var activeProfileName: String
        get() = preferences.getString(SettingsKey.ACTIVE_PROFILE_NAME, "")!!
        set(value) = preferences.edit().putString(SettingsKey.ACTIVE_PROFILE_NAME, value).apply()

    var serviceMode: String
        get() = preferences.getString(SettingsKey.SERVICE_MODE, ServiceMode.VPN)!!
        set(value) = preferences.edit().putString(SettingsKey.SERVICE_MODE, value).apply()

    var configOptions: String
        get() = preferences.getString(SettingsKey.CONFIG_OPTIONS, "")!!
        set(value) = preferences.edit().putString(SettingsKey.CONFIG_OPTIONS, value).apply()

    var debugMode: Boolean
        get() = preferences.getBoolean(SettingsKey.DEBUG_MODE, false)
        set(value) = preferences.edit().putBoolean(SettingsKey.DEBUG_MODE, value).apply()

    var disableMemoryLimit: Boolean
        get() = preferences.getBoolean(SettingsKey.DISABLE_MEMORY_LIMIT, false)
        set(value) = preferences.edit().putBoolean(SettingsKey.DISABLE_MEMORY_LIMIT, value).apply()

    var dynamicNotification: Boolean
        get() = preferences.getBoolean(SettingsKey.DYNAMIC_NOTIFICATION, true)
        set(value) = preferences.edit().putBoolean(SettingsKey.DYNAMIC_NOTIFICATION, value).apply()

    var systemProxyEnabled: Boolean
        get() = preferences.getBoolean(SettingsKey.SYSTEM_PROXY_ENABLED, true)
        set(value) = preferences.edit().putBoolean(SettingsKey.SYSTEM_PROXY_ENABLED, value).apply()

    var startedByUser: Boolean
        get() = preferences.getBoolean(SettingsKey.STARTED_BY_USER, false)
        set(value) = preferences.edit().putBoolean(SettingsKey.STARTED_BY_USER, value).apply()

    // Notification settings
    var notificationStopButtonText: String
        get() = preferences.getString(SettingsKey.NOTIFICATION_STOP_BUTTON_TEXT, "Stop")!!
        set(value) = preferences.edit().putString(SettingsKey.NOTIFICATION_STOP_BUTTON_TEXT, value).apply()

    var notificationTitle: String
        get() = preferences.getString(SettingsKey.NOTIFICATION_TITLE, "")!!
        set(value) = preferences.edit().putString(SettingsKey.NOTIFICATION_TITLE, value).apply()

    var notificationIconName: String
        get() = preferences.getString(SettingsKey.NOTIFICATION_ICON_NAME, "")!!
        set(value) = preferences.edit().putString(SettingsKey.NOTIFICATION_ICON_NAME, value).apply()

    var pingTestUrl: String
        get() = preferences.getString(SettingsKey.PING_TEST_URL, "https://www.gstatic.com/generate_204")!!
        set(value) = preferences.edit().putString(SettingsKey.PING_TEST_URL, value).apply()

    var coreEngine: String
        get() = preferences.getString(SettingsKey.CORE_ENGINE, com.example.v2ray_box.constant.CoreEngine.XRAY)!!
        set(value) = preferences.edit().putString(SettingsKey.CORE_ENGINE, value).apply()

    var activeRuntimeEngine: String
        get() = preferences.getString(SettingsKey.ACTIVE_RUNTIME_ENGINE, "")!!
        set(value) = preferences.edit().putString(SettingsKey.ACTIVE_RUNTIME_ENGINE, value).apply()

    fun effectiveCoreEngine(): String {
        val runtime = activeRuntimeEngine.trim().lowercase()
        return if (runtime == CoreEngine.XRAY || runtime == CoreEngine.SINGBOX) {
            runtime
        } else {
            coreEngine
        }
    }

    // Traffic storage (persisted across app sessions)
    var totalUploadTraffic: Long
        get() = preferences.getLong(SettingsKey.TOTAL_UPLOAD_TRAFFIC, 0L)
        set(value) = preferences.edit().putLong(SettingsKey.TOTAL_UPLOAD_TRAFFIC, value).apply()

    var totalDownloadTraffic: Long
        get() = preferences.getLong(SettingsKey.TOTAL_DOWNLOAD_TRAFFIC, 0L)
        set(value) = preferences.edit().putLong(SettingsKey.TOTAL_DOWNLOAD_TRAFFIC, value).apply()

    // Track last known values to calculate delta
    private var lastUplinkTotal: Long = 0L
    private var lastDownlinkTotal: Long = 0L
    private var isTrackingInitialized = false

    fun updateTrafficStats(uplinkTotal: Long, downlinkTotal: Long) {
        if (!isTrackingInitialized) {
            // First update - just initialize the last values
            lastUplinkTotal = uplinkTotal
            lastDownlinkTotal = downlinkTotal
            isTrackingInitialized = true
            return
        }

        // Calculate delta (new traffic since last update)
        val uploadDelta = if (uplinkTotal >= lastUplinkTotal) {
            uplinkTotal - lastUplinkTotal
        } else {
            // Connection was reset, uplinkTotal is the new traffic
            uplinkTotal
        }

        val downloadDelta = if (downlinkTotal >= lastDownlinkTotal) {
            downlinkTotal - lastDownlinkTotal
        } else {
            // Connection was reset, downlinkTotal is the new traffic
            downlinkTotal
        }

        // Add delta to persistent storage
        if (uploadDelta > 0) {
            totalUploadTraffic += uploadDelta
        }
        if (downloadDelta > 0) {
            totalDownloadTraffic += downloadDelta
        }

        // Update last known values
        lastUplinkTotal = uplinkTotal
        lastDownlinkTotal = downlinkTotal
    }

    fun resetTrafficStats() {
        totalUploadTraffic = 0L
        totalDownloadTraffic = 0L
        lastUplinkTotal = 0L
        lastDownlinkTotal = 0L
        isTrackingInitialized = false
    }

    fun resetTrackingState() {
        lastUplinkTotal = 0L
        lastDownlinkTotal = 0L
        isTrackingInitialized = false
    }

    fun serviceClass(): Class<*> {
        return when (serviceMode) {
            ServiceMode.VPN -> VPNService::class.java
            else -> ProxyService::class.java
        }
    }

    private var currentServiceMode: String? = null

    suspend fun rebuildServiceMode(): Boolean {
        var newMode = ServiceMode.PROXY
        try {
            if (serviceMode == ServiceMode.VPN) {
                newMode = ServiceMode.VPN
            }
        } catch (_: Exception) {
        }
        if (currentServiceMode == newMode) {
            return false
        }
        currentServiceMode = newMode
        return true
    }
}
