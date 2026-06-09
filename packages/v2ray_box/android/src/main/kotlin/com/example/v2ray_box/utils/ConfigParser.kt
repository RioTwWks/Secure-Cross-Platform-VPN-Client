package com.example.v2ray_box.utils

import android.net.Uri
import android.util.Log
import com.google.gson.Gson
import com.google.gson.GsonBuilder
import java.net.URLDecoder

object ConfigParser {
    private const val TAG = "V2Ray/ConfigParser"
    private val gson: Gson = GsonBuilder().setPrettyPrinting().disableHtmlEscaping().create()

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

    fun buildSingBoxConfig(link: String, proxyOnly: Boolean = false): String {
        val outbound = parseLink(link) ?: throw Exception("Invalid or unsupported config link")

        val config = mutableMapOf<String, Any>(
            "log" to mapOf(
                "level" to "info",
                "timestamp" to true
            ),
            "dns" to buildDns(),
            "inbounds" to buildInbounds(proxyOnly),
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
                    "tag" to "dns-remote",
                    "server" to "1.1.1.1",
                    "server_port" to 443,
                    "detour" to "proxy"
                ),
                mapOf(
                    "type" to "local",
                    "tag" to "dns-direct"
                )
            ),
            "strategy" to "prefer_ipv4",
            "independent_cache" to true
        )
    }

    private fun buildInbounds(proxyOnly: Boolean = false): List<Map<String, Any>> {
        val inbounds = mutableListOf<Map<String, Any>>()

        if (!proxyOnly) {
            inbounds.add(mapOf(
                "type" to "tun",
                "tag" to "tun-in",
                "interface_name" to "tun0",
                "mtu" to 9000,
                "address" to listOf("172.19.0.1/30", "fdfe:dcba:9876::1/126"),
                "auto_route" to true,
                "strict_route" to true,
                "stack" to "gvisor"
            ))
        }

        inbounds.add(mapOf(
            "type" to "mixed",
            "tag" to "mixed-in",
            "listen" to "127.0.0.1",
            "listen_port" to 2080
        ))

        return inbounds
    }

    private fun buildRoute(): Map<String, Any> {
        return mapOf(
            "rules" to listOf(
                mapOf("action" to "sniff"),
                mapOf("protocol" to "dns", "action" to "hijack-dns"),
                mapOf("ip_is_private" to true, "outbound" to "direct")
            ),
            "default_domain_resolver" to mapOf("server" to "dns-direct"),
            "final" to "proxy"
        )
    }

    private fun buildExperimental(): Map<String, Any> {
        return mapOf(
            "cache_file" to mapOf(
                "enabled" to true,
                "store_fakeip" to true
            ),
            "clash_api" to mapOf(
                "external_controller" to "127.0.0.1:9090"
            )
        )
    }

    // ========== Query parameter helpers ==========

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

    // ========== Transport ==========

    private fun buildTransport(params: Map<String, String>, vmessJson: Map<*, *>? = null): Map<String, Any>? {
        val transportType = params["type"] ?: vmessJson?.get("net")?.toString() ?: return null

        return when (transportType) {
            "ws", "websocket" -> {
                val transport = mutableMapOf<String, Any>("type" to "ws")
                val path = params["path"] ?: vmessJson?.get("path")?.toString()
                path?.takeIf { it.isNotEmpty() }?.let { transport["path"] = it }
                val host = params["host"] ?: vmessJson?.get("host")?.toString()
                host?.takeIf { it.isNotEmpty() }?.let {
                    transport["headers"] = mapOf("Host" to it)
                }
                params["max-early-data"]?.toIntOrNull()?.let { transport["max_early_data"] = it }
                params["early-data-header-name"]?.takeIf { it.isNotEmpty() }?.let {
                    transport["early_data_header_name"] = it
                }
                transport
            }
            "grpc" -> {
                val transport = mutableMapOf<String, Any>("type" to "grpc")
                val sn = params["serviceName"] ?: params["service-name"]
                    ?: vmessJson?.get("path")?.toString()
                sn?.takeIf { it.isNotEmpty() }?.let { transport["service_name"] = it }
                transport
            }
            "http", "h2" -> {
                val transport = mutableMapOf<String, Any>("type" to "http")
                val path = params["path"] ?: vmessJson?.get("path")?.toString()
                path?.takeIf { it.isNotEmpty() }?.let { transport["path"] = it }
                val host = params["host"] ?: vmessJson?.get("host")?.toString()
                host?.takeIf { it.isNotEmpty() }?.let {
                    transport["host"] = it.split(",").map { h -> h.trim() }
                }
                transport
            }
            "httpupgrade", "xhttp" -> {
                val transport = mutableMapOf<String, Any>("type" to "httpupgrade")
                val path = params["path"] ?: vmessJson?.get("path")?.toString()
                path?.takeIf { it.isNotEmpty() }?.let { transport["path"] = it }
                val host = params["host"] ?: vmessJson?.get("host")?.toString()
                host?.takeIf { it.isNotEmpty() }?.let { transport["host"] = it }
                transport
            }
            "quic" -> {
                mapOf("type" to "quic")
            }
            else -> null
        }
    }

    // ========== TLS ==========

    private fun buildTls(params: Map<String, String>, vmessJson: Map<*, *>? = null): Map<String, Any>? {
        val security = params["security"]
            ?: if (vmessJson?.get("tls")?.toString() == "tls") "tls" else null

        if (security != "tls" && security != "reality" && security != "xtls") return null

        val tls = mutableMapOf<String, Any>("enabled" to true)

        val sni = params["sni"] ?: params["peer"] ?: vmessJson?.get("sni")?.toString()
        sni?.takeIf { it.isNotEmpty() }?.let { tls["server_name"] = it }

        val alpn = params["alpn"] ?: vmessJson?.get("alpn")?.toString()
        alpn?.takeIf { it.isNotEmpty() }?.let {
            tls["alpn"] = it.split(",").map { a -> a.trim() }
        }

        val fp = params["fp"] ?: params["fingerprint"]
        fp?.takeIf { it.isNotEmpty() }?.let {
            tls["utls"] = mapOf("enabled" to true, "fingerprint" to it)
        }

        params["allowInsecure"]?.let {
            if (it == "1" || it == "true") tls["insecure"] = true
        }

        if (security == "reality") {
            val reality = mutableMapOf<String, Any>("enabled" to true)
            params["pbk"]?.takeIf { it.isNotEmpty() }?.let { reality["public_key"] = it }
            params["sid"]?.takeIf { it.isNotEmpty() }?.let { reality["short_id"] = it }
            tls["reality"] = reality
            if (!tls.containsKey("utls")) {
                tls["utls"] = mapOf("enabled" to true, "fingerprint" to (fp ?: "chrome"))
            }
        }

        return tls
    }

    // ========== Multiplex ==========

    private fun buildMux(params: Map<String, String>): Map<String, Any>? {
        val enabled = params["mux"]?.let { it == "1" || it == "true" } ?: return null
        if (!enabled) return null
        val mux = mutableMapOf<String, Any>("enabled" to true, "protocol" to "h2mux")
        params["mux-max-streams"]?.toIntOrNull()?.let { mux["max_streams"] = it }
        return mux
    }

    // ========== Protocol Parsers ==========

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
        params["packet_encoding"]?.takeIf { it.isNotEmpty() }?.let { outbound["packet_encoding"] = it }

        buildTransport(params)?.let { outbound["transport"] = it }
        buildTls(params)?.let { outbound["tls"] = it }
        buildMux(params)?.let { outbound["multiplex"] = it }

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
        val net = json["net"]?.toString() ?: "tcp"

        val outbound = mutableMapOf<String, Any>(
            "type" to "vmess",
            "tag" to "proxy",
            "server" to server,
            "server_port" to port,
            "uuid" to uuid,
            "alter_id" to aid,
            "security" to security
        )

        val transportParams = mapOf("type" to net)
        buildTransport(transportParams, json)?.let { outbound["transport"] = it }

        val tlsParams = mutableMapOf<String, String>()
        if (json["tls"]?.toString() == "tls") tlsParams["security"] = "tls"
        json["sni"]?.toString()?.let { tlsParams["sni"] = it }
        json["alpn"]?.toString()?.let { tlsParams["alpn"] = it }
        json["fp"]?.toString()?.let { tlsParams["fp"] = it }
        buildTls(tlsParams, json)?.let { outbound["tls"] = it }

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

        buildTransport(params)?.let { outbound["transport"] = it }
        buildTls(params)?.let { outbound["tls"] = it }

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
        if (!tlsParams.containsKey("security")) {
            tlsParams["security"] = "tls"
        }

        buildTransport(params)?.let { outbound["transport"] = it }
        buildTls(tlsParams)?.let { outbound["tls"] = it }
            ?: run { outbound["tls"] = mapOf("enabled" to true) }
        buildMux(params)?.let { outbound["multiplex"] = it }

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
            val pluginName = pluginParts[0]
            val pluginOpts = if (pluginParts.size > 1) pluginParts[1] else ""
            outbound["plugin"] = pluginName
            outbound["plugin_opts"] = pluginOpts
        }

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
        params["sni"]?.takeIf { it.isNotEmpty() }?.let { tls["server_name"] = it }
        params["insecure"]?.let {
            if (it == "1" || it == "true") tls["insecure"] = true
        }
        params["alpn"]?.takeIf { it.isNotEmpty() }?.let {
            tls["alpn"] = it.split(",").map { a -> a.trim() }
        }
        outbound["tls"] = tls

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
        params["peer"]?.takeIf { it.isNotEmpty() }?.let { tls["server_name"] = it }
        params["sni"]?.takeIf { it.isNotEmpty() }?.let { tls["server_name"] = it }
        params["insecure"]?.let {
            if (it == "1" || it == "true") tls["insecure"] = true
        }
        params["alpn"]?.takeIf { it.isNotEmpty() }?.let {
            tls["alpn"] = it.split(",").map { a -> a.trim() }
        }
        outbound["tls"] = tls

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
        params["sni"]?.takeIf { it.isNotEmpty() }?.let { tls["server_name"] = it }
        params["alpn"]?.takeIf { it.isNotEmpty() }?.let {
            tls["alpn"] = it.split(",").map { a -> a.trim() }
        }
        params["allowInsecure"]?.let {
            if (it == "1" || it == "true") tls["insecure"] = true
        }
        outbound["tls"] = tls

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

        return outbound
    }
}
