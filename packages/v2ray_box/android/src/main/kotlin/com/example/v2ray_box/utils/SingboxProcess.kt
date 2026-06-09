package com.example.v2ray_box.utils

import android.content.Context
import android.util.Log
import com.example.v2ray_box.SecureVpnCredentials
import java.io.File
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.TimeUnit

object SingboxProcess {
    private const val TAG = "V2Ray/SingboxProcess"
    private const val MIXED_INBOUND_HOST = "127.0.0.1"
    private const val MIXED_INBOUND_PORT = 10808
    private val semverRegex = Regex("""\b(?:v)?(\d+\.\d+\.\d+(?:[-+._][0-9A-Za-z.-]+)?)\b""")
    private val versionLineRegex = Regex("""sing-box version\s+(\S+)""", RegexOption.IGNORE_CASE)
    private var process: Process? = null
    @Volatile var isRunning: Boolean = false
        private set
    val isProcessAlive: Boolean
        get() = process?.isAlive == true

    fun getBinaryPath(context: Context): String? {
        val nativeLibDir = context.applicationInfo.nativeLibraryDir
        val binary = File(nativeLibDir, "libsingbox.so")
        if (binary.exists() && binary.canExecute()) {
            return binary.absolutePath
        }
        Log.w(TAG, "sing-box binary not found at: ${binary.absolutePath}")
        return null
    }

    fun getVersion(context: Context): String {
        val binaryPath = getBinaryPath(context) ?: return ""
        return try {
            val proc = ProcessBuilder(binaryPath, "version")
                .redirectErrorStream(true)
                .start()
            val output = proc.inputStream.bufferedReader().readText().trim()
            proc.waitFor()
            normalizeVersion(output)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get sing-box version", e)
            ""
        }
    }

    private fun normalizeVersion(output: String): String {
        if (output.isBlank()) return ""

        val semver = semverRegex.find(output)?.groupValues?.getOrNull(1)
        if (!semver.isNullOrBlank()) return semver

        val fromVersionLine = versionLineRegex.find(output)?.groupValues?.getOrNull(1)
        if (!fromVersionLine.isNullOrBlank()) return fromVersionLine.removePrefix("v")

        val firstLine = output.lineSequence().firstOrNull()?.trim().orEmpty()
        if (firstLine.isBlank()) return ""
        return firstLine.removePrefix("v")
    }

    fun start(context: Context, configPath: String): Boolean {
        if (isRunning || isProcessAlive) {
            Log.w(TAG, "sing-box is already running, restarting with latest config")
            stop()
            Thread.sleep(150)
        }

        val binaryPath = getBinaryPath(context) ?: run {
            Log.e(TAG, "sing-box binary not found")
            return false
        }

        return try {
            val workDir = context.getExternalFilesDir(null) ?: context.filesDir
            Log.d(TAG, "Starting sing-box: $binaryPath run -c $configPath -D ${workDir.absolutePath}")

            val pb = ProcessBuilder(binaryPath, "run", "-c", configPath, "-D", workDir.absolutePath)
                .directory(workDir)
                .redirectErrorStream(true)
            pb.environment().putAll(SecureVpnCredentials.asEnvironment())

            val proc = pb.start()
            process = proc
            isRunning = true

            Thread {
                try {
                    proc.inputStream.bufferedReader().forEachLine { line ->
                        Log.i("SingboxCore", line)
                    }
                } catch (_: Exception) {}
            }.start()

            Thread {
                try {
                    val exitCode = proc.waitFor()
                    Log.d(TAG, "sing-box process exited with code: $exitCode")
                } catch (_: InterruptedException) {
                } finally {
                    isRunning = false
                    if (process == proc) {
                        process = null
                    }
                }
            }.start()

            Thread.sleep(500)
            if (proc.isAlive) {
                Log.d(TAG, "sing-box started successfully")
                true
            } else {
                Log.e(TAG, "sing-box process died immediately")
                isRunning = false
                process = null
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start sing-box", e)
            isRunning = false
            process = null
            false
        }
    }

    fun stop() {
        val proc = process
        if (proc == null && !isRunning) {
            return
        }
        try {
            proc?.let {
                Log.d(TAG, "Stopping sing-box process")
                it.destroy()
                val exited = runCatching {
                    it.waitFor(1200, TimeUnit.MILLISECONDS)
                }.getOrDefault(false)
                if (!exited) {
                    Log.w(TAG, "sing-box did not stop gracefully, forcing stop")
                    it.destroyForcibly()
                    runCatching { it.waitFor(1000, TimeUnit.MILLISECONDS) }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping sing-box", e)
        } finally {
            if (process == proc) {
                process = null
            }
            isRunning = false
        }
    }

    fun waitForMixedInboundReady(timeoutMs: Long = 4000L): Boolean {
        val start = System.currentTimeMillis()
        while (System.currentTimeMillis() - start < timeoutMs) {
            if (!isRunning) return false
            try {
                Socket().use { socket ->
                    socket.connect(InetSocketAddress(MIXED_INBOUND_HOST, MIXED_INBOUND_PORT), 200)
                    return true
                }
            } catch (_: Exception) {
            }
            try {
                Thread.sleep(120)
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
                return false
            }
        }
        return false
    }
}
