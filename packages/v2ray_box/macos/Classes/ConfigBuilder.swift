import Foundation

class ConfigBuilder {

    private let configOptions: [String: Any]

    init(optionsJson: String) {
        if let data = optionsJson.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            self.configOptions = json
        } else {
            self.configOptions = [:]
        }
    }

    // MARK: - Public

    func buildConfig(from link: String) throws -> String {
        guard let outbound = parseLink(link) else {
            throw ConfigError.invalidLink
        }
        let config = buildFullConfig(outbound: outbound)
        let data = try JSONSerialization.data(withJSONObject: config, options: [.sortedKeys])
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw ConfigError.serializationFailed
        }
        return jsonString
    }

    static func parseOutbound(_ link: String) -> [String: Any]? {
        return ConfigBuilder(optionsJson: "{}").parseLink(link)
    }

    // MARK: - Link Parsing

    private func parseLink(_ link: String) -> [String: Any]? {
        if link.hasPrefix("vless://") { return parseVless(link) }
        if link.hasPrefix("vmess://") { return parseVmess(link) }
        if link.hasPrefix("trojan://") { return parseTrojan(link) }
        if link.hasPrefix("ss://") { return parseShadowsocks(link) }
        if link.hasPrefix("hy2://") || link.hasPrefix("hysteria2://") { return parseHysteria2(link) }
        if link.hasPrefix("hy://") || link.hasPrefix("hysteria://") { return parseHysteria(link) }
        if link.hasPrefix("tuic://") { return parseTuic(link) }
        if link.hasPrefix("wg://") { return parseWireGuard(link) }
        if link.hasPrefix("ssh://") { return parseSsh(link) }
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

    // MARK: - Transport

    private func buildTransport(_ params: [String: String], vmessJson: [String: Any]? = nil) -> [String: Any]? {
        let transportType = params["type"] ?? vmessJson?["net"] as? String ?? "tcp"
        if transportType == "tcp" || transportType.isEmpty { return nil }

        switch transportType {
        case "ws", "websocket":
            var t: [String: Any] = ["type": "ws"]
            let path = params["path"] ?? vmessJson?["path"] as? String
            if let p = path, !p.isEmpty { t["path"] = p }
            let host = params["host"] ?? vmessJson?["host"] as? String
            if let h = host, !h.isEmpty { t["headers"] = ["Host": h] }
            if let med = params["max-early-data"], let v = Int(med) { t["max_early_data"] = v }
            if let edh = params["early-data-header-name"], !edh.isEmpty { t["early_data_header_name"] = edh }
            return t
        case "grpc":
            var t: [String: Any] = ["type": "grpc"]
            let sn = params["serviceName"] ?? params["service-name"] ?? vmessJson?["path"] as? String
            if let s = sn, !s.isEmpty { t["service_name"] = s }
            return t
        case "http", "h2":
            var t: [String: Any] = ["type": "http"]
            let path = params["path"] ?? vmessJson?["path"] as? String
            if let p = path, !p.isEmpty { t["path"] = p }
            let host = params["host"] ?? vmessJson?["host"] as? String
            if let h = host, !h.isEmpty { t["host"] = h.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
            return t
        case "httpupgrade", "xhttp":
            var t: [String: Any] = ["type": "httpupgrade"]
            let path = params["path"] ?? vmessJson?["path"] as? String
            if let p = path, !p.isEmpty { t["path"] = p }
            let host = params["host"] ?? vmessJson?["host"] as? String
            if let h = host, !h.isEmpty { t["host"] = h }
            return t
        case "quic":
            return ["type": "quic"]
        default:
            return nil
        }
    }

    // MARK: - TLS

    private func buildTls(_ params: [String: String], vmessJson: [String: Any]? = nil) -> [String: Any]? {
        let security = params["security"] ?? {
            if vmessJson?["tls"] as? String == "tls" { return "tls" }
            return nil
        }()
        guard let sec = security, sec == "tls" || sec == "reality" || sec == "xtls" else { return nil }

        var tls: [String: Any] = ["enabled": true]
        let sni = params["sni"] ?? params["peer"] ?? vmessJson?["sni"] as? String
        if let s = sni, !s.isEmpty { tls["server_name"] = s }
        let alpn = params["alpn"] ?? vmessJson?["alpn"] as? String
        if let a = alpn, !a.isEmpty {
            tls["alpn"] = a.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        let fp = params["fp"] ?? params["fingerprint"]
        if let f = fp, !f.isEmpty { tls["utls"] = ["enabled": true, "fingerprint": f] }
        if params["allowInsecure"] == "1" || params["allowInsecure"] == "true" ||
           params["insecure"] == "1" || params["insecure"] == "true" {
            tls["insecure"] = true
        }
        if sec == "reality" {
            var reality: [String: Any] = ["enabled": true]
            if let pbk = params["pbk"], !pbk.isEmpty { reality["public_key"] = pbk }
            if let sid = params["sid"], !sid.isEmpty { reality["short_id"] = sid }
            tls["reality"] = reality
            if tls["utls"] == nil { tls["utls"] = ["enabled": true, "fingerprint": fp ?? "chrome"] }
        }
        return tls
    }

    // MARK: - Multiplex

    private func buildMux(_ params: [String: String]) -> [String: Any]? {
        guard let m = params["mux"], m == "1" || m == "true" else { return nil }
        var mux: [String: Any] = ["enabled": true, "protocol": "h2mux"]
        if let ms = params["mux-max-streams"], let v = Int(ms) { mux["max_streams"] = v }
        return mux
    }

    // MARK: - Protocol Parsers

    private func parseVless(_ link: String) -> [String: Any]? {
        guard let url = URL(string: link), let host = url.host, let uuid = url.user else { return nil }
        let port = url.port ?? 443
        let params = queryParams(from: link)
        var outbound: [String: Any] = [
            "type": "vless", "tag": "proxy",
            "server": host, "server_port": port, "uuid": uuid
        ]
        if let flow = params["flow"], !flow.isEmpty { outbound["flow"] = flow }
        if let pe = params["packet_encoding"], !pe.isEmpty { outbound["packet_encoding"] = pe }
        if let t = buildTransport(params) { outbound["transport"] = t }
        if let t = buildTls(params) { outbound["tls"] = t }
        if let m = buildMux(params) { outbound["multiplex"] = m }
        return outbound
    }

    private func parseVmess(_ link: String) -> [String: Any]? {
        let encoded = String(link.dropFirst("vmess://".count))
        if let data = Data(base64Encoded: encoded),
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
        let net = json["net"] as? String ?? "tcp"
        var outbound: [String: Any] = [
            "type": "vmess", "tag": "proxy",
            "server": address, "server_port": port,
            "uuid": uuid, "alter_id": aid, "security": security
        ]
        if let t = buildTransport(["type": net], vmessJson: json) { outbound["transport"] = t }
        var tlsParams: [String: String] = [:]
        if json["tls"] as? String == "tls" { tlsParams["security"] = "tls" }
        if let s = json["sni"] as? String { tlsParams["sni"] = s }
        if let a = json["alpn"] as? String { tlsParams["alpn"] = a }
        if let f = json["fp"] as? String { tlsParams["fp"] = f }
        if let t = buildTls(tlsParams, vmessJson: json) { outbound["tls"] = t }
        return outbound
    }

    private func parseVmessUrl(_ link: String) -> [String: Any]? {
        guard let url = URL(string: link), let host = url.host, let uuid = url.user else { return nil }
        let port = url.port ?? 443
        let params = queryParams(from: link)
        var outbound: [String: Any] = [
            "type": "vmess", "tag": "proxy",
            "server": host, "server_port": port,
            "uuid": uuid, "alter_id": 0, "security": "auto"
        ]
        if let t = buildTransport(params) { outbound["transport"] = t }
        if let t = buildTls(params) { outbound["tls"] = t }
        return outbound
    }

    private func parseTrojan(_ link: String) -> [String: Any]? {
        guard let url = URL(string: link), let host = url.host, let password = url.user else { return nil }
        let port = url.port ?? 443
        let params = queryParams(from: link)
        var outbound: [String: Any] = [
            "type": "trojan", "tag": "proxy",
            "server": host, "server_port": port, "password": password
        ]
        if let t = buildTransport(params) { outbound["transport"] = t }
        var tlsParams = params
        if tlsParams["security"] == nil { tlsParams["security"] = "tls" }
        if let t = buildTls(tlsParams) { outbound["tls"] = t }
        else { outbound["tls"] = ["enabled": true] as [String: Any] }
        if let m = buildMux(params) { outbound["multiplex"] = m }
        return outbound
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
                if creds.count >= 2 { method = creds[0]; password = creds.dropFirst().joined(separator: ":") }
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
        return ["type": "shadowsocks", "tag": "proxy", "server": server, "server_port": port, "method": method, "password": password]
    }

    private func parseHysteria2(_ link: String) -> [String: Any]? {
        let normalized = link.replacingOccurrences(of: "hysteria2://", with: "hy2://")
        guard let url = URL(string: normalized), let host = url.host else { return nil }
        let port = url.port ?? 443
        let params = queryParams(from: normalized)
        var outbound: [String: Any] = ["type": "hysteria2", "tag": "proxy", "server": host, "server_port": port, "password": url.user ?? ""]
        if let obfsType = params["obfs"], !obfsType.isEmpty {
            var obfs: [String: Any] = ["type": obfsType]
            if let op = params["obfs-password"], !op.isEmpty { obfs["password"] = op }
            outbound["obfs"] = obfs
        }
        var tls: [String: Any] = ["enabled": true]
        if let sni = params["sni"], !sni.isEmpty { tls["server_name"] = sni }
        if params["insecure"] == "1" || params["insecure"] == "true" { tls["insecure"] = true }
        if let alpn = params["alpn"], !alpn.isEmpty { tls["alpn"] = alpn.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
        outbound["tls"] = tls
        return outbound
    }

    private func parseHysteria(_ link: String) -> [String: Any]? {
        let normalized = link.replacingOccurrences(of: "hysteria://", with: "hy://")
        guard let url = URL(string: normalized), let host = url.host else { return nil }
        let port = url.port ?? 443
        let params = queryParams(from: normalized)
        var outbound: [String: Any] = ["type": "hysteria", "tag": "proxy", "server": host, "server_port": port]
        let auth = url.user ?? params["auth"]
        if let a = auth, !a.isEmpty { outbound["auth_str"] = a }
        if let up = params["upmbps"], let v = Int(up) { outbound["up_mbps"] = v }
        if let down = params["downmbps"], let v = Int(down) { outbound["down_mbps"] = v }
        if params["obfs"] == "xplus" { outbound["obfs"] = params["obfsParam"] ?? "" }
        if let proto = params["protocol"], !proto.isEmpty { outbound["protocol"] = proto }
        var tls: [String: Any] = ["enabled": true]
        let sni = params["peer"] ?? params["sni"]
        if let s = sni, !s.isEmpty { tls["server_name"] = s }
        if params["insecure"] == "1" || params["insecure"] == "true" { tls["insecure"] = true }
        if let alpn = params["alpn"], !alpn.isEmpty { tls["alpn"] = alpn.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
        outbound["tls"] = tls
        return outbound
    }

    private func parseTuic(_ link: String) -> [String: Any]? {
        guard let url = URL(string: link), let host = url.host else { return nil }
        let port = url.port ?? 443
        let params = queryParams(from: link)
        let userInfo = url.user ?? ""
        let parts = userInfo.components(separatedBy: ":")
        let uuid = parts[0]
        let password = parts.count > 1 ? parts.dropFirst().joined(separator: ":") : ""
        var outbound: [String: Any] = ["type": "tuic", "tag": "proxy", "server": host, "server_port": port, "uuid": uuid, "password": password]
        if let cc = params["congestion_control"], !cc.isEmpty { outbound["congestion_control"] = cc }
        if let ur = params["udp_relay_mode"], !ur.isEmpty { outbound["udp_relay_mode"] = ur }
        var tls: [String: Any] = ["enabled": true]
        if let sni = params["sni"], !sni.isEmpty { tls["server_name"] = sni }
        if let alpn = params["alpn"], !alpn.isEmpty { tls["alpn"] = alpn.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
        if params["allowInsecure"] == "1" || params["allowInsecure"] == "true" { tls["insecure"] = true }
        outbound["tls"] = tls
        return outbound
    }

    private func parseWireGuard(_ link: String) -> [String: Any]? {
        guard let url = URL(string: link), let host = url.host else { return nil }
        let port = url.port ?? 51820
        let params = queryParams(from: link)
        var outbound: [String: Any] = ["type": "wireguard", "tag": "proxy", "server": host, "server_port": port, "private_key": url.user ?? ""]
        if let pk = params["publickey"], !pk.isEmpty { outbound["peer_public_key"] = pk }
        if let psk = params["psk"], !psk.isEmpty { outbound["pre_shared_key"] = psk }
        if let addr = params["address"], !addr.isEmpty { outbound["local_address"] = addr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
        if let reserved = params["reserved"], !reserved.isEmpty {
            let bytes = reserved.components(separatedBy: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            if !bytes.isEmpty { outbound["reserved"] = bytes }
        }
        if let mtu = params["mtu"], let v = Int(mtu) { outbound["mtu"] = v }
        return outbound
    }

    private func parseSsh(_ link: String) -> [String: Any]? {
        guard let url = URL(string: link), let host = url.host else { return nil }
        let port = url.port ?? 22
        let params = queryParams(from: link)
        var outbound: [String: Any] = ["type": "ssh", "tag": "proxy", "server": host, "server_port": port, "user": url.user ?? ""]
        if let pw = url.password, !pw.isEmpty { outbound["password"] = pw }
        if let pk = params["pk"], !pk.isEmpty { outbound["private_key"] = pk }
        if let pkp = params["pkp"], !pkp.isEmpty { outbound["private_key_passphrase"] = pkp }
        if let hk = params["hk"], !hk.isEmpty { outbound["host_key"] = hk.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
        return outbound
    }

    // MARK: - Full Config (Proxy Mode for macOS)

    private func buildFullConfig(outbound: [String: Any]) -> [String: Any] {
        let logLevel = configOptions["log-level"] as? String ?? "warn"
        let mixedPort = configOptions["mixed-port"] as? Int ?? 2080
        let enableClashApi = configOptions["enable-clash-api"] as? Bool ?? true
        let clashApiPort = configOptions["clash-api-port"] as? Int ?? 9090

        var config: [String: Any] = [
            "log": ["level": logLevel, "timestamp": true],
            "dns": [
                "servers": [
                    ["type": "https", "tag": "dns-remote", "server": "1.1.1.1", "server_port": 443, "detour": "proxy"],
                    ["type": "local", "tag": "dns-direct"]
                ] as [[String: Any]],
                "strategy": "prefer_ipv4",
                "independent_cache": true
            ],
            "inbounds": [
                ["type": "mixed", "tag": "mixed-in", "listen": "127.0.0.1", "listen_port": mixedPort]
            ] as [[String: Any]],
            "outbounds": [outbound, ["type": "direct", "tag": "direct"]],
            "route": [
                "rules": [
                    ["action": "sniff"],
                    ["protocol": "dns", "action": "hijack-dns"],
                    ["ip_is_private": true, "outbound": "direct"]
                ] as [[String: Any]],
                "auto_detect_interface": true,
                "default_domain_resolver": ["server": "dns-direct"],
                "final": "proxy"
            ]
        ]

        var exp: [String: Any] = ["cache_file": ["enabled": true, "store_fakeip": true]]
        if enableClashApi { exp["clash_api"] = ["external_controller": "127.0.0.1:\(clashApiPort)"] }
        config["experimental"] = exp

        return config
    }

    // MARK: - Helpers

    private func paddedBase64(_ str: String) -> String {
        var s = str.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let remainder = s.count % 4
        if remainder > 0 { s += String(repeating: "=", count: 4 - remainder) }
        return s
    }
}

enum ConfigError: LocalizedError {
    case invalidLink
    case serializationFailed

    var errorDescription: String? {
        switch self {
        case .invalidLink: return "Invalid or unsupported config link"
        case .serializationFailed: return "Failed to serialize config to JSON"
        }
    }
}
