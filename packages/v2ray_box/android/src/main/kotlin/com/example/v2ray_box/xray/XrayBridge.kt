package com.example.v2ray_box.xray

import android.content.Context
import android.util.Base64
import android.util.Log
import com.google.gson.Gson
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import go.Seq
import libXray.LibXray
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

interface XrayCallbackHandler {
    fun startup(): Long
    fun shutdown(): Long
    fun onEmitStatus(status: Long, message: String?): Long
}

object XrayBridge {
    private const val TAG = "V2Ray/XrayBridge"
    private const val TUN_FD_ENV = "xray.tun.fd"
    private const val TUN_FD_ENV_ALT = "XRAY_TUN_FD"
    private val gson = Gson()
    private val protectLogCount = AtomicLong(0L)
    @Volatile
    private var dialerControllerRef: libXray.DialerController? = null

    @Volatile
    private var workDirPath: String = ""

    fun initCoreEnv(context: Context, workDir: String) {
        workDirPath = workDir
        runCatching { File(workDirPath).mkdirs() }
        // Required by gomobile bindings on Android for proper runtime initialization.
        runCatching { Seq.setContext(context.applicationContext) }
            .onFailure { Log.w(TAG, "Seq.setContext failed: ${it.message}") }
        runCatching { LibXray.touch() }
    }

    fun newCoreController(callback: XrayCallbackHandler): XrayCoreController {
        if (workDirPath.isBlank()) {
            throw IllegalStateException("Core env not initialized. Call initCoreEnv first.")
        }
        return XrayCoreController(callback, workDirPath)
    }

    fun checkVersion(): String {
        val response = decodeCallResponse(LibXray.xrayVersion())
        return if (response.success) response.dataAsString() else ""
    }

    fun configureSocketProtection(
        protectFd: ((Int) -> Boolean)?,
        dnsServer: String? = null
    ) {
        if (protectFd == null) {
            dialerControllerRef = null
            runCatching { LibXray.resetDns() }
            return
        }
        val controller = object : libXray.DialerController {
            override fun protectFd(fd: Long): Boolean {
                val result = runCatching { protectFd(fd.toInt()) }.getOrDefault(false)
                if (protectLogCount.getAndIncrement() < 20) {
                    Log.d(TAG, "protectFd(fd=$fd) -> $result")
                }
                return result
            }
        }
        dialerControllerRef = controller
        runCatching { LibXray.registerDialerController(controller) }
            .onFailure { Log.w(TAG, "registerDialerController failed: ${it.message}") }
        runCatching { LibXray.registerListenerController(controller) }
            .onFailure { Log.w(TAG, "registerListenerController failed: ${it.message}") }
        if (!dnsServer.isNullOrBlank()) {
            runCatching { LibXray.initDns(controller, dnsServer) }
                .onFailure { Log.w(TAG, "initDns failed: ${it.message}") }
        }
    }

    fun parseFirstOutboundFromShareLink(link: String): Map<String, Any>? {
        return runCatching {
            val response = decodeCallResponse(
                LibXray.convertShareLinksToXrayJson(link.toBase64())
            )
            if (!response.success) {
                Log.w(TAG, "parseFirstOutboundFromShareLink failed: ${response.error}")
                return null
            }
            val configJson = response.dataAsString()
            if (configJson.isBlank()) return null
            val root = JsonParser.parseString(configJson).asJsonObject
            val outbounds = root.getAsJsonArray("outbounds") ?: return null
            if (outbounds.size() == 0 || !outbounds[0].isJsonObject) return null
            val normalizedAny = normalizeNumericTypes(
                gson.fromJson<Any>(outbounds[0], Any::class.java)
            )
            @Suppress("UNCHECKED_CAST")
            val outbound = (normalizedAny as? Map<String, Any>) ?: return null
            // libXray share parser stores remarks in sendThrough.
            // Keep ping/runtime outbound clean and deterministic.
            outbound.toMutableMap().apply {
                remove("sendThrough")
                if (this["tag"] == null) {
                    this["tag"] = "proxy"
                }
            }
        }.getOrElse { e ->
            Log.w(TAG, "parseFirstOutboundFromShareLink exception: ${e.message}")
            null
        }
    }

    fun measureOutboundDelay(
        configJson: String,
        testUrl: String,
        timeoutMs: Int,
        proxyUrl: String
    ): Long {
        if (workDirPath.isBlank()) return -1L

        val timeoutSec = (timeoutMs.coerceAtLeast(1000) + 999) / 1000
        invokeCoreDialMeasureDelay(configJson, testUrl, timeoutSec)?.let { return it }

        val workDir = File(workDirPath).apply { mkdirs() }
        val configFile = runCatching {
            File.createTempFile("ping_", ".json", workDir)
        }.getOrElse {
            // Fallback for environments where temp file creation fails unexpectedly.
            File(workDir, "ping_${System.nanoTime()}.json")
        }
        return try {
            configFile.writeText(configJson)
            val request = JsonObject().apply {
                addProperty("datDir", workDirPath)
                addProperty("configPath", configFile.absolutePath)
                addProperty("timeout", timeoutSec)
                addProperty("url", testUrl)
                // Ensure delay is measured through the tested outbound, not direct network.
                addProperty("proxy", proxyUrl)
            }
            val response = decodeCallResponse(
                LibXray.ping(request.toString().toBase64())
            )
            if (response.success) response.dataAsLong() else -1L
        } catch (e: Exception) {
            Log.w(TAG, "measureOutboundDelay failed: ${e.message}")
            -1L
        } finally {
            runCatching { configFile.delete() }
        }
    }

    private fun invokeCoreDialMeasureDelay(
        configJson: String,
        testUrl: String,
        timeoutSec: Int
    ): Long? {
        val candidates = LibXray::class.java.methods.filter { it.name == "measureOutboundDelay" }
        if (candidates.isEmpty()) return null

        candidates.forEach { method ->
            val paramTypes = method.parameterTypes
            val args: Array<Any> = when {
                paramTypes.size == 3 &&
                    paramTypes[0] == String::class.java &&
                    paramTypes[1] == String::class.java &&
                    (paramTypes[2] == java.lang.Long.TYPE || paramTypes[2] == java.lang.Long::class.java) ->
                    arrayOf(configJson, testUrl, timeoutSec.toLong())

                paramTypes.size == 3 &&
                    paramTypes[0] == String::class.java &&
                    paramTypes[1] == String::class.java &&
                    (paramTypes[2] == java.lang.Integer.TYPE || paramTypes[2] == java.lang.Integer::class.java) ->
                    arrayOf(configJson, testUrl, timeoutSec)

                paramTypes.size == 2 &&
                    paramTypes[0] == String::class.java &&
                    paramTypes[1] == String::class.java ->
                    arrayOf(configJson, testUrl)

                else -> return@forEach
            }

            val raw = runCatching { method.invoke(null, *args) }.getOrElse {
                Log.w(TAG, "measureOutboundDelay invoke failed: ${it.message}")
                return@forEach
            } ?: return@forEach

            when (raw) {
                is Number -> return raw.toLong()
                is String -> {
                    val response = decodeCallResponse(raw)
                    if (!response.success) {
                        Log.w(TAG, "measureOutboundDelay response error: ${response.error}")
                        return -1L
                    }
                    return response.dataAsLong()
                }
                else -> {
                    Log.w(TAG, "measureOutboundDelay returned unsupported type: ${raw::class.java.name}")
                }
            }
        }

        return null
    }
}

class XrayCoreController(
    private val callback: XrayCallbackHandler,
    private val workDirPath: String
) {
    companion object {
        private const val TAG = "V2Ray/XrayCoreController"
        private const val TUN_FD_ENV = "xray.tun.fd"
        private const val TUN_FD_ENV_ALT = "XRAY_TUN_FD"
        private const val DEFAULT_METRICS_LISTEN = "127.0.0.1:49227"
        private val coreLifecycleLock = Any()
    }

    @Volatile
    private var running = false

    @Volatile
    private var metricsListen = ""

    private val lastStats = ConcurrentHashMap<String, AtomicLong>()

    val isRunning: Boolean
        get() = running && runCatching { LibXray.getXrayState() }.getOrDefault(false)

    fun startLoop(configContent: String, _tunFd: Int) {
        callback.startup()
        try {
            synchronized(coreLifecycleLock) {
                if (runCatching { LibXray.getXrayState() }.getOrDefault(false)) {
                    runCatching { decodeCallResponse(LibXray.stopXray()) }
                }
                val tunFd = _tunFd.takeIf { it > 0 }
                val goTunApplied = setTunFdInGoRuntime(tunFd)
                if (!goTunApplied) {
                    Log.w(TAG, "libXray SetTunFd API not available; falling back to process env")
                }
                setTunFdEnv(tunFd)

                val sanitizedConfig = sanitizeConfig(configContent)
                val request = buildRunFromJsonRequest(workDirPath, sanitizedConfig)
                val response = decodeCallResponse(LibXray.runXrayFromJSON(request))
                if (!response.success) {
                    val message = response.error ?: "runXrayFromJSON failed"
                    callback.onEmitStatus(1, message)
                    throw IllegalStateException(message)
                }
                running = runCatching { LibXray.getXrayState() }.getOrDefault(true)
            }
            callback.onEmitStatus(0, "core started")
        } catch (e: Exception) {
            running = false
            setTunFdInGoRuntime(null)
            setTunFdEnv(null)
            callback.onEmitStatus(1, e.message)
            throw e
        }
    }

    fun stopLoop() {
        try {
            synchronized(coreLifecycleLock) {
                val response = decodeCallResponse(LibXray.stopXray())
                if (!response.success) {
                    Log.w(TAG, "stopXray returned error: ${response.error}")
                }
            }
        } finally {
            setTunFdInGoRuntime(null)
            setTunFdEnv(null)
            running = false
            lastStats.clear()
            callback.shutdown()
        }
    }

    fun queryStats(tag: String, direction: String): Long {
        if (!isRunning) return 0L
        if (metricsListen.isBlank()) return 0L
        return try {
            val metricsUrl = if (metricsListen.startsWith("http://") || metricsListen.startsWith("https://")) {
                "${metricsListen.trimEnd('/')}/debug/vars"
            } else {
                "http://$metricsListen/debug/vars"
            }

            val response = decodeCallResponse(LibXray.queryStats(metricsUrl.toBase64()))
            if (!response.success) return 0L

            val body = response.dataAsString()
            if (body.isBlank()) return 0L
            val total = extractTrafficTotal(body, tag, direction)
            val key = "$tag:$direction"
            val previous = lastStats.getOrPut(key) { AtomicLong(0L) }.getAndSet(total)
            (total - previous).coerceAtLeast(0L)
        } catch (e: Exception) {
            Log.w(TAG, "queryStats failed: ${e.message}")
            0L
        }
    }

    private fun sanitizeConfig(rawConfig: String): String {
        return try {
            val root = JsonParser.parseString(rawConfig).asJsonObject
            metricsListen = extractMetricsListen(root)
            // Avoid injecting metrics/stats blocks automatically.
            // Some libXray builds panic on repeated core starts when stats are re-registered.
            root.toString()
        } catch (e: Exception) {
            metricsListen = ""
            Log.w(TAG, "sanitizeConfig failed, using original config: ${e.message}")
            rawConfig
        }
    }

    private fun extractMetricsListen(root: JsonObject): String {
        if (!root.has("metrics") || !root.get("metrics").isJsonObject) return ""
        val metricsObj = root.getAsJsonObject("metrics")
        if (!metricsObj.has("listen")) return ""
        return runCatching { metricsObj.get("listen").asString.trim() }
            .getOrDefault("")
    }

    private fun extractTrafficTotal(metricsBody: String, tag: String, direction: String): Long {
        val root = JsonParser.parseString(metricsBody).asJsonObject
        if (root.has("stats") && root.get("stats").isJsonObject) {
            val stats = root.getAsJsonObject("stats")
            if (stats.has("outbound") && stats.get("outbound").isJsonObject) {
                val outbound = stats.getAsJsonObject("outbound")
                if (outbound.has(tag) && outbound.get(tag).isJsonObject) {
                    val tagStats = outbound.getAsJsonObject(tag)
                    val nestedValue = tagStats.get(direction)?.safeAsLong()
                    if (nestedValue != null) return nestedValue
                }
            }
        }

        val statsObject = if (root.has("stats") && root.get("stats").isJsonObject) {
            root.getAsJsonObject("stats")
        } else root

        val key = "outbound>>>$tag>>>traffic>>>$direction"
        val direct = statsObject.get(key)?.safeAsLong()
        if (direct != null) return direct

        var fallback = 0L
        for ((name, value) in statsObject.entrySet()) {
            if (
                name.contains("outbound>>>$tag>>>traffic>>>", ignoreCase = true) &&
                name.endsWith(direction, ignoreCase = true)
            ) {
                fallback = value.safeAsLong() ?: fallback
            }
        }
        return fallback
    }

    private fun setTunFdEnv(tunFd: Int?) {
        val value = (tunFd ?: 0).coerceAtLeast(0).toString()
        val appliedPrimary = applyProcessEnv(TUN_FD_ENV, value)
        val appliedAlt = applyProcessEnv(TUN_FD_ENV_ALT, value)
        if (!appliedPrimary && !appliedAlt) {
            // Fallback path when direct process env update is unavailable.
            runCatching {
                System.setProperty(TUN_FD_ENV, value)
                System.setProperty(TUN_FD_ENV_ALT, value)
            }.onFailure {
                Log.w(TAG, "Failed to set tun fd fallback property: ${it.message}")
            }
        }
        Log.d(TAG, "Configured tun fd env value=$value")
    }

    private fun setTunFdInGoRuntime(tunFd: Int?): Boolean {
        val value = (tunFd ?: 0).coerceAtLeast(0)
        val methods = LibXray::class.java.methods.filter { method ->
            (method.name == "setTunFd" || method.name == "setAndroidTunFd") &&
                method.parameterTypes.size == 1
        }
        if (methods.isEmpty()) return false

        var applied = false
        methods.forEach { method ->
            val parameterType = method.parameterTypes[0]
            val arg: Any = when (parameterType) {
                java.lang.Integer.TYPE, java.lang.Integer::class.java -> value
                java.lang.Long.TYPE, java.lang.Long::class.java -> value.toLong()
                java.lang.String::class.java -> value.toString()
                else -> return@forEach
            }

            runCatching {
                method.invoke(null, arg)
                applied = true
            }.onFailure {
                Log.w(TAG, "Failed invoking ${method.name}(${parameterType.simpleName}): ${it.message}")
            }
        }

        if (applied) {
            Log.d(TAG, "Configured tun fd via libXray runtime API value=$value")
        }
        return applied
    }

    private fun applyProcessEnv(name: String, value: String): Boolean {
        return runCatching {
            val osClass = Class.forName("android.system.Os")
            val setenv = osClass.getMethod(
                "setenv",
                String::class.java,
                String::class.java,
                java.lang.Boolean.TYPE
            )
            setenv.invoke(null, name, value, true)
            true
        }.getOrElse {
            Log.w(TAG, "applyProcessEnv failed for $name: ${it.message}")
            false
        }
    }

    private fun buildRunFromJsonRequest(datDir: String, configJson: String): String {
        return try {
            val method = LibXray::class.java.getMethod(
                "newXrayRunFromJSONRequest",
                String::class.java,
                String::class.java,
                String::class.java
            )
            val mphCachePath = File(datDir, "xray.mph").absolutePath
            method.invoke(null, datDir, mphCachePath, configJson) as String
        } catch (_: NoSuchMethodException) {
            val legacyMethod = LibXray::class.java.getMethod(
                "newXrayRunFromJSONRequest",
                String::class.java,
                String::class.java
            )
            legacyMethod.invoke(null, datDir, configJson) as String
        }
    }
}

private fun normalizeNumericTypes(value: Any?): Any? {
    return when (value) {
        is Map<*, *> -> {
            val out = LinkedHashMap<String, Any>()
            value.forEach { (k, v) ->
                val key = k?.toString() ?: return@forEach
                val normalized = normalizeNumericTypes(v) ?: return@forEach
                out[key] = normalized
            }
            out
        }
        is List<*> -> {
            value.mapNotNull { normalizeNumericTypes(it) }
        }
        is Double -> {
            if (!value.isFinite()) return value
            val longValue = value.toLong()
            if (value == longValue.toDouble()) {
                if (longValue in Int.MIN_VALUE.toLong()..Int.MAX_VALUE.toLong()) {
                    longValue.toInt()
                } else {
                    longValue
                }
            } else {
                value
            }
        }
        else -> value
    }
}

private data class CallResponse(
    val success: Boolean,
    val data: JsonElement?,
    val error: String?
) {
    fun dataAsString(): String {
        val element = data ?: return ""
        return when {
            element.isJsonPrimitive -> element.asJsonPrimitive.asString
            else -> element.toString()
        }
    }

    fun dataAsLong(): Long {
        val element = data ?: return -1L
        return runCatching {
            when {
                element.isJsonPrimitive -> element.asJsonPrimitive.asLong
                else -> element.toString().toLong()
            }
        }.getOrDefault(-1L)
    }
}

private fun decodeCallResponse(encoded: String): CallResponse {
    if (encoded.isBlank()) {
        return CallResponse(success = false, data = null, error = "empty response")
    }
    return try {
        val decoded = String(Base64.decode(encoded, Base64.DEFAULT), Charsets.UTF_8)
        val obj = JsonParser.parseString(decoded).asJsonObject
        CallResponse(
            success = obj.get("success")?.asBoolean ?: false,
            data = obj.get("data"),
            error = obj.get("error")?.asString
        )
    } catch (e: Exception) {
        CallResponse(success = false, data = null, error = e.message ?: "decode failed")
    }
}

private fun String.toBase64(): String {
    return Base64.encodeToString(this.toByteArray(Charsets.UTF_8), Base64.NO_WRAP)
}

private fun JsonElement.safeAsLong(): Long? {
    return runCatching {
        if (!isJsonPrimitive) return null
        asJsonPrimitive.asLong
    }.getOrNull()
}
