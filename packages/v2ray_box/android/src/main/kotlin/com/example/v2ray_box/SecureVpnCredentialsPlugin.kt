package com.example.v2ray_box

import com.example.v2ray_box.bg.BoxService
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SecureVpnCredentialsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
  private lateinit var channel: MethodChannel
  private var applicationContext: android.content.Context? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    applicationContext = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    applicationContext = null
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "setSessionCredentials" -> {
        val username = call.argument<String>("username")
        val password = call.argument<String>("password")
        val port = call.argument<Int>("port") ?: 1080
        SecureVpnCredentials.setSession(username, password, port)
        result.success(true)
      }

      "clearSessionCredentials" -> {
        SecureVpnCredentials.clearSession()
        applicationContext?.let { BoxService.wipeSensitiveConfigFiles(it) }
        result.success(true)
      }

      "getLocalSocksPort" -> {
        result.success(SecureVpnCredentials.getSocksPort())
      }

      else -> result.notImplemented()
    }
  }

  companion object {
    private const val CHANNEL_NAME = "secure_vpn/credentials"
  }
}
