package com.example.v2ray_box.bg

import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.os.PowerManager
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.core.content.ContextCompat
import androidx.lifecycle.MutableLiveData
import com.example.v2ray_box.Settings
import com.example.v2ray_box.V2rayBoxPlugin
import com.example.v2ray_box.constant.Action
import com.example.v2ray_box.constant.Alert
import com.example.v2ray_box.constant.CoreEngine
import com.example.v2ray_box.constant.PerAppProxyMode
import com.example.v2ray_box.constant.ServiceMode
import com.example.v2ray_box.constant.Status
import com.example.v2ray_box.utils.CommandClient
import com.example.v2ray_box.utils.CoreCompatibility
import com.example.v2ray_box.utils.SingboxConfigParser
import com.example.v2ray_box.utils.SingboxProcess
import com.example.v2ray_box.utils.XrayConfigParser
import com.example.v2ray_box.xray.XrayBridge
import com.example.v2ray_box.xray.XrayCallbackHandler
import com.example.v2ray_box.xray.XrayCoreController
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import java.io.File

class BoxService(
    private val service: Service,
    private val platformInterface: PlatformInterfaceWrapper
) : XrayCallbackHandler {

    companion object {
        private const val TAG = "V2Ray/BoxService"
        private const val XRAY_DNS_SERVER = "1.1.1.1:53"

        private var initializeOnce = false
        private var workingDir: File? = null

        private fun getWorkingDir(context: Context): File {
            if (workingDir == null) {
                workingDir = context.getExternalFilesDir(null) ?: context.filesDir
                workingDir?.mkdirs()
            }
            return workingDir!!
        }

        private fun initialize(context: Context) {
            if (initializeOnce) return
            val wDir = getWorkingDir(context)
            Log.d(TAG, "working dir: ${wDir.path}")
            XrayBridge.initCoreEnv(context, wDir.path)
            initializeOnce = true
        }

        private fun buildXrayConfigWithLibParserFallback(
            context: Context,
            configLink: String,
            proxyOnly: Boolean
        ): String {
            initialize(context)
            // Prefer libXray parser for parity with Xray-core link parsing behavior.
            val libOutbound = XrayBridge.parseFirstOutboundFromShareLink(configLink)
            if (libOutbound != null) {
                return XrayConfigParser.buildXrayConfigFromOutbound(libOutbound, proxyOnly)
            }

            // Local parser is retained as a fallback for cases not handled by libXray parser.
            val localOutbound = XrayConfigParser.parseLink(configLink)
                ?: throw IllegalArgumentException("Invalid or unsupported config link")
            return XrayConfigParser.buildXrayConfigFromOutbound(localOutbound, proxyOnly)
        }

        private fun resolveRuntimeEngineForLink(
            configLink: String,
            preferredEngine: String
        ): String {
            return CoreCompatibility.resolveEngineForLink(preferredEngine, configLink)
        }

        fun parseConfig(
            context: Context,
            configLink: String,
            debug: Boolean,
            preferredEngine: String = Settings.coreEngine
        ): String {
            return try {
                val engine = resolveRuntimeEngineForLink(configLink, preferredEngine)
                if (engine == CoreEngine.SINGBOX) {
                    SingboxConfigParser.buildSingboxConfig(configLink)
                } else {
                    buildXrayConfigWithLibParserFallback(context, configLink, proxyOnly = false)
                }
                ""
            } catch (e: Exception) {
                Log.w(TAG, "Config validation failed: ${e.message}", e)
                e.message ?: "invalid config"
            }
        }

        fun buildConfig(
            context: Context,
            configLink: String,
            preferredEngine: String = Settings.coreEngine
        ): String {
            val proxyOnly = Settings.serviceMode == ServiceMode.PROXY
            val engine = resolveRuntimeEngineForLink(configLink, preferredEngine)
            return if (engine == CoreEngine.SINGBOX) {
                SingboxConfigParser.buildSingboxConfig(configLink, !proxyOnly)
            } else {
                buildXrayConfigWithLibParserFallback(context, configLink, proxyOnly)
            }
        }

        fun writeConfigFile(
            context: Context,
            configLink: String,
            preferredEngine: String = Settings.coreEngine
        ): String {
            val wDir = getWorkingDir(context)
            val proxyOnly = Settings.serviceMode == ServiceMode.PROXY
            val engine = resolveRuntimeEngineForLink(configLink, preferredEngine)

            if (engine == CoreEngine.SINGBOX) {
                val config = SingboxConfigParser.buildSingboxConfig(configLink, false)
                val configFile = File(wDir, "singbox_config.json")
                configFile.writeText(config)
                Log.d(TAG, "Sing-box config written to: ${configFile.absolutePath}")

                if (!proxyOnly) {
                    val bridgeConfig = buildXrayTunBridge(context)
                    val bridgeFile = File(wDir, "active_config.json")
                    bridgeFile.writeText(bridgeConfig)
                    Log.d(TAG, "Xray TUN bridge config written")
                }

                return configFile.absolutePath
            } else {
                val config = buildXrayConfigWithLibParserFallback(context, configLink, proxyOnly)
                val configFile = File(wDir, "active_config.json")
                configFile.writeText(config)
                Log.d(TAG, "Config written to: ${configFile.absolutePath}")
                return configFile.absolutePath
            }
        }

        private fun buildXrayTunBridge(context: Context): String {
            val tunSettings = mutableMapOf<String, Any>(
                "name" to "xray0",
                "MTU" to 1500,
                "userLevel" to 8
            )
            val perAppMode = Settings.perAppProxyMode
            val perAppList = Settings.perAppProxyList
                .map { it.trim() }
                .filter { it.isNotEmpty() }
                .distinct()

            when (perAppMode) {
                PerAppProxyMode.INCLUDE -> {
                    if (perAppList.isNotEmpty()) {
                        tunSettings["includedPackage"] = perAppList
                    }
                }
                PerAppProxyMode.EXCLUDE -> {
                    val excludedPackages = linkedSetOf<String>()
                    excludedPackages.addAll(perAppList)
                    excludedPackages.add(context.packageName)
                    tunSettings["excludedPackage"] = excludedPackages.toList()
                }
                else -> {
                    tunSettings["excludedPackage"] = listOf(context.packageName)
                }
            }

            Log.d(
                TAG,
                "Xray bridge per-app: mode=$perAppMode include=${(tunSettings["includedPackage"] as? List<*>)?.size ?: 0} exclude=${(tunSettings["excludedPackage"] as? List<*>)?.size ?: 0}"
            )

            val config = mapOf(
                "log" to mapOf("loglevel" to if (Settings.debugMode) "debug" else "warning"),
                "inbounds" to listOf(
                    mapOf(
                        "tag" to "tun",
                        "port" to 0,
                        "protocol" to "tun",
                        "settings" to tunSettings,
                        "sniffing" to mapOf(
                            "enabled" to true,
                            "destOverride" to listOf("http", "tls")
                        )
                    )
                ),
                "outbounds" to listOf(
                    mapOf(
                        "tag" to "proxy",
                        "protocol" to "socks",
                        "settings" to mapOf(
                            "servers" to listOf(
                                mapOf(
                                    "address" to "127.0.0.1",
                                    "port" to 10808
                                )
                            )
                        )
                    ),
                    mapOf(
                        "tag" to "direct",
                        "protocol" to "freedom",
                        "settings" to mapOf("domainStrategy" to "UseIP")
                    )
                ),
                "routing" to mapOf(
                    "domainStrategy" to "AsIs",
                    "rules" to listOf(
                        mapOf(
                            "type" to "field",
                            "outboundTag" to "direct",
                            "ip" to listOf(
                                "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16",
                                "127.0.0.0/8", "fc00::/7", "fe80::/10", "::1/128"
                            )
                        )
                    )
                ),
                "policy" to mapOf(
                    "levels" to mapOf(
                        "8" to mapOf(
                            "handshake" to 4,
                            "connIdle" to 300,
                            "uplinkOnly" to 1,
                            "downlinkOnly" to 1
                        )
                    )
                )
            )
            return com.google.gson.Gson().toJson(config)
        }

        fun writeJsonConfigFile(context: Context, configJson: String): String {
            val wDir = getWorkingDir(context)
            val proxyOnly = Settings.serviceMode == ServiceMode.PROXY
            val engine = Settings.effectiveCoreEngine()

            if (engine == CoreEngine.SINGBOX) {
                val configFile = File(wDir, "singbox_config.json")
                configFile.writeText(configJson)
                Log.d(TAG, "Sing-box JSON config written to: ${configFile.absolutePath}")

                if (!proxyOnly) {
                    val bridgeConfig = buildXrayTunBridge(context)
                    val bridgeFile = File(wDir, "active_config.json")
                    bridgeFile.writeText(bridgeConfig)
                    Log.d(TAG, "Xray TUN bridge config written for sing-box JSON connect")
                }

                return configFile.absolutePath
            }

            val configFile = File(wDir, "active_config.json")
            configFile.writeText(configJson)
            Log.d(TAG, "JSON config written to: ${configFile.absolutePath}")
            return configFile.absolutePath
        }

        fun wipeSensitiveConfigFiles(context: Context) {
            val wDir = getWorkingDir(context)
            listOf("active_config.json", "singbox_config.json").forEach { name ->
                val file = File(wDir, name)
                if (file.exists()) {
                    file.writeText("")
                    file.delete()
                    Log.d(TAG, "Wiped sensitive config file: $name")
                }
            }
        }

        fun start(context: Context) {
            val intent = runBlocking {
                withContext(Dispatchers.IO) {
                    Intent(context, Settings.serviceClass())
                }
            }
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            context.sendBroadcast(
                Intent(Action.SERVICE_CLOSE).setPackage(context.packageName)
            )
        }

        fun reload(context: Context) {
            context.sendBroadcast(
                Intent(Action.SERVICE_RELOAD).setPackage(context.packageName)
            )
        }
    }

    var fileDescriptor: ParcelFileDescriptor? = null
    var coreController: XrayCoreController? = null
        private set

    private val status = MutableLiveData(Status.Stopped)
    private val binder = ServiceBinder(status)
    private val notification = ServiceNotification(status, service)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var receiverRegistered = false
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                Action.SERVICE_CLOSE -> stopService()
                Action.SERVICE_RELOAD -> serviceReload()
                PowerManager.ACTION_DEVICE_IDLE_MODE_CHANGED -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        serviceUpdateIdleMode()
                    }
                }
            }
        }
    }

    private var activeProfileName = ""

    private fun emitServiceLog(message: String, force: Boolean = false) {
        if (!force && !Settings.debugMode) return
        val trimmed = message.trim()
        if (trimmed.isEmpty()) return
        binder.broadcast {
            it.onServiceWriteLog(trimmed)
        }
    }

    @Suppress("DEPRECATION")
    private suspend fun startService() {
        try {
            if (coreController != null || SingboxProcess.isRunning || SingboxProcess.isProcessAlive) {
                Log.w(TAG, "Detected stale core state before start, forcing cleanup")
                emitServiceLog("Stale core state detected, cleaning up before start", force = true)
                stopCore(async = false, closeTun = true)
            }
            Log.d(TAG, "starting service (engine: ${Settings.effectiveCoreEngine()})")
            emitServiceLog(
                "Starting service (engine=${Settings.effectiveCoreEngine()}, mode=${Settings.serviceMode})",
                force = true
            )
            withContext(Dispatchers.Main) {
                notification.show(activeProfileName, "Starting...")
            }

            val selectedConfigPath = Settings.activeConfigPath
            if (selectedConfigPath.isBlank()) {
                emitServiceLog("Start failed: empty active config path", force = true)
                stopAndAlert(Alert.EmptyConfiguration)
                return
            }

            activeProfileName = Settings.activeProfileName

            if (!File(selectedConfigPath).exists()) {
                Log.w(TAG, "Config file not found: $selectedConfigPath")
                emitServiceLog("Start failed: config file not found", force = true)
                stopAndAlert(Alert.EmptyConfiguration, "Config file not found")
                return
            }

            withContext(Dispatchers.Main) {
                notification.show(activeProfileName, "Starting...")
                binder.broadcast {
                    it.onServiceResetLogs(listOf())
                }
            }

            DefaultNetworkMonitor.start()
            Log.d(TAG, "DefaultNetworkMonitor started")
            emitServiceLog("Network monitor started")

            val isVpnMode = Settings.serviceMode == ServiceMode.VPN
            val engine = Settings.effectiveCoreEngine()

            val started = if (engine == CoreEngine.SINGBOX) {
                startSingboxEngine(isVpnMode)
            } else {
                startXrayEngine(isVpnMode)
            }

            if (!started) return

            status.postValue(Status.Started)
            Log.d(TAG, "Service is now running (engine: $engine)")
            emitServiceLog("Service connected (engine=$engine)", force = true)

            withContext(Dispatchers.Main) {
                notification.show(activeProfileName, "Connected")
            }
            notification.start()
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected error in startService", e)
            emitServiceLog("Unexpected startService error: ${e.message}", force = true)
            stopAndAlert(Alert.StartService, e.message)
        }
    }

    private suspend fun startXrayEngine(isVpnMode: Boolean): Boolean {
        val content = File(Settings.activeConfigPath).readText()
        emitServiceLog("Starting Xray engine (vpnMode=$isVpnMode)")

        var tunFd = 0
        if (isVpnMode) {
            val pfd = platformInterface.createTun()
            if (pfd == null) {
                emitServiceLog("Xray start failed: unable to create TUN", force = true)
                stopAndAlert(Alert.StartService, "Failed to create TUN interface")
                return false
            }
            tunFd = pfd.fd
            Log.d(TAG, "TUN created with fd=$tunFd")
            emitServiceLog("TUN created with fd=$tunFd")
        }

        try {
            Log.d(TAG, "Starting Xray core...")
            if (isVpnMode) {
                XrayBridge.configureSocketProtection(
                    protectFd = { fd -> platformInterface.autoDetectInterfaceControl(fd) },
                    dnsServer = XRAY_DNS_SERVER
                )
            } else {
                XrayBridge.configureSocketProtection(null)
            }
            val controller = XrayBridge.newCoreController(this)
            controller.startLoop(content, tunFd)
            if (!waitForCoreControllerReady(controller)) {
                throw IllegalStateException("Xray core did not enter running state")
            }
            coreController = controller
            CommandClient.activeCoreController = controller
            Log.d(TAG, "Xray core started successfully")
            emitServiceLog("Xray core started successfully", force = true)
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start Xray core", e)
            emitServiceLog("Xray start failed: ${e.message}", force = true)
            platformInterface.closeTun()
            stopAndAlert(Alert.StartService, e.message)
            return false
        }
    }

    private suspend fun startSingboxEngine(isVpnMode: Boolean): Boolean {
        val singboxConfigPath = Settings.activeConfigPath
        Log.d(TAG, "Starting sing-box engine...")
        emitServiceLog("Starting sing-box engine (vpnMode=$isVpnMode)")

        if (!SingboxProcess.start(service, singboxConfigPath)) {
            emitServiceLog("sing-box start failed", force = true)
            stopAndAlert(Alert.StartService, "Failed to start sing-box process")
            return false
        }
        if (!SingboxProcess.waitForMixedInboundReady()) {
            SingboxProcess.stop()
            emitServiceLog("sing-box inbound not ready", force = true)
            stopAndAlert(Alert.StartService, "sing-box inbound not ready on 127.0.0.1:10808")
            return false
        }
        Log.d(TAG, "sing-box process started")
        emitServiceLog("sing-box process started", force = true)

        if (isVpnMode) {
            val pfd = platformInterface.createTun()
            if (pfd == null) {
                SingboxProcess.stop()
                emitServiceLog("sing-box vpn bridge failed: unable to create TUN", force = true)
                stopAndAlert(Alert.StartService, "Failed to create TUN interface")
                return false
            }
            val tunFd = pfd.fd
            Log.d(TAG, "TUN created with fd=$tunFd, starting Xray TUN bridge...")
            emitServiceLog("TUN created with fd=$tunFd for sing-box bridge")

            try {
                val wDir = getWorkingDir(service)
                val bridgeConfigFile = File(wDir, "active_config.json")
                if (!bridgeConfigFile.exists()) {
                    SingboxProcess.stop()
                    platformInterface.closeTun()
                    emitServiceLog("sing-box vpn bridge failed: bridge config missing", force = true)
                    stopAndAlert(Alert.StartService, "TUN bridge config not found")
                    return false
                }
                val bridgeContent = bridgeConfigFile.readText()
                XrayBridge.configureSocketProtection(
                    protectFd = { fd -> platformInterface.autoDetectInterfaceControl(fd) },
                    dnsServer = XRAY_DNS_SERVER
                )
                val controller = XrayBridge.newCoreController(this)
                controller.startLoop(bridgeContent, tunFd)
                if (!waitForCoreControllerReady(controller)) {
                    throw IllegalStateException("Xray TUN bridge did not enter running state")
                }
                coreController = controller
                Log.d(TAG, "Xray TUN bridge started for sing-box VPN mode")
                emitServiceLog("Xray TUN bridge started for sing-box VPN mode", force = true)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start Xray TUN bridge", e)
                SingboxProcess.stop()
                platformInterface.closeTun()
                emitServiceLog("sing-box vpn bridge failed: ${e.message}", force = true)
                stopAndAlert(Alert.StartService, "TUN bridge failed: ${e.message}")
                return false
            }
        }
        return true
    }

    fun serviceReload() {
        notification.close()
        status.postValue(Status.Starting)

        stopCore(async = false, closeTun = true)

        runBlocking {
            DefaultNetworkMonitor.stop()
            startService()
        }
    }

    private fun stopCore(async: Boolean = true, closeTun: Boolean = true) {
        val controller = coreController
        coreController = null
        CommandClient.activeCoreController = null

        if (controller != null) {
            val stopRunner = {
                try {
                    controller.stopLoop()
                } catch (e: Exception) {
                    Log.w(TAG, "Error stopping xray core", e)
                }
            }
            if (async) {
                val stopThread = Thread({
                    try {
                        stopRunner()
                    } catch (e: Exception) {
                        Log.w(TAG, "Error in async xray stop thread", e)
                    }
                }, "xray-stop-thread")
                stopThread.isDaemon = true
                stopThread.start()
            } else {
                stopRunner()
            }
        }

        if (SingboxProcess.isRunning || SingboxProcess.isProcessAlive) {
            if (async) {
                val stopThread = Thread({
                    try {
                        SingboxProcess.stop()
                        Log.d(TAG, "sing-box process stopped")
                    } catch (e: Exception) {
                        Log.w(TAG, "Error stopping sing-box process", e)
                    }
                }, "singbox-stop-thread")
                stopThread.isDaemon = true
                stopThread.start()
            } else {
                SingboxProcess.stop()
                Log.d(TAG, "sing-box process stopped")
            }
        }

        // Ensure libXray Android socket/DNS hooks are reset when service stops.
        XrayBridge.configureSocketProtection(null)

        if (closeTun) {
            platformInterface.closeTun()
            fileDescriptor = null
        }
    }

    private fun waitForCoreControllerReady(
        controller: XrayCoreController,
        timeoutMs: Long = 2500L
    ): Boolean {
        val start = System.currentTimeMillis()
        while (System.currentTimeMillis() - start < timeoutMs) {
            if (controller.isRunning) return true
            Thread.sleep(80)
        }
        return controller.isRunning
    }

    @RequiresApi(Build.VERSION_CODES.M)
    private fun serviceUpdateIdleMode() {
        V2rayBoxPlugin.powerManager?.let { pm ->
            if (pm.isDeviceIdleMode) {
                Log.d(TAG, "Device entered idle mode")
            } else {
                Log.d(TAG, "Device exited idle mode")
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun stopService() {
        if (status.value == Status.Stopped || status.value == Status.Stopping) return
        emitServiceLog("Stopping service", force = true)
        status.value = Status.Stopping
        if (receiverRegistered) {
            service.unregisterReceiver(receiver)
            receiverRegistered = false
        }
        notification.close()
        // Keep stop path fast like v2rayNG: request service stop early, then tear down cores asynchronously.
        service.stopSelf()
        // Close TUN immediately so Android removes VPN key icon as soon as possible.
        platformInterface.closeTun()
        fileDescriptor = null
        GlobalScope.launch(Dispatchers.IO) {
            stopCore(async = true, closeTun = false)
            DefaultNetworkMonitor.stop()
            emitServiceLog("Service stopped", force = true)

            Settings.startedByUser = false
            status.postValue(Status.Stopped)
        }
    }

    private suspend fun stopAndAlert(type: Alert, message: String? = null) {
        emitServiceLog("Stopping service with alert ${type.name}: ${message ?: ""}".trim(), force = true)
        Settings.startedByUser = false
        platformInterface.closeTun()
        fileDescriptor = null
        stopCore(async = true, closeTun = false)
        DefaultNetworkMonitor.stop()
        withContext(Dispatchers.Main) {
            if (receiverRegistered) {
                service.unregisterReceiver(receiver)
                receiverRegistered = false
            }
            notification.close()
            binder.broadcast { callback ->
                callback.onServiceAlert(type.ordinal, message)
            }
            status.value = Status.Stopped
            service.stopSelf()
        }
    }

    @Suppress("DEPRECATION")
    fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (status.value != Status.Stopped) return Service.START_NOT_STICKY
        status.value = Status.Starting
        emitServiceLog("onStartCommand received", force = true)

        if (!receiverRegistered) {
            ContextCompat.registerReceiver(service, receiver, IntentFilter().apply {
                addAction(Action.SERVICE_CLOSE)
                addAction(Action.SERVICE_RELOAD)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    addAction(PowerManager.ACTION_DEVICE_IDLE_MODE_CHANGED)
                }
            }, ContextCompat.RECEIVER_NOT_EXPORTED)
            receiverRegistered = true
        }

        GlobalScope.launch(Dispatchers.IO) {
            Settings.startedByUser = true
            initialize(service)
            startService()
        }
        return Service.START_NOT_STICKY
    }

    fun onBind(intent: Intent): IBinder {
        return binder
    }

    fun onDestroy() {
        emitServiceLog("Service onDestroy", force = true)
        if (receiverRegistered) {
            runCatching { service.unregisterReceiver(receiver) }
            receiverRegistered = false
        }
        notification.close()
        platformInterface.closeTun()
        fileDescriptor = null
        stopCore(async = true, closeTun = false)
        GlobalScope.launch(Dispatchers.IO) {
            DefaultNetworkMonitor.stop()
        }
        status.postValue(Status.Stopped)
        binder.close()
    }

    fun onRevoke() {
        stopService()
    }

    // CoreCallbackHandler implementation

    override fun startup(): Long {
        Log.d(TAG, "CoreCallbackHandler: startup")
        emitServiceLog("Core callback: startup", force = true)
        return 0
    }

    override fun shutdown(): Long {
        Log.d(TAG, "CoreCallbackHandler: shutdown")
        emitServiceLog("Core callback: shutdown", force = true)
        mainHandler.post {
            stopService()
        }
        return 0
    }

    override fun onEmitStatus(status: Long, message: String?): Long {
        Log.d(TAG, "CoreCallbackHandler: onEmitStatus status=$status, msg=$message")
        if (!message.isNullOrBlank()) {
            emitServiceLog("Core status[$status]: ${message.trim()}", force = true)
        } else {
            emitServiceLog("Core status[$status]")
        }
        if (message?.contains("core stopped", ignoreCase = true) == true) {
            mainHandler.post {
                stopService()
            }
        }
        return 0
    }
}
