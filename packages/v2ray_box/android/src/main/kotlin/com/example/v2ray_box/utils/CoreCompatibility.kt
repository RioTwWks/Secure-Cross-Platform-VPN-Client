package com.example.v2ray_box.utils

import android.net.Uri
import android.util.Base64
import com.example.v2ray_box.constant.CoreEngine
import com.google.gson.JsonParser
import java.net.URLDecoder

data class ConfigLinkMeta(
    val protocol: String,
    val transport: String?,
    val shadowsocksPlugin: String?
)

object CoreCompatibility {
    private val XRAY_PROTOCOLS = setOf(
        "vmess",
        "vless",
        "trojan",
        "ss",
        "shadowsocks",
        "wg",
        "wireguard"
    )

    private val XRAY_TRANSPORTS = setOf(
        "tcp",
        "kcp",
        "mkcp",
        "ws",
        "websocket",
        "grpc",
        "http",
        "h2",
        "httpupgrade",
        "xhttp",
        "splithttp",
        "quic"
    )

    fun resolveEngineForLink(preferredEngine: String, link: String): String {
        val preferred = preferredEngine.trim().lowercase()
        if (preferred == CoreEngine.SINGBOX) return CoreEngine.SINGBOX
        return if (isXrayCompatible(link)) CoreEngine.XRAY else CoreEngine.SINGBOX
    }

    fun isXrayCompatible(link: String): Boolean {
        val meta = parseConfigLinkMeta(link) ?: return false
        val protocol = meta.protocol

        if (protocol == "tuic" ||
            protocol == "ssh" ||
            protocol == "hy" ||
            protocol == "hysteria" ||
            protocol == "hy2" ||
            protocol == "hysteria2"
        ) {
            return false
        }
        if (protocol !in XRAY_PROTOCOLS) return false

        val transport = meta.transport
        if (!transport.isNullOrBlank() && transport !in XRAY_TRANSPORTS) {
            return false
        }

        if (protocol == "ss" || protocol == "shadowsocks") {
            val plugin = meta.shadowsocksPlugin?.trim()?.lowercase()
            if (!plugin.isNullOrEmpty() && !plugin.contains("obfs=http")) {
                return false
            }
        }
        return true
    }

    fun parseConfigLinkMeta(link: String): ConfigLinkMeta? {
        val schemeRaw = link.substringBefore("://", "").trim().lowercase()
        if (schemeRaw.isEmpty()) return null

        val protocol = when (schemeRaw) {
            "wireguard" -> "wg"
            "hysteria2" -> "hy2"
            else -> schemeRaw
        }

        val params = parseQueryParams(link)
        val transport = normalizeTransport(params["type"] ?: params["net"] ?: vmessNetworkFromPayload(link))

        val ssPlugin = if (protocol == "ss" || protocol == "shadowsocks") {
            params["plugin"]
        } else {
            null
        }

        return ConfigLinkMeta(
            protocol = protocol,
            transport = transport,
            shadowsocksPlugin = ssPlugin
        )
    }

    private fun normalizeTransport(value: String?): String? {
        if (value.isNullOrBlank()) return null
        return when (value.trim().lowercase()) {
            "websocket" -> "ws"
            "http2" -> "h2"
            "http-upgrade" -> "httpupgrade"
            "split-http" -> "splithttp"
            else -> value.trim().lowercase()
        }
    }

    private fun parseQueryParams(link: String): Map<String, String> {
        val query = runCatching { Uri.parse(link).query }.getOrNull()
            ?: link.substringAfter("?", "").substringBefore("#")
        if (query.isBlank()) return emptyMap()
        val out = linkedMapOf<String, String>()
        query.split("&")
            .filter { it.isNotBlank() }
            .forEach { pair ->
                val parts = pair.split("=", limit = 2)
                val key = parts.getOrNull(0)?.trim()?.lowercase().orEmpty()
                if (key.isBlank()) return@forEach
                val value = parts.getOrNull(1).orEmpty()
                out[key] = runCatching { URLDecoder.decode(value, "UTF-8") }.getOrDefault(value)
            }
        return out
    }

    private fun vmessNetworkFromPayload(link: String): String? {
        if (!link.startsWith("vmess://")) return null
        val payload = link.removePrefix("vmess://").substringBefore("#")
        val decoded = runCatching {
            String(Base64.decode(payload, Base64.DEFAULT), Charsets.UTF_8)
        }.getOrNull() ?: return null

        if (!decoded.trimStart().startsWith("{")) return null
        return runCatching {
            JsonParser.parseString(decoded).asJsonObject.get("net")?.asString
        }.getOrNull()?.trim()?.lowercase()
    }
}
