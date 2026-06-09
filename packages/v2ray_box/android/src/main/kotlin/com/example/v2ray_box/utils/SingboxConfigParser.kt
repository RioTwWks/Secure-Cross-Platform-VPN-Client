package com.example.v2ray_box.utils

import android.net.Uri
import android.util.Log
import com.google.gson.Gson
import com.google.gson.GsonBuilder
import java.net.URLDecoder

object SingboxConfigParser {
    private const val TAG = "V2Ray/SingboxConfigParser"
    private const val DNS_REMOTE_TAG = "dns-remote"
    private const val DNS_DIRECT_TAG = "dns-direct"
    private const val DNS_STRATEGY = "prefer_ipv4"
    private val gson: Gson = GsonBuilder().setPrettyPrinting().disableHtmlEscaping().create()
    private val ipv4Regex = Regex(
        """^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$"""
    )

    fun buildSingboxConfig(link: String, enableTun: Boolean = false): String {
        val outbound = parseLink(link) ?: throw Exception("Invalid or unsupported config link")

        val config = mutableMapOf<String, Any>(
            "log" to mapOf("level" to "warn", "timestamp" to false),
            "dns" to buildDns(),
            "inbounds" to buildInbounds(enableTun),
            "outbounds" to listOf(
                outbound,
                mapOf("type" to "direct", "tag" to "direct")
            ),
            "route" to buildRoute(),
            "experimental" to buildExperimental()
        )

        return gson.toJson(config)
    }

    private fun buildDns(): Map<String, Any> {
        return mapOf(
            "servers" to listOf(
                mapOf(
                    "type" to "https",
                    "tag" to DNS_REMOTE_TAG,
                    "server" to "1.1.1.1",
                    "server_port" to 443,
                    "path" to "/dns-query",
                    "detour" to "proxy"
                ),
                mapOf(
                    "type" to "local",
                    "tag" to DNS_DIRECT_TAG
                )
            ),
            "strategy" to DNS_STRATEGY,
            "final" to DNS_REMOTE_TAG,
            "disable_expire" to true,
            "independent_cache" to true
        )
    }

    private fun buildInbounds(enableTun: Boolean): List<Map<String, Any>> {
        val inbounds = mutableListOf<Map<String, Any>>()
        if (enableTun) {
            inbounds += mapOf(
                "type" to "tun",
                "tag" to "tun-in",
                "interface_name" to "tun0",
                "mtu" to 9000,
                "address" to listOf("172.19.0.1/30", "fdfe:dcba:9876::1/126"),
                "auto_route" to true,
                "strict_route" to true,
                "stack" to "mixed"
            )
        }
        inbounds += mapOf(
            "type" to "mixed",
            "tag" to "mixed-in",
            "listen" to "127.0.0.1",
            "listen_port" to 10808
        )
        return inbounds
    }

    private fun buildRoute(): Map<String, Any> {
        return mapOf(
            "rules" to listOf(
                mapOf("action" to "sniff"),
                mapOf("protocol" to "dns", "action" to "hijack-dns"),
                mapOf("ip_is_private" to true, "outbound" to "direct")
            ),
            "default_domain_resolver" to mapOf(
                "server" to DNS_DIRECT_TAG,
                "strategy" to DNS_STRATEGY
            ),
            "final" to "proxy"
        )
    }

    private fun buildExperimental(): Map<String, Any> {
        return mapOf(
            "cache_file" to mapOf(
                "enabled" to true,
                "path" to "cache.db",
                "store_fakeip" to true
            ),
            "clash_api" to mapOf(
                "external_controller" to "127.0.0.1:9090"
            )
        )
    }

    fun parseLink(link: String): Map<String, Any>? {
        return try {
            when {
                link.startsWith("vless://") -> parseVless(link)
                link.startsWith("vmess://") -> parseVmess(link)
                link.startsWith("trojan://") -> parseTrojan(link)
                link.startsWith("ss://") -> parseShadowsocks(link)
                link.startsWith("hy2://") || link.startsWith("hysteria2://") -> parseHysteria2(link)
                link.startsWith("hy://") || link.startsWith("hysteria://") -> parseHysteria(link)
                link.startsWith("tuic://") -> parseTuic(link)
                link.startsWith("wg://") || link.startsWith("wireguard://") -> parseWireGuard(link)
                link.startsWith("ssh://") -> parseSsh(link)
                else -> null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse link: ${e.message}", e)
            null
        }
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
    }

    private fun normalizePath(path: String?): String? {
        val value = path?.trim() ?: return null
        if (value.isEmpty()) return "/"
        return if (value.startsWith("/")) value else "/$value"
    }

    private fun normalizeGrpcServiceName(value: String?): String? {
        val service = value?.trim()?.trim('/') ?: return null
        return service.takeIf { it.isNotEmpty() }
    }

    private fun splitCsv(value: String?): List<String> {
        if (value.isNullOrBlank()) return emptyList()
        return value.split(",")
            .map { it.trim() }
            .filter { it.isNotEmpty() }
    }

    private fun firstHostValue(value: String?): String? = splitCsv(value).firstOrNull()

    private fun isIpAddress(value: String?): Boolean {
        if (value.isNullOrBlank()) return false
        val host = value.trim().removePrefix("[").removeSuffix("]").substringBefore("%")
        if (host.isEmpty()) return false
        if (ipv4Regex.matches(host)) return true
        if (!host.contains(":")) return false
        return host.all { c ->
            c == ':' || c == '.' || c in '0'..'9' || c in 'a'..'f' || c in 'A'..'F'
        }
    }

    private fun isDomainLike(value: String?): Boolean {
        return !value.isNullOrBlank() && !isIpAddress(value)
    }

    private fun applyDefaultDomainResolver(outbound: MutableMap<String, Any>, server: String) {
        if (!isDomainLike(server) || outbound.containsKey("domain_resolver")) return
        outbound["domain_resolver"] = mapOf(
            "server" to DNS_DIRECT_TAG,
            "strategy" to DNS_STRATEGY
        )
    }

    private fun parseFlexibleBool(value: String?): Boolean? {
        return when (value?.trim()?.lowercase()) {
            "1", "true", "yes", "on" -> true
            "0", "false", "no", "off" -> false
            else -> null
        }
    }

    private fun buildTls(
        params: Map<String, String>,
        vmessJson: Map<*, *>? = null,
        defaultServerName: String? = null
    ): Map<String, Any>? {
        val security = getParam(params, "security")
            ?: if (vmessJson?.get("tls")?.toString() == "tls") "tls" else null

        if (security != "tls" && security != "reality" && security != "xtls") return null

        val tls = mutableMapOf<String, Any>("enabled" to true)
        val hostFromTransport = firstHostValue(getParam(params, "host") ?: vmessJson?.get("host")?.toString())

        val sni = getParam(params, "sni")
            ?: getParam(params, "peer")
            ?: vmessJson?.get("sni")?.toString()?.trim()?.takeIf { it.isNotEmpty() }
            ?: defaultServerName?.takeIf { isDomainLike(it) }
            ?: hostFromTransport?.takeIf { isDomainLike(it) }
        sni?.takeIf { it.isNotEmpty() }?.let { tls["server_name"] = it }

        val alpn = getParam(params, "alpn") ?: vmessJson?.get("alpn")?.toString()
        alpn?.takeIf { it.isNotEmpty() }?.let {
            tls["alpn"] = it.split(",").map { a -> a.trim() }.filter { a -> a.isNotEmpty() }
        }

        val fp = getParam(params, "fp") ?: getParam(params, "fingerprint")
        fp?.takeIf { it.isNotEmpty() }?.let {
            tls["utls"] = mapOf("enabled" to true, "fingerprint" to it)
        }

        parseFlexibleBool(getParam(params, "allowInsecure") ?: getParam(params, "insecure"))?.let {
            if (it) tls["insecure"] = true
        }

        if (security == "reality") {
            val reality = mutableMapOf<String, Any>("enabled" to true)
            getParam(params, "pbk")?.let { reality["public_key"] = it }
            getParam(params, "sid")?.let { reality["short_id"] = it }
            tls["reality"] = reality
            if (!tls.containsKey("utls")) {
                tls["utls"] = mapOf("enabled" to true, "fingerprint" to (fp ?: "chrome"))
            }
        }

        return tls
    }

    private fun buildMux(params: Map<String, String>): Map<String, Any>? {
        val enabled = parseFlexibleBool(getParam(params, "mux")) ?: return null
        if (!enabled) return null
        val mux = mutableMapOf<String, Any>("enabled" to true, "protocol" to "h2mux")
        params["mux-max-streams"]?.toIntOrNull()?.let { mux["max_streams"] = it }
        parseFlexibleBool(getParam(params, "mux-padding"))?.let { mux["padding"] = it }
        return mux
    }

    private fun buildTransport(params: Map<String, String>, vmessJson: Map<*, *>? = null): Map<String, Any>? {
        val transportTypeRaw = getParam(params, "type") ?: vmessJson?.get("net")?.toString() ?: return null
        val transportType = when (transportTypeRaw.lowercase()) {
            "websocket" -> "ws"
            else -> transportTypeRaw.lowercase()
        }

        return when (transportType) {
            "tcp" -> {
                val headerType = (getParam(params, "headerType")
                    ?: getParam(params, "header-type")
                    ?: vmessJson?.get("type")?.toString()
                    ?: "none").lowercase()
                if (headerType != "http") return null
                val transport = mutableMapOf<String, Any>("type" to "http")
                val path = normalizePath(getParam(params, "path") ?: vmessJson?.get("path")?.toString())
                transport["path"] = path ?: "/"
                val hostList = splitCsv(getParam(params, "host") ?: vmessJson?.get("host")?.toString())
                if (hostList.isNotEmpty()) {
                    transport["host"] = hostList
                }
                transport
            }
            "ws", "websocket" -> {
                val transport = mutableMapOf<String, Any>("type" to "ws")
                val path = normalizePath(getParam(params, "path") ?: vmessJson?.get("path")?.toString())
                transport["path"] = path ?: "/"
                val host = firstHostValue(getParam(params, "host") ?: vmessJson?.get("host")?.toString())
                host?.let {
                    transport["headers"] = mapOf("Host" to it)
                }
                getParam(params, "max-early-data")?.toIntOrNull()?.let { transport["max_early_data"] = it }
                getParam(params, "early-data-header-name")?.let {
                    transport["early_data_header_name"] = it
                }
                transport
            }
            "grpc" -> {
                val transport = mutableMapOf<String, Any>("type" to "grpc")
                val serviceName = normalizeGrpcServiceName(
                    getParam(params, "serviceName")
                        ?: getParam(params, "service-name")
                        ?: vmessJson?.get("path")?.toString()
                )
                serviceName?.let { transport["service_name"] = it }
                getParam(params, "grpc-idle-timeout")?.let { transport["idle_timeout"] = it }
                getParam(params, "grpc-ping-timeout")?.let { transport["ping_timeout"] = it }
                parseFlexibleBool(getParam(params, "grpc-permit-without-stream"))?.let {
                    transport["permit_without_stream"] = it
                }
                transport
            }
            "http", "h2" -> {
                val transport = mutableMapOf<String, Any>("type" to "http")
                val path = normalizePath(getParam(params, "path") ?: vmessJson?.get("path")?.toString())
                transport["path"] = path ?: "/"
                val hostList = splitCsv(getParam(params, "host") ?: vmessJson?.get("host")?.toString())
                if (hostList.isNotEmpty()) {
                    transport["host"] = hostList
                }
                transport
            }
            "httpupgrade", "xhttp" -> {
                val transport = mutableMapOf<String, Any>("type" to "httpupgrade")
                val path = normalizePath(getParam(params, "path") ?: vmessJson?.get("path")?.toString())
                transport["path"] = path ?: "/"
                val host = firstHostValue(getParam(params, "host") ?: vmessJson?.get("host")?.toString())
                host?.let { transport["host"] = it }
                transport
            }
            "quic" -> mapOf("type" to "quic")
            else -> null
        }
    }

    private fun parseVless(link: String): Map<String, Any> {
        val uri = Uri.parse(link)
        val uuid = uri.userInfo ?: throw Exception("Invalid vless link: no UUID")
        val server = uri.host ?: throw Exception("Invalid vless link: no server")
        val port = uri.port.takeIf { it > 0 } ?: 443
        val params = parseQueryParams(uri)

        val outbound = mutableMapOf<String, Any>(
            "type" to "vless",
            "tag" to "proxy",
            "server" to server,
            "server_port" to port,
            "uuid" to uuid
        )

        params["flow"]?.takeIf { it.isNotEmpty() }?.let { outbound["flow"] = it }
        (getParam(params, "packet_encoding") ?: getParam(params, "packetEncoding"))
            ?.let { outbound["packet_encoding"] = it }

        buildTransport(params)?.let { outbound["transport"] = it }
        buildTls(params, defaultServerName = server)?.let { outbound["tls"] = it }
        buildMux(params)?.let { outbound["multiplex"] = it }
        applyDefaultDomainResolver(outbound, server)

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

        val json = gson.fromJson(decoded, Map::class.java)
        val server = json["add"]?.toString() ?: throw Exception("Invalid vmess: no server")
        val port = json["port"]?.toString()?.toDoubleOrNull()?.toInt() ?: 443
        val uuid = json["id"]?.toString() ?: throw Exception("Invalid vmess: no id")
        val aid = json["aid"]?.toString()?.toDoubleOrNull()?.toInt() ?: 0
        val security = json["scy"]?.toString()?.takeIf { it.isNotEmpty() } ?: "auto"

        val outbound = mutableMapOf<String, Any>(
            "type" to "vmess",
            "tag" to "proxy",
            "server" to server,
            "server_port" to port,
            "uuid" to uuid,
            "alter_id" to aid,
            "security" to security
        )

        val transportParams = mutableMapOf("type" to (json["net"]?.toString() ?: "tcp"))
        json["type"]?.toString()?.let { transportParams["headerType"] = it }
        buildTransport(transportParams, json)?.let { outbound["transport"] = it }

        val tlsParams = mutableMapOf<String, String>()
        if (json["tls"]?.toString() == "tls") tlsParams["security"] = "tls"
        json["sni"]?.toString()?.let { tlsParams["sni"] = it }
        json["alpn"]?.toString()?.let { tlsParams["alpn"] = it }
        json["fp"]?.toString()?.let { tlsParams["fp"] = it }
        buildTls(tlsParams, json, defaultServerName = server)?.let { outbound["tls"] = it }
        json["packetEncoding"]?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let {
            outbound["packet_encoding"] = it
        }
        applyDefaultDomainResolver(outbound, server)

        return outbound
    }

    private fun parseVmessUrl(link: String): Map<String, Any> {
        val uri = Uri.parse(link)
        val uuid = uri.userInfo ?: throw Exception("Invalid vmess link")
        val server = uri.host ?: throw Exception("Invalid vmess link")
        val port = uri.port.takeIf { it > 0 } ?: 443
        val params = parseQueryParams(uri)

        val outbound = mutableMapOf<String, Any>(
            "type" to "vmess",
            "tag" to "proxy",
            "server" to server,
            "server_port" to port,
            "uuid" to uuid,
            "alter_id" to 0,
            "security" to "auto"
        )

        buildTls(params, defaultServerName = server)?.let { outbound["tls"] = it }
        buildTransport(params)?.let { outbound["transport"] = it }
        buildMux(params)?.let { outbound["multiplex"] = it }
        (getParam(params, "packet_encoding") ?: getParam(params, "packetEncoding"))
            ?.let { outbound["packet_encoding"] = it }
        applyDefaultDomainResolver(outbound, server)

        return outbound
    }

    private fun parseTrojan(link: String): Map<String, Any> {
        val uri = Uri.parse(link)
        val password = uri.userInfo ?: throw Exception("Invalid trojan link: no password")
        val server = uri.host ?: throw Exception("Invalid trojan link: no server")
        val port = uri.port.takeIf { it > 0 } ?: 443
        val params = parseQueryParams(uri)

        val outbound = mutableMapOf<String, Any>(
            "type" to "trojan",
            "tag" to "proxy",
            "server" to server,
            "server_port" to port,
            "password" to password
        )

        val tlsParams = params.toMutableMap()
        if (tlsParams["security"].isNullOrBlank()) {
            tlsParams["security"] = "tls"
        }

        buildTransport(params)?.let { outbound["transport"] = it }
        buildTls(tlsParams, defaultServerName = server)?.let { outbound["tls"] = it }
            ?: run { outbound["tls"] = mapOf("enabled" to true) }
        buildMux(params)?.let { outbound["multiplex"] = it }
        applyDefaultDomainResolver(outbound, server)

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
        queryString.split("&").forEach { param ->
            val parts = param.split("=", limit = 2)
            if (parts.size == 2) params[parts[0]] = URLDecoder.decode(parts[1], "UTF-8")
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
                } catch (_: Exception) { userPart }
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

        val outbound = mutableMapOf<String, Any>(
            "type" to "shadowsocks",
            "tag" to "proxy",
            "server" to server,
            "server_port" to port.toInt(),
            "method" to method,
            "password" to password
        )

        params["plugin"]?.takeIf { it.isNotEmpty() }?.let { pluginStr ->
            val pluginParts = pluginStr.split(";", limit = 2)
            outbound["plugin"] = pluginParts[0]
            if (pluginParts.size > 1) outbound["plugin_opts"] = pluginParts[1]
        }
        applyDefaultDomainResolver(outbound, server)

        return outbound
    }

    private fun parseHysteria2(link: String): Map<String, Any> {
        val normalized = link.replace("hysteria2://", "hy2://")
        val uri = Uri.parse(normalized)
        val auth = uri.userInfo ?: ""
        val server = uri.host ?: throw Exception("Invalid hy2 link: no server")
        val port = uri.port.takeIf { it > 0 } ?: 443
        val params = parseQueryParams(uri)

        val outbound = mutableMapOf<String, Any>(
            "type" to "hysteria2",
            "tag" to "proxy",
            "server" to server,
            "server_port" to port,
            "password" to auth
        )

        params["obfs"]?.takeIf { it.isNotEmpty() }?.let { obfsType ->
            val obfs = mutableMapOf<String, Any>("type" to obfsType)
            params["obfs-password"]?.takeIf { it.isNotEmpty() }?.let { obfs["password"] = it }
            outbound["obfs"] = obfs
        }

        val tls = mutableMapOf<String, Any>("enabled" to true)
        (getParam(params, "sni") ?: server.takeIf { isDomainLike(it) })?.let { tls["server_name"] = it }
        parseFlexibleBool(getParam(params, "allowInsecure") ?: getParam(params, "insecure"))?.let {
            if (it) tls["insecure"] = true
        }
        params["alpn"]?.takeIf { it.isNotEmpty() }?.let {
            tls["alpn"] = it.split(",").map { a -> a.trim() }
        }
        outbound["tls"] = tls
        applyDefaultDomainResolver(outbound, server)

        return outbound
    }

    private fun parseHysteria(link: String): Map<String, Any> {
        val normalized = link.replace("hysteria://", "hy://")
        val uri = Uri.parse(normalized)
        val server = uri.host ?: throw Exception("Invalid hysteria link: no server")
        val port = uri.port.takeIf { it > 0 } ?: 443
        val params = parseQueryParams(uri)

        val outbound = mutableMapOf<String, Any>(
            "type" to "hysteria",
            "tag" to "proxy",
            "server" to server,
            "server_port" to port
        )

        val auth = uri.userInfo ?: params["auth"]
        auth?.takeIf { it.isNotEmpty() }?.let { outbound["auth_str"] = it }

        params["upmbps"]?.takeIf { it.isNotEmpty() }?.let { outbound["up_mbps"] = it.toInt() }
        params["downmbps"]?.takeIf { it.isNotEmpty() }?.let { outbound["down_mbps"] = it.toInt() }

        params["obfs"]?.takeIf { it.isNotEmpty() }?.let { obfsType ->
            if (obfsType == "xplus") {
                outbound["obfs"] = params["obfsParam"] ?: ""
            }
        }

        params["protocol"]?.takeIf { it.isNotEmpty() }?.let { outbound["protocol"] = it }

        val tls = mutableMapOf<String, Any>("enabled" to true)
        (getParam(params, "sni")
            ?: getParam(params, "peer")
            ?: server.takeIf { isDomainLike(it) })?.let { tls["server_name"] = it }
        parseFlexibleBool(getParam(params, "allowInsecure") ?: getParam(params, "insecure"))?.let {
            if (it) tls["insecure"] = true
        }
        params["alpn"]?.takeIf { it.isNotEmpty() }?.let {
            tls["alpn"] = it.split(",").map { a -> a.trim() }
        }
        outbound["tls"] = tls
        applyDefaultDomainResolver(outbound, server)

        return outbound
    }

    private fun parseTuic(link: String): Map<String, Any> {
        val uri = Uri.parse(link)
        val userInfo = uri.userInfo ?: ""
        val server = uri.host ?: throw Exception("Invalid tuic link: no server")
        val port = uri.port.takeIf { it > 0 } ?: 443
        val params = parseQueryParams(uri)

        val parts = userInfo.split(":", limit = 2)
        val uuid = parts[0]
        val password = if (parts.size > 1) parts[1] else ""

        val outbound = mutableMapOf<String, Any>(
            "type" to "tuic",
            "tag" to "proxy",
            "server" to server,
            "server_port" to port,
            "uuid" to uuid,
            "password" to password
        )

        params["congestion_control"]?.takeIf { it.isNotEmpty() }?.let {
            outbound["congestion_control"] = it
        }
        params["udp_relay_mode"]?.takeIf { it.isNotEmpty() }?.let {
            outbound["udp_relay_mode"] = it
        }

        val tls = mutableMapOf<String, Any>("enabled" to true)
        (getParam(params, "sni") ?: server.takeIf { isDomainLike(it) })?.let { tls["server_name"] = it }
        params["alpn"]?.takeIf { it.isNotEmpty() }?.let {
            tls["alpn"] = it.split(",").map { a -> a.trim() }
        }
        parseFlexibleBool(getParam(params, "allowInsecure") ?: getParam(params, "insecure"))?.let {
            if (it) tls["insecure"] = true
        }
        outbound["tls"] = tls
        applyDefaultDomainResolver(outbound, server)

        return outbound
    }

    private fun parseWireGuard(link: String): Map<String, Any> {
        val uri = Uri.parse(link)
        val privateKey = uri.userInfo ?: ""
        val server = uri.host ?: throw Exception("Invalid wg link: no server")
        val port = uri.port.takeIf { it > 0 } ?: 51820
        val params = parseQueryParams(uri)

        val outbound = mutableMapOf<String, Any>(
            "type" to "wireguard",
            "tag" to "proxy",
            "server" to server,
            "server_port" to port,
            "private_key" to privateKey
        )

        params["publickey"]?.takeIf { it.isNotEmpty() }?.let { outbound["peer_public_key"] = it }
        params["psk"]?.takeIf { it.isNotEmpty() }?.let { outbound["pre_shared_key"] = it }
        params["address"]?.takeIf { it.isNotEmpty() }?.let {
            outbound["local_address"] = it.split(",").map { a -> a.trim() }
        }
        params["reserved"]?.takeIf { it.isNotEmpty() }?.let { reserved ->
            val bytes = reserved.split(",").mapNotNull { it.trim().toIntOrNull() }
            if (bytes.isNotEmpty()) outbound["reserved"] = bytes
        }
        params["mtu"]?.toIntOrNull()?.let { outbound["mtu"] = it }
        applyDefaultDomainResolver(outbound, server)

        return outbound
    }

    private fun parseSsh(link: String): Map<String, Any> {
        val uri = Uri.parse(link)
        val userInfo = uri.userInfo ?: ""
        val server = uri.host ?: throw Exception("Invalid ssh link: no server")
        val port = uri.port.takeIf { it > 0 } ?: 22
        val params = parseQueryParams(uri)

        val parts = userInfo.split(":", limit = 2)
        val user = parts[0]
        val password = if (parts.size > 1) parts[1] else ""

        val outbound = mutableMapOf<String, Any>(
            "type" to "ssh",
            "tag" to "proxy",
            "server" to server,
            "server_port" to port,
            "user" to user
        )

        if (password.isNotEmpty()) outbound["password"] = password

        params["pk"]?.takeIf { it.isNotEmpty() }?.let { outbound["private_key"] = it }
        params["pkp"]?.takeIf { it.isNotEmpty() }?.let { outbound["private_key_passphrase"] = it }
        params["hk"]?.takeIf { it.isNotEmpty() }?.let {
            outbound["host_key"] = it.split(",").map { k -> k.trim() }
        }
        applyDefaultDomainResolver(outbound, server)

        return outbound
    }
}
