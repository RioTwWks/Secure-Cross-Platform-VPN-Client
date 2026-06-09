package com.example.v2ray_box.utils

import android.net.Uri
import android.util.Log
import com.example.v2ray_box.Settings
import com.google.gson.Gson
import com.google.gson.GsonBuilder
import java.net.URLDecoder

object XrayConfigParser {
    private const val TAG = "V2Ray/XrayConfigParser"
    private const val XRAY_USER_LEVEL = 8
    private val gson: Gson = GsonBuilder().setPrettyPrinting().disableHtmlEscaping().create()

    fun buildXrayConfig(link: String, proxyOnly: Boolean = false): String {
        val outbound = parseLink(link) ?: throw Exception("Invalid or unsupported config link")
        return buildXrayConfigFromOutbound(outbound, proxyOnly)
    }

    fun buildXrayConfigFromOutbound(
        outboundInput: Map<String, Any>,
        proxyOnly: Boolean = false
    ): String {
        val outbound = outboundInput.toMutableMap()
        if (outbound["tag"] == null || outbound["tag"].toString().isBlank()) {
            outbound["tag"] = "proxy"
        }
        if (!outbound.containsKey("mux")) {
            outbound["mux"] = mapOf("enabled" to false)
        }

        val socksPort = 10808
        val httpPort = 10809

        val inbounds = mutableListOf<Map<String, Any>>(
            mapOf(
                "tag" to "socks",
                "port" to socksPort,
                "listen" to "127.0.0.1",
                "protocol" to "socks",
                "sniffing" to mapOf(
                    "enabled" to true,
                    "destOverride" to listOf("http", "tls")
                ),
                "settings" to mapOf(
                    "auth" to "noauth",
                    "udp" to true,
                    "userLevel" to XRAY_USER_LEVEL
                )
            )
        )

        if (proxyOnly) {
            inbounds.add(
                mapOf(
                    "tag" to "http",
                    "port" to httpPort,
                    "listen" to "127.0.0.1",
                    "protocol" to "http",
                    "sniffing" to mapOf(
                        "enabled" to true,
                        "destOverride" to listOf("http", "tls")
                    ),
                    "settings" to mapOf<String, Any>()
                )
            )
        } else {
            inbounds.add(
                mapOf(
                    "tag" to "tun",
                    "port" to 0,
                    "protocol" to "tun",
                    "settings" to mapOf(
                        "name" to "xray0",
                        "MTU" to 1500,
                        "userLevel" to XRAY_USER_LEVEL
                    ),
                    "sniffing" to mapOf(
                        "enabled" to true,
                        "destOverride" to listOf("http", "tls")
                    )
                )
            )
        }

        val config = mutableMapOf<String, Any>(
            "log" to mapOf("loglevel" to if (Settings.debugMode) "debug" else "warning"),
            "policy" to buildPolicy(),
            "dns" to buildDns(),
            "inbounds" to inbounds,
            "outbounds" to listOf(
                outbound,
                mapOf(
                    "tag" to "direct",
                    "protocol" to "freedom",
                    "settings" to mapOf("domainStrategy" to "UseIP")
                ),
                mapOf(
                    "tag" to "block",
                    "protocol" to "blackhole",
                    "settings" to mapOf("response" to mapOf("type" to "http"))
                )
            ),
            "routing" to buildRouting()
        )

        return gson.toJson(config)
    }

    fun parseLink(link: String): Map<String, Any>? {
        val rawLink = link.trim()
        return try {
            when {
                rawLink.startsWith("vless://", ignoreCase = true) -> parseVless(rawLink)
                rawLink.startsWith("vmess://", ignoreCase = true) -> parseVmess(rawLink)
                rawLink.startsWith("trojan://", ignoreCase = true) -> parseTrojan(rawLink)
                rawLink.startsWith("ss://", ignoreCase = true) -> parseShadowsocks(rawLink)
                rawLink.startsWith("wg://", ignoreCase = true) ||
                    rawLink.startsWith("wireguard://", ignoreCase = true) -> parseWireGuard(rawLink)
                else -> null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse link: ${e.message}", e)
            null
        }
    }

    private fun buildDns(): Map<String, Any> {
        return mapOf(
            "hosts" to emptyMap<String, Any>(),
            "servers" to emptyList<Any>()
        )
    }

    private fun buildRouting(): Map<String, Any> {
        return mapOf(
            "domainStrategy" to "AsIs",
            "rules" to emptyList<Any>()
        )
    }

    private fun buildPolicy(): Map<String, Any> {
        return mapOf(
            "levels" to mapOf(
                "8" to mapOf(
                    "handshake" to 4,
                    "connIdle" to 300,
                    "uplinkOnly" to 1,
                    "downlinkOnly" to 1
                )
            ),
            "system" to mapOf(
                "statsOutboundUplink" to true,
                "statsOutboundDownlink" to true
            )
        )
    }

    private fun parseQueryParams(uri: Uri): Map<String, String> {
        val params = mutableMapOf<String, String>()
        uri.query?.split("&")?.forEach { param ->
            val parts = param.split("=", limit = 2)
            if (parts.size == 2) {
                params[parts[0]] = URLDecoder.decode(parts[1], "UTF-8")
            } else if (parts.size == 1) {
                params[parts[0]] = ""
            }
        }
        return params
    }

    private fun getParam(params: Map<String, String>, key: String): String? {
        return params[key]?.trim()?.takeIf { it.isNotEmpty() }
            ?: params[key.lowercase()]?.trim()?.takeIf { it.isNotEmpty() }
            ?: params.entries.firstOrNull { it.key.equals(key, ignoreCase = true) }
                ?.value
                ?.trim()
                ?.takeIf { it.isNotEmpty() }
    }

    private fun isDomainLike(value: String?): Boolean {
        if (value.isNullOrBlank()) return false
        return value.any { it.isLetter() }
    }

    private fun parseFlexibleBool(value: String?): Boolean? {
        return when (value?.trim()?.lowercase()) {
            "1", "true", "yes", "on" -> true
            "0", "false", "no", "off" -> false
            else -> null
        }
    }

    private fun resolveSecurity(params: Map<String, String>, vmessJson: Map<*, *>? = null): String? {
        val explicit = getParam(params, "security")?.lowercase()
        if (!explicit.isNullOrBlank()) {
            return if (explicit == "none") null else explicit
        }
        if (vmessJson?.get("tls")?.toString() == "tls") return "tls"
        if (!getParam(params, "pbk").isNullOrBlank() || !getParam(params, "sid").isNullOrBlank()) {
            return "reality"
        }
        val hasTlsHints = listOf(
            "sni", "peer", "alpn", "fp", "fingerprint", "allowInsecure", "insecure"
        ).any { !getParam(params, it).isNullOrBlank() }
        return if (hasTlsHints) "tls" else null
    }

    private fun buildStreamSettings(
        params: Map<String, String>,
        vmessJson: Map<*, *>? = null,
        defaultServerName: String? = null
    ): Map<String, Any> {
        val stream = mutableMapOf<String, Any>()
        var transportSniCandidate: String? = null
        val networkTypeRaw = getParam(params, "type") ?: vmessJson?.get("net")?.toString() ?: "tcp"
        val networkType = when (networkTypeRaw.lowercase()) {
            "websocket" -> "ws"
            "mkcp" -> "kcp"
            "http2" -> "h2"
            "http-upgrade" -> "httpupgrade"
            "split-http" -> "xhttp"
            else -> networkTypeRaw.lowercase()
        }
        stream["network"] = networkType

        val resolvedSecurity = resolveSecurity(params, vmessJson)
        val security = resolvedSecurity ?: "none"
        stream["security"] = security

        when (networkType) {
            "tcp" -> {
                val headerType = (getParam(params, "headerType")
                    ?: getParam(params, "header-type")
                    ?: vmessJson?.get("type")?.toString()
                    ?: "none").lowercase()
                val host = getParam(params, "host") ?: vmessJson?.get("host")?.toString()
                if (!host.isNullOrEmpty()) {
                    transportSniCandidate = host.split(",").firstOrNull()?.trim()?.takeIf { it.isNotEmpty() }
                }

                val tcpHeader = mutableMapOf<String, Any>("type" to headerType)
                if (headerType == "http") {
                    val hostList = host
                        ?.split(",")
                        ?.map { it.trim() }
                        ?.filter { it.isNotEmpty() }
                    val pathList = (getParam(params, "path") ?: vmessJson?.get("path")?.toString())
                        ?.split(",")
                        ?.map { it.trim() }
                        ?.filter { it.isNotEmpty() }
                        ?.ifEmpty { listOf("/") }
                        ?: listOf("/")

                    val requestHeaders = mutableMapOf<String, Any>(
                        "User-Agent" to listOf(
                            "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.6478.122 Mobile Safari/537.36"
                        ),
                        "Accept-Encoding" to listOf("gzip, deflate"),
                        "Connection" to listOf("keep-alive"),
                        "Pragma" to "no-cache"
                    )
                    if (!hostList.isNullOrEmpty()) {
                        requestHeaders["Host"] = hostList
                    }

                    tcpHeader["request"] = mapOf(
                        "version" to "1.1",
                        "method" to "GET",
                        "path" to pathList,
                        "headers" to requestHeaders
                    )
                }

                stream["tcpSettings"] = mapOf("header" to tcpHeader)
            }
            "ws", "websocket" -> {
                val wsSettings = mutableMapOf<String, Any>()
                val path = getParam(params, "path") ?: vmessJson?.get("path")?.toString() ?: "/"
                wsSettings["path"] = path
                val host = getParam(params, "host") ?: vmessJson?.get("host")?.toString()
                if (!host.isNullOrEmpty()) {
                    wsSettings["headers"] = mapOf("Host" to host)
                    transportSniCandidate = host
                }
                stream["wsSettings"] = wsSettings
            }
            "grpc" -> {
                val grpcSettings = mutableMapOf<String, Any>()
                val sn = getParam(params, "serviceName") ?: getParam(params, "service-name")
                    ?: vmessJson?.get("path")?.toString()
                if (!sn.isNullOrEmpty()) grpcSettings["serviceName"] = sn
                getParam(params, "mode")?.let { mode ->
                    if (mode == "multi") grpcSettings["multiMode"] = true
                }
                getParam(params, "authority")?.let {
                    grpcSettings["authority"] = it
                    transportSniCandidate = it
                }
                stream["grpcSettings"] = grpcSettings
            }
            "h2", "http" -> {
                val httpSettings = mutableMapOf<String, Any>()
                val path = getParam(params, "path") ?: vmessJson?.get("path")?.toString()
                if (!path.isNullOrEmpty()) httpSettings["path"] = path
                val host = getParam(params, "host") ?: vmessJson?.get("host")?.toString()
                if (!host.isNullOrEmpty()) {
                    val hostList = host.split(",").map { it.trim() }.filter { it.isNotEmpty() }
                    httpSettings["host"] = hostList
                    transportSniCandidate = hostList.firstOrNull()
                }
                stream["httpSettings"] = httpSettings
                stream["network"] = "h2"
            }
            "httpupgrade" -> {
                val huSettings = mutableMapOf<String, Any>()
                val path = getParam(params, "path") ?: vmessJson?.get("path")?.toString()
                if (!path.isNullOrEmpty()) huSettings["path"] = path
                val host = getParam(params, "host") ?: vmessJson?.get("host")?.toString()
                if (!host.isNullOrEmpty()) {
                    huSettings["host"] = host
                    transportSniCandidate = host
                }
                stream["httpupgradeSettings"] = huSettings
            }
            "splithttp", "xhttp" -> {
                val xhttpSettings = mutableMapOf<String, Any>()
                val path = getParam(params, "path") ?: vmessJson?.get("path")?.toString()
                if (!path.isNullOrEmpty()) xhttpSettings["path"] = path
                val host = getParam(params, "host") ?: vmessJson?.get("host")?.toString()
                if (!host.isNullOrEmpty()) {
                    xhttpSettings["host"] = host
                    transportSniCandidate = host
                }
                getParam(params, "mode")?.let { xhttpSettings["mode"] = it }
                stream["xhttpSettings"] = xhttpSettings
                stream["network"] = "xhttp"
            }
            "quic" -> {
                val quicSettings = mutableMapOf<String, Any>(
                    "security" to (getParam(params, "quicSecurity") ?: "none"),
                    "header" to mapOf("type" to (getParam(params, "headerType") ?: "none"))
                )
                getParam(params, "key")?.let { quicSettings["key"] = it }
                stream["quicSettings"] = quicSettings
            }
            "kcp", "mkcp" -> {
                val kcpSettings = mutableMapOf<String, Any>(
                    "header" to mapOf("type" to (getParam(params, "headerType") ?: "none"))
                )
                getParam(params, "seed")?.let { kcpSettings["seed"] = it }
                stream["kcpSettings"] = kcpSettings
                stream["network"] = "kcp"
            }
        }

        when (security) {
            "tls" -> {
                val tlsSettings = mutableMapOf<String, Any>()
                val sni = getParam(params, "sni")
                    ?: getParam(params, "peer")
                    ?: vmessJson?.get("sni")?.toString()?.trim()?.takeIf { it.isNotEmpty() }
                    ?: transportSniCandidate?.takeIf { isDomainLike(it) }
                    ?: defaultServerName?.takeIf { isDomainLike(it) }
                if (!sni.isNullOrEmpty()) tlsSettings["serverName"] = sni
                val alpn = getParam(params, "alpn") ?: vmessJson?.get("alpn")?.toString()
                if (!alpn.isNullOrEmpty()) {
                    tlsSettings["alpn"] = alpn.split(",").map { it.trim() }
                }
                val fp = getParam(params, "fp") ?: getParam(params, "fingerprint")
                if (!fp.isNullOrEmpty()) tlsSettings["fingerprint"] = fp
                parseFlexibleBool(getParam(params, "allowInsecure") ?: getParam(params, "insecure"))?.let {
                    if (it) tlsSettings["allowInsecure"] = true
                }
                stream["tlsSettings"] = tlsSettings
            }
            "reality" -> {
                val realitySettings = mutableMapOf<String, Any>()
                val sni = getParam(params, "sni")
                    ?: getParam(params, "peer")
                    ?: transportSniCandidate?.takeIf { isDomainLike(it) }
                    ?: defaultServerName?.takeIf { isDomainLike(it) }
                if (!sni.isNullOrEmpty()) realitySettings["serverName"] = sni
                val fp = getParam(params, "fp") ?: getParam(params, "fingerprint") ?: "chrome"
                realitySettings["fingerprint"] = fp
                getParam(params, "pbk")?.let { realitySettings["publicKey"] = it }
                getParam(params, "sid")?.let { realitySettings["shortId"] = it }
                getParam(params, "spx")?.let { realitySettings["spiderX"] = it }
                stream["realitySettings"] = realitySettings
            }
        }

        return stream
    }

    // ========== Protocol Parsers ==========

    private fun parseVless(link: String): Map<String, Any> {
        val uri = Uri.parse(link)
        val uuid = uri.userInfo ?: throw Exception("Invalid vless link: no UUID")
        val server = uri.host ?: throw Exception("Invalid vless link: no server")
        val port = uri.port.takeIf { it > 0 } ?: 443
        val params = parseQueryParams(uri)

        val user = mutableMapOf<String, Any>(
            "id" to uuid,
            "encryption" to (getParam(params, "encryption") ?: "none"),
            "level" to XRAY_USER_LEVEL
        )
        params["flow"]?.takeIf { it.isNotEmpty() }?.let { user["flow"] = it }

        val outbound = mutableMapOf<String, Any>(
            "tag" to "proxy",
            "protocol" to "vless",
            "settings" to mapOf(
                "vnext" to listOf(
                    mapOf(
                        "address" to server,
                        "port" to port,
                        "users" to listOf(user)
                    )
                )
            ),
            "streamSettings" to buildStreamSettings(params, defaultServerName = server)
        )

        return outbound
    }

    private fun parseVmess(link: String): Map<String, Any> {
        val encoded = link.removePrefix("vmess://")
        val decoded = try {
            android.util.Base64.decode(encoded, android.util.Base64.DEFAULT).toString(Charsets.UTF_8)
        } catch (e: Exception) {
            return parseVmessUrl(link)
        }

        if (!decoded.trimStart().startsWith("{")) return parseVmessUrl(link)

        @Suppress("UNCHECKED_CAST")
        val json = gson.fromJson(decoded, Map::class.java) as Map<String, Any?>
        val server = json["add"]?.toString() ?: throw Exception("Invalid vmess: no server")
        val port = json["port"]?.toString()?.toDoubleOrNull()?.toInt() ?: 443
        val uuid = json["id"]?.toString() ?: throw Exception("Invalid vmess: no id")
        val aid = json["aid"]?.toString()?.toDoubleOrNull()?.toInt() ?: 0
        val security = json["scy"]?.toString()?.takeIf { it.isNotEmpty() } ?: "auto"

        val user = mutableMapOf<String, Any>(
            "id" to uuid,
            "alterId" to aid,
            "security" to security,
            "level" to XRAY_USER_LEVEL
        )

        val params = mutableMapOf<String, String>()
        json["net"]?.toString()?.let { params["type"] = it }
        if (json["tls"]?.toString() == "tls") params["security"] = "tls"
        json["sni"]?.toString()?.let { params["sni"] = it }
        json["alpn"]?.toString()?.let { params["alpn"] = it }
        json["fp"]?.toString()?.let { params["fp"] = it }
        json["path"]?.toString()?.let { params["path"] = it }
        json["host"]?.toString()?.let { params["host"] = it }
        json["type"]?.toString()?.let { params["headerType"] = it }

        val outbound = mutableMapOf<String, Any>(
            "tag" to "proxy",
            "protocol" to "vmess",
            "settings" to mapOf(
                "vnext" to listOf(
                    mapOf(
                        "address" to server,
                        "port" to port,
                        "users" to listOf(user)
                    )
                )
            ),
            "streamSettings" to buildStreamSettings(params, json, defaultServerName = server)
        )

        return outbound
    }

    private fun parseVmessUrl(link: String): Map<String, Any> {
        val uri = Uri.parse(link)
        val uuid = uri.userInfo ?: throw Exception("Invalid vmess link")
        val server = uri.host ?: throw Exception("Invalid vmess link")
        val port = uri.port.takeIf { it > 0 } ?: 443
        val params = parseQueryParams(uri)

        val user = mutableMapOf<String, Any>(
            "id" to uuid,
            "alterId" to 0,
            "security" to "auto",
            "level" to XRAY_USER_LEVEL
        )

        val outbound = mutableMapOf<String, Any>(
            "tag" to "proxy",
            "protocol" to "vmess",
            "settings" to mapOf(
                "vnext" to listOf(
                    mapOf(
                        "address" to server,
                        "port" to port,
                        "users" to listOf(user)
                    )
                )
            ),
            "streamSettings" to buildStreamSettings(params, defaultServerName = server)
        )

        return outbound
    }

    private fun parseTrojan(link: String): Map<String, Any> {
        val uri = Uri.parse(link)
        val password = uri.userInfo ?: throw Exception("Invalid trojan link: no password")
        val server = uri.host ?: throw Exception("Invalid trojan link: no server")
        val port = uri.port.takeIf { it > 0 } ?: 443
        val params = parseQueryParams(uri)

        val tlsParams = params.toMutableMap()
        if (tlsParams["security"].isNullOrBlank()) {
            tlsParams["security"] = "tls"
        }

        val outbound = mutableMapOf<String, Any>(
            "tag" to "proxy",
            "protocol" to "trojan",
            "settings" to mapOf(
                "servers" to listOf(
                    mapOf(
                        "address" to server,
                        "port" to port,
                        "password" to password,
                        "level" to XRAY_USER_LEVEL
                    )
                )
            ),
            "streamSettings" to buildStreamSettings(tlsParams, defaultServerName = server)
        )

        return outbound
    }

    private fun parseShadowsocks(link: String): Map<String, Any> {
        val withoutPrefix = link.removePrefix("ss://")
        val fragmentIndex = withoutPrefix.lastIndexOf("#")
        val linkPart = if (fragmentIndex > 0) withoutPrefix.substring(0, fragmentIndex) else withoutPrefix

        val queryIndex = linkPart.indexOf("?")
        val mainPart = if (queryIndex > 0) linkPart.substring(0, queryIndex) else linkPart
        val queryString = if (queryIndex > 0) linkPart.substring(queryIndex + 1) else ""

        val params = mutableMapOf<String, String>()
        queryString.split("&")
            .filter { it.isNotBlank() }
            .forEach { pair ->
                val kv = pair.split("=", limit = 2)
                val key = kv[0].trim()
                if (key.isEmpty()) return@forEach
                val value = if (kv.size > 1) URLDecoder.decode(kv[1], "UTF-8") else ""
                params[key] = value
            }

        val atIndex = mainPart.lastIndexOf("@")
        val (method, password, server, port) = if (atIndex > 0) {
            val userPart = mainPart.substring(0, atIndex)
            val serverPart = mainPart.substring(atIndex + 1)
            val decoded = try {
                android.util.Base64.decode(userPart, android.util.Base64.NO_WRAP or android.util.Base64.URL_SAFE)
                    .toString(Charsets.UTF_8)
            } catch (e: Exception) {
                try {
                    android.util.Base64.decode(userPart, android.util.Base64.DEFAULT)
                        .toString(Charsets.UTF_8)
                } catch (e2: Exception) {
                    userPart
                }
            }
            val colonIdx = decoded.indexOf(":")
            val m = decoded.substring(0, colonIdx)
            val p = decoded.substring(colonIdx + 1)
            val lastColon = serverPart.lastIndexOf(":")
            val s = serverPart.substring(0, lastColon)
            val pt = serverPart.substring(lastColon + 1).toInt()
            listOf(m, p, s, pt.toString())
        } else {
            val decoded = try {
                android.util.Base64.decode(mainPart, android.util.Base64.NO_WRAP or android.util.Base64.URL_SAFE)
                    .toString(Charsets.UTF_8)
            } catch (e: Exception) {
                android.util.Base64.decode(mainPart, android.util.Base64.DEFAULT)
                    .toString(Charsets.UTF_8)
            }
            val idx = decoded.lastIndexOf("@")
            val userPart = decoded.substring(0, idx)
            val serverPart = decoded.substring(idx + 1)
            val colonIdx = userPart.indexOf(":")
            val m = userPart.substring(0, colonIdx)
            val p = userPart.substring(colonIdx + 1)
            val lastColon = serverPart.lastIndexOf(":")
            val s = serverPart.substring(0, lastColon)
            val pt = serverPart.substring(lastColon + 1).toInt()
            listOf(m, p, s, pt.toString())
        }

        val streamSettings = mutableMapOf<String, Any>(
            "network" to "tcp",
            "tcpSettings" to mapOf("header" to mapOf("type" to "none"))
        )

        val pluginValue = params["plugin"]?.lowercase()
        if (!pluginValue.isNullOrBlank() && pluginValue.contains("obfs=http")) {
            val pluginOptions = mutableMapOf<String, String>()
            pluginValue.split(";")
                .filter { it.contains("=") }
                .forEach { item ->
                    val kv = item.split("=", limit = 2)
                    pluginOptions[kv[0].trim()] = kv[1].trim()
                }

            val host = pluginOptions["obfs-host"]?.takeIf { it.isNotBlank() }
            val path = pluginOptions["path"]?.takeIf { it.isNotBlank() } ?: "/"
            val requestHeaders = mutableMapOf<String, Any>(
                "User-Agent" to listOf(
                    "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.6478.122 Mobile Safari/537.36"
                ),
                "Accept-Encoding" to listOf("gzip, deflate"),
                "Connection" to listOf("keep-alive"),
                "Pragma" to "no-cache"
            )
            if (!host.isNullOrBlank()) {
                requestHeaders["Host"] = host.split(",").map { it.trim() }.filter { it.isNotEmpty() }
            }
            streamSettings["tcpSettings"] = mapOf(
                "header" to mapOf(
                    "type" to "http",
                    "request" to mapOf(
                        "version" to "1.1",
                        "method" to "GET",
                        "path" to listOf(path),
                        "headers" to requestHeaders
                    )
                )
            )
        }

        val outbound = mutableMapOf<String, Any>(
            "tag" to "proxy",
            "protocol" to "shadowsocks",
            "settings" to mapOf(
                "servers" to listOf(
                    mapOf(
                        "address" to server,
                        "port" to port.toInt(),
                        "method" to method,
                        "password" to password,
                        "level" to XRAY_USER_LEVEL
                    )
                )
            ),
            "streamSettings" to streamSettings
        )

        return outbound
    }

    private fun parseHysteria2(link: String): Map<String, Any> {
        val normalized = link.replace("hysteria2://", "hy2://")
        val uri = Uri.parse(normalized)
        val auth = uri.userInfo ?: ""
        val server = uri.host ?: throw Exception("Invalid hy2 link: no server")
        val port = uri.port.takeIf { it > 0 } ?: 443
        val params = parseQueryParams(uri)

        val settings = mutableMapOf<String, Any>(
            "address" to server,
            "port" to port,
            "version" to 2
        )

        val outbound = mutableMapOf<String, Any>(
            "tag" to "proxy",
            "protocol" to "hysteria",
            "settings" to settings
        )

        val stream = mutableMapOf<String, Any>(
            "network" to "hysteria",
            "security" to "tls"
        )
        val hysteriaSettings = mutableMapOf<String, Any>("version" to 2)
        if (auth.isNotBlank()) hysteriaSettings["auth"] = auth
        getParam(params, "upmbps")?.let { hysteriaSettings["up"] = "${it} Mbps" }
        getParam(params, "downmbps")?.let { hysteriaSettings["down"] = "${it} Mbps" }
        getParam(params, "mport")?.let { ports ->
            val hop = mutableMapOf<String, Any>("port" to ports)
            getParam(params, "mportHopInt")?.toIntOrNull()?.let { interval ->
                if (interval >= 5) {
                    hop["interval"] = interval
                }
            }
            hysteriaSettings["udphop"] = hop
        }
        stream["hysteriaSettings"] = hysteriaSettings

        val tlsSettings = mutableMapOf<String, Any>()
        (getParam(params, "sni") ?: server.takeIf { isDomainLike(it) })?.let { tlsSettings["serverName"] = it }
        parseFlexibleBool(getParam(params, "allowInsecure") ?: getParam(params, "insecure"))?.let {
            if (it) tlsSettings["allowInsecure"] = true
        }
        params["alpn"]?.takeIf { it.isNotEmpty() }?.let {
            tlsSettings["alpn"] = it.split(",").map { a -> a.trim() }
        }
        stream["tlsSettings"] = tlsSettings
        outbound["streamSettings"] = stream

        return outbound
    }

    private fun parseWireGuard(link: String): Map<String, Any> {
        val uri = Uri.parse(link)
        val privateKey = uri.userInfo ?: ""
        val server = uri.host ?: throw Exception("Invalid wg link: no server")
        val port = uri.port.takeIf { it > 0 } ?: 51820
        val params = parseQueryParams(uri)

        val peer = mutableMapOf<String, Any>(
            "endpoint" to "$server:$port"
        )
        params["publickey"]?.takeIf { it.isNotEmpty() }?.let { peer["publicKey"] = it }
        params["psk"]?.takeIf { it.isNotEmpty() }?.let { peer["preSharedKey"] = it }

        val settings = mutableMapOf<String, Any>(
            "secretKey" to privateKey,
            "peers" to listOf(peer)
        )
        params["address"]?.takeIf { it.isNotEmpty() }?.let {
            settings["address"] = it.split(",").map { a -> a.trim() }
        }
        params["reserved"]?.takeIf { it.isNotEmpty() }?.let { reserved ->
            val bytes = reserved.split(",").mapNotNull { it.trim().toIntOrNull() }
            if (bytes.isNotEmpty()) settings["reserved"] = bytes
        }
        params["mtu"]?.toIntOrNull()?.let { settings["mtu"] = it }

        return mapOf(
            "tag" to "proxy",
            "protocol" to "wireguard",
            "settings" to settings
        )
    }
}
