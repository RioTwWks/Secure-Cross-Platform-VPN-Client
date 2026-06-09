import Foundation

class XrayConfigBuilder {

    private let configOptions: [String: Any]

    init(optionsJson: String) {
        if let data = optionsJson.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            self.configOptions = json
        } else {
            self.configOptions = [:]
        }
    }

    func buildConfig(from link: String, proxyOnly: Bool = false) throws -> String {
        guard let outbound = parseLink(link) else {
            throw XrayConfigError.invalidLink
        }
        let config = buildFullConfig(outbound: outbound, proxyOnly: proxyOnly)
        let data = try JSONSerialization.data(withJSONObject: config, options: [.sortedKeys])
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw XrayConfigError.serializationFailed
        }
        return jsonString
    }

    static func parseOutbound(_ link: String) -> [String: Any]? {
        return XrayConfigBuilder(optionsJson: "{}").parseLink(link)
    }

    // MARK: - Link Parsing

    private func parseLink(_ link: String) -> [String: Any]? {
        if link.hasPrefix("vless://") { return parseVless(link) }
        if link.hasPrefix("vmess://") { return parseVmess(link) }
        if link.hasPrefix("trojan://") { return parseTrojan(link) }
        if link.hasPrefix("ss://") { return parseShadowsocks(link) }
        if link.hasPrefix("hy2://") || link.hasPrefix("hysteria2://") { return parseHysteria2(link) }
        if link.hasPrefix("wg://") { return parseWireGuard(link) }
        return nil
    }

    // MARK: - Query Parameters

    private func queryParams(from link: String) -> [String: String] {
        guard let comps = URLComponents(string: link) else { return [:] }
        var params: [String: String] = [:]
        for item in comps.queryItems ?? [] {
            params[item.name] = item.value ?? ""
        }
        return params
    }

    // MARK: - Stream Settings

    private func buildStreamSettings(_ params: [String: String], vmessJson: [String: Any]? = nil) -> [String: Any] {
        var stream: [String: Any] = [:]
        let networkType = params["type"] ?? vmessJson?["net"] as? String ?? "tcp"
        stream["network"] = networkType

        let security = params["security"] ?? {
            if vmessJson?["tls"] as? String == "tls" { return "tls" }
            return "none"
        }()
        stream["security"] = security

        switch networkType {
        case "ws", "websocket":
            var wsSettings: [String: Any] = [:]
            let path = params["path"] ?? vmessJson?["path"] as? String ?? "/"
            wsSettings["path"] = path
            let host = params["host"] ?? vmessJson?["host"] as? String
            if let h = host, !h.isEmpty { wsSettings["headers"] = ["Host": h] }
            stream["wsSettings"] = wsSettings
        case "grpc":
            var grpcSettings: [String: Any] = [:]
            let sn = params["serviceName"] ?? params["service-name"] ?? vmessJson?["path"] as? String
            if let s = sn, !s.isEmpty { grpcSettings["serviceName"] = s }
            if let mode = params["mode"], !mode.isEmpty { grpcSettings["multiMode"] = (mode == "multi") }
            stream["grpcSettings"] = grpcSettings
        case "h2", "http":
            var httpSettings: [String: Any] = [:]
            let path = params["path"] ?? vmessJson?["path"] as? String
            if let p = path, !p.isEmpty { httpSettings["path"] = p }
            let host = params["host"] ?? vmessJson?["host"] as? String
            if let h = host, !h.isEmpty {
                httpSettings["host"] = h.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            }
            stream["httpSettings"] = httpSettings
            stream["network"] = "h2"
        case "httpupgrade":
            var huSettings: [String: Any] = [:]
            let path = params["path"] ?? vmessJson?["path"] as? String
            if let p = path, !p.isEmpty { huSettings["path"] = p }
            let host = params["host"] ?? vmessJson?["host"] as? String
            if let h = host, !h.isEmpty { huSettings["host"] = h }
            stream["httpupgradeSettings"] = huSettings
        case "splithttp", "xhttp":
            var shSettings: [String: Any] = [:]
            let path = params["path"] ?? vmessJson?["path"] as? String
            if let p = path, !p.isEmpty { shSettings["path"] = p }
            let host = params["host"] ?? vmessJson?["host"] as? String
            if let h = host, !h.isEmpty { shSettings["host"] = h }
            if let mode = params["mode"], !mode.isEmpty { shSettings["mode"] = mode }
            stream["splithttpSettings"] = shSettings
            stream["network"] = "splithttp"
        case "quic":
            var quicSettings: [String: Any] = [
                "security": params["quicSecurity"] ?? "none",
                "header": ["type": params["headerType"] ?? "none"]
            ]
            if let key = params["key"], !key.isEmpty { quicSettings["key"] = key }
            stream["quicSettings"] = quicSettings
        case "kcp", "mkcp":
            var kcpSettings: [String: Any] = [
                "header": ["type": params["headerType"] ?? "none"]
            ]
            if let seed = params["seed"], !seed.isEmpty { kcpSettings["seed"] = seed }
            stream["kcpSettings"] = kcpSettings
            stream["network"] = "kcp"
        default:
            break
        }

        switch security {
        case "tls":
            var tlsSettings: [String: Any] = [:]
            let sni = params["sni"] ?? params["peer"] ?? vmessJson?["sni"] as? String
            if let s = sni, !s.isEmpty { tlsSettings["serverName"] = s }
            let alpn = params["alpn"] ?? vmessJson?["alpn"] as? String
            if let a = alpn, !a.isEmpty {
                tlsSettings["alpn"] = a.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            }
            let fp = params["fp"] ?? params["fingerprint"]
            if let f = fp, !f.isEmpty { tlsSettings["fingerprint"] = f }
            if params["allowInsecure"] == "1" || params["allowInsecure"] == "true" {
                tlsSettings["allowInsecure"] = true
            }
            stream["tlsSettings"] = tlsSettings
        case "reality":
            var realitySettings: [String: Any] = [:]
            let sni = params["sni"] ?? params["peer"]
            if let s = sni, !s.isEmpty { realitySettings["serverName"] = s }
            let fp = params["fp"] ?? params["fingerprint"] ?? "chrome"
            realitySettings["fingerprint"] = fp
            if let pbk = params["pbk"], !pbk.isEmpty { realitySettings["publicKey"] = pbk }
            if let sid = params["sid"], !sid.isEmpty { realitySettings["shortId"] = sid }
            if let spx = params["spx"], !spx.isEmpty { realitySettings["spiderX"] = spx }
            stream["realitySettings"] = realitySettings
        default:
            break
        }

        return stream
    }

    // MARK: - Protocol Parsers

    private func parseVless(_ link: String) -> [String: Any]? {
        guard let url = URL(string: link), let host = url.host, let uuid = url.user else { return nil }
        let port = url.port ?? 443
        let params = queryParams(from: link)

        var user: [String: Any] = [
            "id": uuid,
            "encryption": params["encryption"] ?? "none",
            "level": 0
        ]
        if let flow = params["flow"], !flow.isEmpty { user["flow"] = flow }

        return [
            "tag": "proxy",
            "protocol": "vless",
            "settings": [
                "vnext": [[
                    "address": host,
                    "port": port,
                    "users": [user]
                ]]
            ],
            "streamSettings": buildStreamSettings(params)
        ]
    }

    private func parseVmess(_ link: String) -> [String: Any]? {
        let encoded = String(link.dropFirst("vmess://".count))
        if let data = Data(base64Encoded: paddedBase64(encoded)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return parseVmessJson(json)
        }
        return parseVmessUrl(link)
    }

    private func parseVmessJson(_ json: [String: Any]) -> [String: Any]? {
        guard let address = json["add"] as? String, let uuid = json["id"] as? String else { return nil }
        let port: Int = {
            if let p = json["port"] as? Int { return p }
            if let p = json["port"] as? String, let pi = Int(p) { return pi }
            if let p = json["port"] as? Double { return Int(p) }
            return 443
        }()
        let aid: Int = {
            if let a = json["aid"] as? Int { return a }
            if let a = json["aid"] as? String, let ai = Int(a) { return ai }
            if let a = json["aid"] as? Double { return Int(a) }
            return 0
        }()
        let security = (json["scy"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "auto"

        var params: [String: String] = [:]
        if let net = json["net"] as? String { params["type"] = net }
        if json["tls"] as? String == "tls" { params["security"] = "tls" }
        if let s = json["sni"] as? String { params["sni"] = s }
        if let a = json["alpn"] as? String { params["alpn"] = a }
        if let f = json["fp"] as? String { params["fp"] = f }
        if let p = json["path"] as? String { params["path"] = p }
        if let h = json["host"] as? String { params["host"] = h }
        if let t = json["type"] as? String { params["headerType"] = t }

        return [
            "tag": "proxy",
            "protocol": "vmess",
            "settings": [
                "vnext": [[
                    "address": address,
                    "port": port,
                    "users": [[
                        "id": uuid,
                        "alterId": aid,
                        "security": security,
                        "level": 0
                    ] as [String: Any]]
                ] as [String: Any]]
            ],
            "streamSettings": buildStreamSettings(params, vmessJson: json)
        ]
    }

    private func parseVmessUrl(_ link: String) -> [String: Any]? {
        guard let url = URL(string: link), let host = url.host, let uuid = url.user else { return nil }
        let port = url.port ?? 443
        let params = queryParams(from: link)

        return [
            "tag": "proxy",
            "protocol": "vmess",
            "settings": [
                "vnext": [[
                    "address": host,
                    "port": port,
                    "users": [[
                        "id": uuid,
                        "alterId": 0,
                        "security": "auto",
                        "level": 0
                    ] as [String: Any]]
                ] as [String: Any]]
            ],
            "streamSettings": buildStreamSettings(params)
        ]
    }

    private func parseTrojan(_ link: String) -> [String: Any]? {
        guard let url = URL(string: link), let host = url.host, let password = url.user else { return nil }
        let port = url.port ?? 443
        let params = queryParams(from: link)

        var tlsParams = params
        if tlsParams["security"] == nil { tlsParams["security"] = "tls" }

        return [
            "tag": "proxy",
            "protocol": "trojan",
            "settings": [
                "servers": [[
                    "address": host,
                    "port": port,
                    "password": password,
                    "level": 0
                ] as [String: Any]]
            ],
            "streamSettings": buildStreamSettings(tlsParams)
        ]
    }

    private func parseShadowsocks(_ link: String) -> [String: Any]? {
        var cleanLink = String(link.dropFirst("ss://".count))
        if let hashIdx = cleanLink.firstIndex(of: "#") { cleanLink = String(cleanLink[..<hashIdx]) }
        if let qIdx = cleanLink.firstIndex(of: "?") { cleanLink = String(cleanLink[..<qIdx]) }

        var method = "", password = "", server = "", port = 0

        if cleanLink.contains("@") {
            let parts = cleanLink.components(separatedBy: "@")
            guard parts.count == 2 else { return nil }
            if let data = Data(base64Encoded: paddedBase64(parts[0])),
               let decoded = String(data: data, encoding: .utf8) {
                let creds = decoded.components(separatedBy: ":")
                if creds.count >= 2 {
                    method = creds[0]
                    password = creds.dropFirst().joined(separator: ":")
                }
            }
            let lastColon = parts[1].lastIndex(of: ":") ?? parts[1].endIndex
            server = String(parts[1][..<lastColon])
            let portStr = lastColon < parts[1].endIndex ? String(parts[1][parts[1].index(after: lastColon)...]) : ""
            port = Int(portStr) ?? 0
        } else {
            if let data = Data(base64Encoded: paddedBase64(cleanLink)),
               let decoded = String(data: data, encoding: .utf8) {
                if let atIdx = decoded.lastIndex(of: "@") {
                    let creds = String(decoded[..<atIdx])
                    let serverPart = String(decoded[decoded.index(after: atIdx)...])
                    let colonIdx = creds.firstIndex(of: ":") ?? creds.endIndex
                    method = String(creds[..<colonIdx])
                    if colonIdx < creds.endIndex { password = String(creds[creds.index(after: colonIdx)...]) }
                    let lastColon = serverPart.lastIndex(of: ":") ?? serverPart.endIndex
                    server = String(serverPart[..<lastColon])
                    let portStr = lastColon < serverPart.endIndex ? String(serverPart[serverPart.index(after: lastColon)...]) : ""
                    port = Int(portStr) ?? 0
                }
            }
        }

        guard !server.isEmpty, port > 0 else { return nil }
        return [
            "tag": "proxy",
            "protocol": "shadowsocks",
            "settings": [
                "servers": [[
                    "address": server,
                    "server_port": port,
                    "method": method,
                    "password": password,
                    "level": 0
                ] as [String: Any]]
            ],
            "streamSettings": ["network": "tcp"] as [String: Any]
        ]
    }

    private func parseHysteria2(_ link: String) -> [String: Any]? {
        let normalized = link.replacingOccurrences(of: "hysteria2://", with: "hy2://")
        guard let url = URL(string: normalized), let host = url.host else { return nil }
        let port = url.port ?? 443
        let params = queryParams(from: normalized)

        var stream: [String: Any] = ["network": "tcp", "security": "tls"]
        var tlsSettings: [String: Any] = [:]
        if let sni = params["sni"], !sni.isEmpty { tlsSettings["serverName"] = sni }
        if params["insecure"] == "1" || params["insecure"] == "true" { tlsSettings["allowInsecure"] = true }
        if let alpn = params["alpn"], !alpn.isEmpty {
            tlsSettings["alpn"] = alpn.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        stream["tlsSettings"] = tlsSettings

        return [
            "tag": "proxy",
            "protocol": "hysteria2",
            "settings": [
                "servers": [[
                    "address": host,
                    "port": port,
                    "password": url.user ?? "",
                    "level": 0
                ] as [String: Any]]
            ],
            "streamSettings": stream
        ]
    }

    private func parseWireGuard(_ link: String) -> [String: Any]? {
        guard let url = URL(string: link), let host = url.host else { return nil }
        let port = url.port ?? 51820
        let params = queryParams(from: link)
        let privateKey = url.user ?? ""

        var peer: [String: Any] = ["endpoint": "\(host):\(port)"]
        if let pk = params["publickey"], !pk.isEmpty { peer["publicKey"] = pk }
        if let psk = params["psk"], !psk.isEmpty { peer["preSharedKey"] = psk }

        var settings: [String: Any] = [
            "secretKey": privateKey,
            "peers": [peer]
        ]
        if let addr = params["address"], !addr.isEmpty {
            settings["address"] = addr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        if let reserved = params["reserved"], !reserved.isEmpty {
            let bytes = reserved.components(separatedBy: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            if !bytes.isEmpty { settings["reserved"] = bytes }
        }
        if let mtu = params["mtu"], let v = Int(mtu) { settings["mtu"] = v }

        return [
            "tag": "proxy",
            "protocol": "wireguard",
            "settings": settings
        ]
    }

    // MARK: - Full Config

    private func buildFullConfig(outbound: [String: Any], proxyOnly: Bool) -> [String: Any] {
        let socksPort = configOptions["socks-port"] as? Int ?? 10808
        let httpPort = configOptions["http-port"] as? Int ?? 10809

        var inbounds: [[String: Any]] = [
            [
                "tag": "socks",
                "port": socksPort,
                "listen": "127.0.0.1",
                "protocol": "socks",
                "sniffing": [
                    "enabled": true,
                    "destOverride": ["http", "tls", "quic"],
                    "routeOnly": true
                ],
                "settings": [
                    "auth": "noauth",
                    "udp": true,
                    "userLevel": 8
                ]
            ],
            [
                "tag": "http",
                "port": httpPort,
                "listen": "127.0.0.1",
                "protocol": "http",
                "sniffing": [
                    "enabled": true,
                    "destOverride": ["http", "tls", "quic"],
                    "routeOnly": true
                ],
                "settings": [:] as [String: Any]
            ]
        ]

        if !proxyOnly {
            inbounds.append([
                "tag": "tun",
                "port": 0,
                "protocol": "tun",
                "settings": [
                    "name": "xray0",
                    "MTU": 9000,
                    "userLevel": 8
                ],
                "sniffing": [
                    "enabled": true,
                    "destOverride": ["http", "tls", "quic"]
                ]
            ])
        }

        return [
            "log": ["loglevel": "warning"],
            "dns": buildDns(),
            "inbounds": inbounds,
            "outbounds": [
                outbound,
                ["tag": "direct", "protocol": "freedom", "settings": [:] as [String: Any]],
                ["tag": "block", "protocol": "blackhole", "settings": ["response": ["type": "http"]]]
            ],
            "routing": buildRouting(),
            "stats": [:] as [String: Any],
            "policy": buildPolicy()
        ]
    }

    private func buildDns() -> [String: Any] {
        return [
            "hosts": ["dns.google": "8.8.8.8"],
            "servers": ["https://1.1.1.1/dns-query", "1.1.1.1", "8.8.8.8", "localhost"]
        ]
    }

    private func buildRouting() -> [String: Any] {
        return [
            "domainStrategy": "IPIfNonMatch",
            "rules": [
                [
                    "type": "field",
                    "outboundTag": "direct",
                    "ip": [
                        "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16",
                        "100.64.0.0/10", "169.254.0.0/16", "127.0.0.0/8",
                        "fc00::/7", "fe80::/10", "::1/128"
                    ]
                ],
                [
                    "type": "field",
                    "outboundTag": "block",
                    "protocol": ["bittorrent"]
                ]
            ] as [[String: Any]]
        ]
    }

    private func buildPolicy() -> [String: Any] {
        return [
            "levels": [
                "0": [
                    "statsUserUplink": true,
                    "statsUserDownlink": true
                ],
                "8": [
                    "handshake": 4,
                    "connIdle": 300,
                    "uplinkOnly": 1,
                    "downlinkOnly": 1
                ]
            ],
            "system": [
                "statsOutboundUplink": true,
                "statsOutboundDownlink": true
            ]
        ]
    }

    // MARK: - Helpers

    private func paddedBase64(_ str: String) -> String {
        var s = str.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let remainder = s.count % 4
        if remainder > 0 { s += String(repeating: "=", count: 4 - remainder) }
        return s
    }
}

enum XrayConfigError: LocalizedError {
    case invalidLink
    case serializationFailed

    var errorDescription: String? {
        switch self {
        case .invalidLink: return "Invalid or unsupported config link for Xray"
        case .serializationFailed: return "Failed to serialize Xray config to JSON"
        }
    }
}
