package com.example.v2ray_box

object SecureVpnCredentials {
  @Volatile
  private var username: String? = null

  @Volatile
  private var password: String? = null

  @Volatile
  private var socksPort: Int = 1080

  fun setSession(usernameValue: String?, passwordValue: String?, port: Int) {
    username = usernameValue
    password = passwordValue
    socksPort = port
  }

  fun clearSession() {
    username = null
    password = null
    socksPort = 1080
  }

  fun getSocksPort(): Int = socksPort

  fun asEnvironment(): Map<String, String> {
    val env = mutableMapOf<String, String>()
    val user = username
    val pass = password
    if (!user.isNullOrEmpty()) {
      env["SECURE_VPN_SOCKS_USER"] = user
    }
    if (!pass.isNullOrEmpty()) {
      env["SECURE_VPN_SOCKS_PASS"] = pass
    }
    env["SECURE_VPN_SOCKS_PORT"] = socksPort.toString()
    return env
  }
}
