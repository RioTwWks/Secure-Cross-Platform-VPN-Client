import Cocoa
import FlutterMacOS
import Network

public class V2rayBoxPlugin: NSObject, FlutterPlugin {
    private var methodChannel: FlutterMethodChannel?
    private var statusChannel: FlutterEventChannel?
    private var alertsChannel: FlutterEventChannel?
    private var statsChannel: FlutterEventChannel?
    private var pingChannel: FlutterEventChannel?
    private var logsChannel: FlutterEventChannel?
    
    private var statusEventSink: FlutterEventSink?
    private var alertsEventSink: FlutterEventSink?
    private var statsEventSink: FlutterEventSink?
    private var pingEventSink: FlutterEventSink?
    private var logsEventSink: FlutterEventSink?
    
    private var debugMode: Bool {
        get { UserDefaults.standard.bool(forKey: "v2ray_box_debug_mode") }
        set { UserDefaults.standard.set(newValue, forKey: "v2ray_box_debug_mode") }
    }
    
    private var pingTestUrl: String {
        get { UserDefaults.standard.string(forKey: "v2ray_box_ping_test_url") ?? "http://connectivitycheck.gstatic.com/generate_204" }
        set { UserDefaults.standard.set(newValue, forKey: "v2ray_box_ping_test_url") }
    }
    
    private var coreEngine: String {
        get { UserDefaults.standard.string(forKey: "v2ray_box_core_engine") ?? "singbox" }
        set { UserDefaults.standard.set(newValue, forKey: "v2ray_box_core_engine") }
    }
    
    private var statsTimer: Timer?
    private var configOptions: String = "{}"
    private var activeConfigPath: String = ""
    private var activeProfileName: String = ""
    private var isRunning: Bool = false
    
    private var lastSingboxUpload: Int64 = 0
    private var lastSingboxDownload: Int64 = 0
    
    private var singboxConfigBuilder: ConfigBuilder {
        return ConfigBuilder(optionsJson: configOptions)
    }
    
    private var xrayConfigBuilder: XrayConfigBuilder {
        return XrayConfigBuilder(optionsJson: configOptions)
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "v2ray_box", binaryMessenger: registrar.messenger)
        let instance = V2rayBoxPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        instance.methodChannel = channel
        
        let statusChannel = FlutterEventChannel(
            name: "v2ray_box/status",
            binaryMessenger: registrar.messenger,
            codec: FlutterJSONMethodCodec.sharedInstance()
        )
        statusChannel.setStreamHandler(StatusStreamHandler(plugin: instance))
        instance.statusChannel = statusChannel
        
        let alertsChannel = FlutterEventChannel(
            name: "v2ray_box/alerts",
            binaryMessenger: registrar.messenger,
            codec: FlutterJSONMethodCodec.sharedInstance()
        )
        alertsChannel.setStreamHandler(AlertsStreamHandler(plugin: instance))
        instance.alertsChannel = alertsChannel
        
        let statsChannel = FlutterEventChannel(
            name: "v2ray_box/stats",
            binaryMessenger: registrar.messenger,
            codec: FlutterJSONMethodCodec.sharedInstance()
        )
        statsChannel.setStreamHandler(StatsStreamHandler(plugin: instance))
        instance.statsChannel = statsChannel
        
        let pingChannel = FlutterEventChannel(
            name: "v2ray_box/ping",
            binaryMessenger: registrar.messenger,
            codec: FlutterJSONMethodCodec.sharedInstance()
        )
        pingChannel.setStreamHandler(PingStreamHandler(plugin: instance))
        instance.pingChannel = pingChannel
        
        let logsChannel = FlutterEventChannel(
            name: "v2ray_box/logs",
            binaryMessenger: registrar.messenger,
            codec: FlutterJSONMethodCodec.sharedInstance()
        )
        logsChannel.setStreamHandler(LogsStreamHandler(plugin: instance))
        instance.logsChannel = logsChannel
    }
    
    deinit {
        statsTimer?.invalidate()
        coreMonitorTimer?.invalidate()
        if isRunning {
            stopCore()
            disableSystemProxy()
        }
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
            
        case "setup":
            setup(result: result)
            
        case "parse_config":
            guard let args = call.arguments as? [String: Any],
                  let link = args["link"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing link parameter", details: nil))
                return
            }
            parseConfig(link: link, result: result)
            
        case "change_config_options":
            guard let options = call.arguments as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing options parameter", details: nil))
                return
            }
            configOptions = options
            result(true)
            
        case "generate_config":
            guard let args = call.arguments as? [String: Any],
                  let link = args["link"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing link parameter", details: nil))
                return
            }
            generateConfig(link: link, result: result)
            
        case "start":
            guard let args = call.arguments as? [String: Any],
                  let link = args["link"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing link parameter", details: nil))
                return
            }
            let name = args["name"] as? String ?? ""
            start(link: link, name: name, result: result)
            
        case "stop":
            stop(result: result)
            
        case "restart":
            guard let args = call.arguments as? [String: Any],
                  let link = args["link"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing link parameter", details: nil))
                return
            }
            let name = args["name"] as? String ?? ""
            restart(link: link, name: name, result: result)
            
        case "check_vpn_permission":
            result(true)
            
        case "request_vpn_permission":
            result(true)
            
        case "set_service_mode":
            result(true)
            
        case "get_service_mode":
            result("proxy")
            
        case "set_notification_stop_button_text", "set_notification_title", "set_notification_icon":
            result(true)
            
        case "get_installed_packages":
            result("[]")
            
        case "get_package_icon":
            result(nil)
            
        case "url_test":
            guard let args = call.arguments as? [String: Any],
                  let link = args["link"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing link parameter", details: nil))
                return
            }
            let timeout = args["timeout"] as? Int ?? 5000
            urlTest(link: link, timeout: timeout, result: result)
            
        case "url_test_all":
            guard let args = call.arguments as? [String: Any],
                  let links = args["links"] as? [String] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing links parameter", details: nil))
                return
            }
            let timeout = args["timeout"] as? Int ?? 5000
            urlTestAll(links: links, timeout: timeout, result: result)
            
        case "set_per_app_proxy_mode", "set_per_app_proxy_list":
            result(true)
            
        case "get_per_app_proxy_mode":
            result("off")
            
        case "get_per_app_proxy_list":
            result([String]())
            
        case "get_total_traffic":
            result(["upload": 0, "download": 0])
            
        case "reset_total_traffic":
            lastSingboxUpload = 0
            lastSingboxDownload = 0
            result(true)
            
        case "set_core_engine":
            if let engine = call.arguments as? String,
               engine == "xray" || engine == "singbox" {
                coreEngine = engine
                result(true)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Engine must be 'xray' or 'singbox'", details: nil))
            }
            
        case "get_core_engine":
            result(coreEngine)
            
        case "get_core_info":
            if coreEngine == "xray" {
                let version = XrayProcess.shared.getVersion()
                result(["engine": "xray", "core": "xray-core", "version": version] as [String: Any])
            } else {
                let version = SingboxProcess.shared.getVersion()
                result(["engine": "singbox", "core": "sing-box", "version": version] as [String: Any])
            }
            
        case "check_config_json":
            guard let configJson = call.arguments as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing config JSON", details: nil))
                return
            }
            if let data = configJson.data(using: .utf8),
               let _ = try? JSONSerialization.jsonObject(with: data) {
                result("")
            } else {
                result("Invalid JSON format")
            }
            
        case "start_with_json":
            guard let args = call.arguments as? [String: Any],
                  let configJson = args["config"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing config parameter", details: nil))
                return
            }
            let name = args["name"] as? String ?? ""
            startWithJson(configJson: configJson, name: name, result: result)
            
        case "get_logs":
            result([String]())
            
        case "set_debug_mode":
            if let enabled = call.arguments as? Bool {
                debugMode = enabled
            }
            result(true)
            
        case "get_debug_mode":
            result(debugMode)
            
        case "format_bytes":
            let bytes: Int64
            if let b = call.arguments as? Int64 { bytes = b }
            else if let b = call.arguments as? Int { bytes = Int64(b) }
            else { result("0 B"); return }
            result(formatBytesLocal(bytes))
            
        case "get_active_config":
            getActiveConfig(result: result)
            
        case "proxy_display_type":
            if let type = call.arguments as? String {
                result(type.prefix(1).uppercased() + type.dropFirst())
            } else {
                result("")
            }
            
        case "format_config":
            guard let configJson = call.arguments as? String else {
                result("")
                return
            }
            if let data = configJson.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data),
               let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
               let str = String(data: pretty, encoding: .utf8) {
                result(str)
            } else {
                result(configJson)
            }
            
        case "available_port":
            if let startPort = call.arguments as? Int {
                result(findAvailablePort(from: startPort))
            } else {
                result(-1)
            }
            
        case "select_outbound":
            result(false)
            
        case "set_clash_mode":
            result(false)
            
        case "parse_subscription":
            result([String: Any]())
            
        case "generate_subscription_link":
            result("")
            
        case "set_locale":
            result(true)
            
        case "set_ping_test_url":
            if let url = call.arguments as? String {
                pingTestUrl = url
            }
            result(true)
            
        case "get_ping_test_url":
            result(pingTestUrl)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Setup
    
    private func setup(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let fileManager = FileManager.default
                let baseDir = self.getBaseDirectory()
                let workingDir = self.getWorkingDirectory()
                let tempDir = self.getTempDirectory()
                
                try fileManager.createDirectory(at: baseDir, withIntermediateDirectories: true)
                try fileManager.createDirectory(at: workingDir, withIntermediateDirectories: true)
                try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
                
                DispatchQueue.main.async {
                    result("")
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "SETUP_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    // MARK: - Parse Config
    
    private func parseConfig(link: String, result: @escaping FlutterResult) {
        result("")
    }
    
    // MARK: - Generate Config
    
    private func generateConfig(link: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let config: String
                if self.coreEngine == "xray" {
                    config = try self.xrayConfigBuilder.buildConfig(from: link, proxyOnly: true)
                } else {
                    config = try self.singboxConfigBuilder.buildConfig(from: link)
                }
                DispatchQueue.main.async {
                    result(config)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "BUILD_CONFIG", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    // MARK: - Start
    
    private func start(link: String, name: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                self.activeProfileName = name
                
                let config: String
                if self.coreEngine == "xray" {
                    config = try self.xrayConfigBuilder.buildConfig(from: link, proxyOnly: true)
                } else {
                    config = try self.singboxConfigBuilder.buildConfig(from: link)
                }
                
                let configPath = self.getWorkingDirectory().appendingPathComponent("profiles/active_config.json")
                try FileManager.default.createDirectory(
                    at: configPath.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try config.write(to: configPath, atomically: true, encoding: .utf8)
                self.activeConfigPath = configPath.path
                
                print("V2rayBox: Config saved to \(configPath.path)")
                
                DispatchQueue.main.async {
                    self.statusEventSink?(["status": "Starting"])
                }
                
                let success = self.startCore(configPath: configPath.path)
                
                if success {
                    self.isRunning = true
                    let port = self.getProxyPort()
                    self.enableSystemProxy(port: port)
                    self.startCoreMonitor()
                    
                    DispatchQueue.main.async {
                        self.statusEventSink?(["status": "Started"])
                        result(true)
                    }
                } else {
                    self.isRunning = false
                    DispatchQueue.main.async {
                        self.statusEventSink?(["status": "Stopped"])
                        result(FlutterError(code: "START_ERROR", message: "Failed to start \(self.coreEngine) core", details: nil))
                    }
                }
            } catch {
                print("V2rayBox: Start exception: \(error)")
                self.isRunning = false
                DispatchQueue.main.async {
                    self.statusEventSink?(["status": "Stopped"])
                    result(FlutterError(code: "START_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func startCore(configPath: String) -> Bool {
        if coreEngine == "xray" {
            return XrayProcess.shared.start(configPath: configPath)
        } else {
            let workDir = getWorkingDirectory().path
            return SingboxProcess.shared.start(configPath: configPath, workingDir: workDir)
        }
    }
    
    private func stopCore() {
        if coreEngine == "xray" || XrayProcess.shared.isRunning {
            XrayProcess.shared.stop()
        }
        if coreEngine == "singbox" || SingboxProcess.shared.isRunning {
            SingboxProcess.shared.stop()
        }
    }
    
    private var coreMonitorTimer: Timer?
    
    private func startCoreMonitor() {
        stopCoreMonitor()
        failedPortChecks = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self, self.isRunning else { return }
            self.coreMonitorTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
                self?.checkCoreStatus()
            }
        }
    }
    
    private func stopCoreMonitor() {
        coreMonitorTimer?.invalidate()
        coreMonitorTimer = nil
    }
    
    private var failedPortChecks = 0
    
    private func checkCoreStatus() {
        guard isRunning else {
            stopCoreMonitor()
            return
        }
        
        let isCoreRunning: Bool
        if coreEngine == "xray" {
            isCoreRunning = XrayProcess.shared.isRunning
        } else {
            isCoreRunning = SingboxProcess.shared.isRunning
        }
        
        if !isCoreRunning {
            failedPortChecks += 1
            if failedPortChecks >= 3 {
                print("V2rayBox: Core appears to have stopped (process not running)")
                DispatchQueue.main.async {
                    self.isRunning = false
                    self.stopCoreMonitor()
                    self.disableSystemProxy()
                    self.statusEventSink?(["status": "Stopped"])
                }
            }
        } else {
            failedPortChecks = 0
        }
    }
    
    // MARK: - Stop
    
    private func stop(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.stopCoreMonitor()
            }
            
            if !self.isRunning {
                DispatchQueue.main.async {
                    result(true)
                }
                return
            }
            
            DispatchQueue.main.async {
                self.statusEventSink?(["status": "Stopping"])
            }
            
            self.stopCore()
            self.disableSystemProxy()
            
            self.isRunning = false
            DispatchQueue.main.async {
                self.statusEventSink?(["status": "Stopped"])
                result(true)
            }
        }
    }
    
    // MARK: - Restart
    
    private func restart(link: String, name: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.stopCore()
            self.disableSystemProxy()
            
            do {
                self.activeProfileName = name
                
                let config: String
                if self.coreEngine == "xray" {
                    config = try self.xrayConfigBuilder.buildConfig(from: link, proxyOnly: true)
                } else {
                    config = try self.singboxConfigBuilder.buildConfig(from: link)
                }
                
                let configPath = self.getWorkingDirectory().appendingPathComponent("profiles/active_config.json")
                try FileManager.default.createDirectory(
                    at: configPath.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try config.write(to: configPath, atomically: true, encoding: .utf8)
                self.activeConfigPath = configPath.path
                
                DispatchQueue.main.async {
                    self.statusEventSink?(["status": "Starting"])
                }
                
                let success = self.startCore(configPath: configPath.path)
                
                if success {
                    self.isRunning = true
                    let port = self.getProxyPort()
                    self.enableSystemProxy(port: port)
                    self.startCoreMonitor()
                    
                    DispatchQueue.main.async {
                        self.statusEventSink?(["status": "Started"])
                        result(true)
                    }
                } else {
                    self.isRunning = false
                    DispatchQueue.main.async {
                        self.statusEventSink?(["status": "Stopped"])
                        result(FlutterError(code: "RESTART_ERROR", message: "Failed to restart \(self.coreEngine) core", details: nil))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "RESTART_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    // MARK: - Start With JSON
    
    private func startWithJson(configJson: String, name: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                self.activeProfileName = name
                
                let configPath = self.getWorkingDirectory().appendingPathComponent("profiles/active_config.json")
                try FileManager.default.createDirectory(at: configPath.deletingLastPathComponent(), withIntermediateDirectories: true)
                try configJson.write(to: configPath, atomically: true, encoding: .utf8)
                self.activeConfigPath = configPath.path
                
                DispatchQueue.main.async { self.statusEventSink?(["status": "Starting"]) }
                
                let success = self.startCore(configPath: configPath.path)
                
                if success {
                    self.isRunning = true
                    let port = self.getProxyPort()
                    self.enableSystemProxy(port: port)
                    self.startCoreMonitor()
                    
                    DispatchQueue.main.async {
                        self.statusEventSink?(["status": "Started"])
                        result(true)
                    }
                } else {
                    self.isRunning = false
                    DispatchQueue.main.async {
                        self.statusEventSink?(["status": "Stopped"])
                        result(FlutterError(code: "START_ERROR", message: "Failed to start \(self.coreEngine) core", details: nil))
                    }
                }
            } catch {
                self.isRunning = false
                DispatchQueue.main.async {
                    self.statusEventSink?(["status": "Stopped"])
                    result(FlutterError(code: "START_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    // MARK: - URL Test
    
    private func urlTest(link: String, timeout: Int, result: @escaping FlutterResult) {
        Task {
            let latency = await performURLTest(link: link, timeout: timeout)
            DispatchQueue.main.async {
                result(latency)
            }
        }
    }
    
    private func urlTestAll(links: [String], timeout: Int, result: @escaping FlutterResult) {
        Task {
            var results: [String: Int] = [:]
            
            await withTaskGroup(of: (String, Int).self) { group in
                for link in links {
                    group.addTask {
                        let latency = await self.performURLTest(link: link, timeout: timeout)
                        return (link, latency)
                    }
                }
                
                for await (link, latency) in group {
                    results[link] = latency
                    let eventData: [String: Any] = ["link": link, "latency": latency]
                    DispatchQueue.main.async {
                        self.pingEventSink?(eventData)
                    }
                }
            }
            
            DispatchQueue.main.async {
                result(results)
            }
        }
    }
    
    private func performURLTest(link: String, timeout: Int) async -> Int {
        guard let (host, port) = parseServerFromLink(link),
              !host.isEmpty, port > 0 else {
            return -1
        }
        
        return await withCheckedContinuation { continuation in
            let startTime = CFAbsoluteTimeGetCurrent()
            
            let endpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(integerLiteral: UInt16(port))
            )
            
            let parameters = NWParameters.tcp
            parameters.expiredDNSBehavior = .allow
            
            let connection = NWConnection(to: endpoint, using: parameters)
            
            var hasCompleted = false
            let lock = NSLock()
            
            let timeoutWorkItem = DispatchWorkItem {
                lock.lock()
                if !hasCompleted {
                    hasCompleted = true
                    lock.unlock()
                    connection.cancel()
                    continuation.resume(returning: -1)
                } else {
                    lock.unlock()
                }
            }
            
            DispatchQueue.global().asyncAfter(
                deadline: .now() + .milliseconds(timeout),
                execute: timeoutWorkItem
            )
            
            connection.stateUpdateHandler = { state in
                lock.lock()
                guard !hasCompleted else {
                    lock.unlock()
                    return
                }
                
                switch state {
                case .ready:
                    hasCompleted = true
                    lock.unlock()
                    timeoutWorkItem.cancel()
                    let elapsed = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                    connection.cancel()
                    continuation.resume(returning: elapsed)
                    
                case .failed(_), .cancelled:
                    hasCompleted = true
                    lock.unlock()
                    timeoutWorkItem.cancel()
                    continuation.resume(returning: -1)
                    
                default:
                    lock.unlock()
                }
            }
            
            connection.start(queue: DispatchQueue.global())
        }
    }
    
    private func parseServerFromLink(_ link: String) -> (String, Int)? {
        if link.hasPrefix("vmess://") {
            return parseVmessServer(link)
        } else if link.hasPrefix("vless://") || link.hasPrefix("trojan://") || link.hasPrefix("ss://") ||
                    link.hasPrefix("hy2://") || link.hasPrefix("hysteria2://") ||
                    link.hasPrefix("hy://") || link.hasPrefix("hysteria://") ||
                    link.hasPrefix("tuic://") || link.hasPrefix("wg://") || link.hasPrefix("ssh://") {
            guard let url = URL(string: link), let host = url.host else { return nil }
            let port = url.port ?? 443
            return (host, port)
        }
        return nil
    }
    
    private func parseVmessServer(_ link: String) -> (String, Int)? {
        let encoded = String(link.dropFirst("vmess://".count))
        guard let data = Data(base64Encoded: encoded),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let host = json["add"] as? String else { return nil }
        let port: Int
        if let portNum = json["port"] as? Int {
            port = portNum
        } else if let portStr = json["port"] as? String, let portNum = Int(portStr) {
            port = portNum
        } else {
            port = 443
        }
        return (host, port)
    }
    
    // MARK: - System Proxy
    
    private func enableSystemProxy(port: Int) {
        let host = "127.0.0.1"
        let services = getActiveNetworkServices()
        print("V2rayBox: Setting system proxy on services: \(services)")
        for service in services {
            runNetworkSetup(["-setwebproxy", service, host, "\(port)"])
            runNetworkSetup(["-setsecurewebproxy", service, host, "\(port)"])
            runNetworkSetup(["-setsocksfirewallproxy", service, host, "\(port)"])
            runNetworkSetup(["-setwebproxystate", service, "on"])
            runNetworkSetup(["-setsecurewebproxystate", service, "on"])
            runNetworkSetup(["-setsocksfirewallproxystate", service, "on"])
        }
    }
    
    private func disableSystemProxy() {
        let services = getActiveNetworkServices()
        for service in services {
            runNetworkSetup(["-setwebproxystate", service, "off"])
            runNetworkSetup(["-setsecurewebproxystate", service, "off"])
            runNetworkSetup(["-setsocksfirewallproxystate", service, "off"])
        }
    }
    
    @discardableResult
    private func runNetworkSetup(_ args: [String]) -> Bool {
        do {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
            task.arguments = args
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    private func getActiveNetworkServices() -> [String] {
        do {
            let task = Process()
            let pipe = Pipe()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
            task.arguments = ["-listallnetworkservices"]
            task.standardOutput = pipe
            task.standardError = FileHandle.nullDevice
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return ["Wi-Fi"] }
            
            var services: [String] = []
            for line in output.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty || trimmed.hasPrefix("An asterisk") || trimmed.hasPrefix("*") { continue }
                
                let checkTask = Process()
                let checkPipe = Pipe()
                checkTask.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
                checkTask.arguments = ["-getinfo", trimmed]
                checkTask.standardOutput = checkPipe
                checkTask.standardError = FileHandle.nullDevice
                try checkTask.run()
                checkTask.waitUntilExit()
                let info = String(data: checkPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                if info.contains("IP address:") && !info.contains("IP address: none") {
                    services.append(trimmed)
                }
            }
            return services.isEmpty ? ["Wi-Fi"] : services
        } catch {
            return ["Wi-Fi"]
        }
    }
    
    private func getProxyPort() -> Int {
        if let data = configOptions.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if coreEngine == "xray" {
                return json["socks-port"] as? Int ?? 10808
            } else {
                return json["mixed-port"] as? Int ?? 2080
            }
        }
        return coreEngine == "xray" ? 10808 : 2080
    }
    
    // MARK: - Get Active Config
    
    private func getActiveConfig(result: @escaping FlutterResult) {
        let configPath = getWorkingDirectory().appendingPathComponent("profiles/active_config.json")
        if let content = try? String(contentsOf: configPath, encoding: .utf8) {
            result(content)
        } else {
            result("")
        }
    }
    
    // MARK: - Format Bytes (local)
    
    private func formatBytesLocal(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0
        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        if unitIndex == 0 { return "\(bytes) B" }
        return String(format: "%.2f %@", value, units[unitIndex])
    }
    
    // MARK: - Find Available Port
    
    private func findAvailablePort(from startPort: Int) -> Int {
        for port in startPort..<65535 {
            let socketFD = socket(AF_INET, SOCK_STREAM, 0)
            guard socketFD >= 0 else { continue }
            defer { close(socketFD) }
            
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = in_port_t(port).bigEndian
            addr.sin_addr.s_addr = INADDR_ANY
            
            let bindResult = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.bind(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            if bindResult == 0 { return port }
        }
        return -1
    }
    
    // MARK: - Helper Methods
    
    private func getBaseDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("V2rayBox", isDirectory: true)
    }
    
    private func getWorkingDirectory() -> URL {
        return getBaseDirectory().appendingPathComponent("working", isDirectory: true)
    }
    
    private func getTempDirectory() -> URL {
        return getBaseDirectory().appendingPathComponent("temp", isDirectory: true)
    }
    
    // MARK: - Event Sinks
    
    func setStatusEventSink(_ sink: FlutterEventSink?) {
        statusEventSink = sink
        if sink != nil {
            let status = isRunning ? "Started" : "Stopped"
            sink?(["status": status])
        }
    }
    
    func setAlertsEventSink(_ sink: FlutterEventSink?) {
        alertsEventSink = sink
    }
    
    func setStatsEventSink(_ sink: FlutterEventSink?) {
        statsEventSink = sink
        if sink != nil {
            startStatsTimer()
        } else {
            stopStatsTimer()
        }
    }
    
    func setPingEventSink(_ sink: FlutterEventSink?) {
        pingEventSink = sink
    }
    
    func setLogsEventSink(_ sink: FlutterEventSink?) {
        logsEventSink = sink
    }
    
    private func startStatsTimer() {
        stopStatsTimer()
        statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
    }
    
    private func stopStatsTimer() {
        statsTimer?.invalidate()
        statsTimer = nil
    }
    
    private func updateStats() {
        guard isRunning else { return }
        
        if coreEngine == "singbox" {
            pollSingboxStats()
        } else {
            pollXrayStats()
        }
    }
    
    private func pollSingboxStats() {
        let clashApiPort = 9090
        guard let url = URL(string: "http://127.0.0.1:\(clashApiPort)/connections") else { return }
        
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2
        let session = URLSession(configuration: config)
        
        session.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, error == nil, let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            
            let totalUpload = json["uploadTotal"] as? Int64 ?? 0
            let totalDownload = json["downloadTotal"] as? Int64 ?? 0
            
            let upPerSec = max(0, totalUpload - self.lastSingboxUpload)
            let downPerSec = max(0, totalDownload - self.lastSingboxDownload)
            
            self.lastSingboxUpload = totalUpload
            self.lastSingboxDownload = totalDownload
            
            DispatchQueue.main.async {
                self.statsEventSink?([
                    "connections-in": 0,
                    "connections-out": 0,
                    "uplink": upPerSec,
                    "downlink": downPerSec,
                    "uplink-total": totalUpload,
                    "downlink-total": totalDownload
                ])
            }
        }.resume()
    }
    
    private func pollXrayStats() {
        statsEventSink?([
            "connections-in": 0,
            "connections-out": 0,
            "uplink": 0,
            "downlink": 0,
            "uplink-total": 0,
            "downlink-total": 0
        ])
    }
}

// MARK: - Stream Handlers

class StatusStreamHandler: NSObject, FlutterStreamHandler {
    weak var plugin: V2rayBoxPlugin?
    
    init(plugin: V2rayBoxPlugin) {
        self.plugin = plugin
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        plugin?.setStatusEventSink(events)
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        plugin?.setStatusEventSink(nil)
        return nil
    }
}

class AlertsStreamHandler: NSObject, FlutterStreamHandler {
    weak var plugin: V2rayBoxPlugin?
    
    init(plugin: V2rayBoxPlugin) {
        self.plugin = plugin
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        plugin?.setAlertsEventSink(events)
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        plugin?.setAlertsEventSink(nil)
        return nil
    }
}

class StatsStreamHandler: NSObject, FlutterStreamHandler {
    weak var plugin: V2rayBoxPlugin?
    
    init(plugin: V2rayBoxPlugin) {
        self.plugin = plugin
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        plugin?.setStatsEventSink(events)
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        plugin?.setStatsEventSink(nil)
        return nil
    }
}

class PingStreamHandler: NSObject, FlutterStreamHandler {
    weak var plugin: V2rayBoxPlugin?
    
    init(plugin: V2rayBoxPlugin) {
        self.plugin = plugin
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        plugin?.setPingEventSink(events)
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        plugin?.setPingEventSink(nil)
        return nil
    }
}

class LogsStreamHandler: NSObject, FlutterStreamHandler {
    weak var plugin: V2rayBoxPlugin?
    
    init(plugin: V2rayBoxPlugin) {
        self.plugin = plugin
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        plugin?.setLogsEventSink(events)
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        plugin?.setLogsEventSink(nil)
        return nil
    }
}
