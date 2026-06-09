//
//  PacketTunnelProvider.swift
//  V2rayBoxPacketTunnel
//

import NetworkExtension
import Libbox

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private var commandServer: LibboxCommandServer?
    private var boxService: LibboxBoxService?
    private var platformInterface: TunnelPlatformInterface?
    private var config: String?
    private var coreEngine: String = "singbox"
    
    private var uploadTotal: Int64 = 0
    private var downloadTotal: Int64 = 0
    
    override func startTunnel(options: [String: NSObject]?) async throws {
        // Get config from options
        guard let configString = options?["Config"] as? String else {
            throw NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: "Config not provided"])
        }
        
        config = configString
        coreEngine = (options?["CoreEngine"] as? String ?? "singbox").lowercased()
        if coreEngine == "xray" {
            throw NSError(
                domain: "V2rayBox",
                code: -10,
                userInfo: [NSLocalizedDescriptionKey: "iOS xray engine is not enabled in default PacketTunnel. Build and integrate XTLS/libXray in your tunnel target first."]
            )
        }
        let disableMemoryLimit = (options?["DisableMemoryLimit"] as? String ?? "NO") == "YES"
        
        // Create directories
        let fileManager = FileManager.default
        let workingDir = getWorkingDirectory()
        let cacheDir = getCacheDirectory()
        let sharedDir = getSharedDirectory()
        
        try fileManager.createDirectory(at: workingDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: sharedDir, withIntermediateDirectories: true)
        
        // Setup libbox
        let options = LibboxSetupOptions()
        options.basePath = sharedDir.path
        options.workingPath = workingDir.path
        options.tempPath = cacheDir.path
        
        var error: NSError?
        LibboxSetup(options, &error)
        if let error = error {
            throw error
        }
        
        // Redirect stderr
        LibboxRedirectStderr(cacheDir.appendingPathComponent("stderr.log").path, &error)
        
        // Set memory limit
        LibboxSetMemoryLimit(!disableMemoryLimit)
        
        // Create platform interface
        platformInterface = TunnelPlatformInterface(tunnel: self)
        
        // Create command server
        commandServer = LibboxNewCommandServer(platformInterface, 30)
        try commandServer?.start()
        
        // Start service
        try await startService()
    }
    
    private func startService() async throws {
        guard let config = config else {
            throw NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: "Config is nil"])
        }
        
        var error: NSError?
        guard let service = LibboxNewService(config, platformInterface, &error) else {
            if let error = error {
                throw error
            }
            throw NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create service"])
        }
        
        try service.start()
        boxService = service
        commandServer?.setService(service)
    }
    
    private func stopService() {
        if let service = boxService {
            do {
                try service.close()
            } catch {
                NSLog("Error closing service: \(error.localizedDescription)")
            }
            boxService = nil
            commandServer?.setService(nil)
        }
        platformInterface?.reset()
    }
    
    override func stopTunnel(with reason: NEProviderStopReason) async {
        stopService()
        
        if let server = commandServer {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            try? server.close()
            commandServer = nil
        }
    }
    
    override func handleAppMessage(_ messageData: Data) async -> Data? {
        guard let message = String(data: messageData, encoding: .utf8) else {
            return nil
        }
        
        switch message {
        case "stats":
            return "\(uploadTotal),\(downloadTotal)".data(using: .utf8)
        default:
            return nil
        }
    }
    
    override func sleep() {
        boxService?.pause()
    }
    
    override func wake() {
        boxService?.wake()
    }
    
    func writeMessage(_ message: String) {
        if let server = commandServer {
            server.writeMessage(message)
        } else {
            NSLog(message)
        }
    }
    
    func writeFatalError(_ message: String) {
        NSLog("FATAL: \(message)")
        cancelTunnelWithError(NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: message]))
    }
    
    func updateTraffic(upload: Int64, download: Int64) {
        uploadTotal = upload
        downloadTotal = download
    }
    
    // MARK: - Directory Helpers
    
    private func getSharedDirectory() -> URL {
        let groupId = getAppGroupIdentifier()
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId)!
    }
    
    private func getWorkingDirectory() -> URL {
        return getSharedDirectory().appendingPathComponent("working", isDirectory: true)
    }
    
    private func getCacheDirectory() -> URL {
        return getSharedDirectory()
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)
    }
    
    private func getAppGroupIdentifier() -> String {
        // Get from Info.plist or use default pattern
        if let groupId = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String {
            return groupId
        }
        // Default pattern: group.{main_bundle_identifier}
        let mainBundleId = Bundle.main.bundleIdentifier?.replacingOccurrences(of: ".PacketTunnel", with: "") ?? "com.example.v2raybox"
        return "group.\(mainBundleId)"
    }
}

// MARK: - Platform Interface

class TunnelPlatformInterface: NSObject, LibboxPlatformInterfaceProtocol, LibboxCommandServerHandlerProtocol {
    
    private weak var tunnel: PacketTunnelProvider?
    private var networkSettings: NEPacketTunnelNetworkSettings?
    
    init(tunnel: PacketTunnelProvider) {
        self.tunnel = tunnel
    }
    
    func reset() {
        networkSettings = nil
    }
    
    // MARK: - LibboxPlatformInterfaceProtocol
    
    func openTun(_ options: (any LibboxTunOptionsProtocol)?, ret0_: UnsafeMutablePointer<Int32>?) throws {
        try runBlocking { [self] in
            try await openTunAsync(options, ret0_)
        }
    }
    
    private func openTunAsync(_ options: (any LibboxTunOptionsProtocol)?, _ ret0_: UnsafeMutablePointer<Int32>?) async throws {
        guard let options = options else {
            throw NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: "nil options"])
        }
        guard let ret0_ = ret0_ else {
            throw NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: "nil return pointer"])
        }
        guard let tunnel = tunnel else {
            throw NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: "tunnel is nil"])
        }
        
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        
        if options.getAutoRoute() {
            settings.mtu = NSNumber(value: options.getMTU())
            
            // DNS
            var error: NSError?
            if let dnsServer = options.getDNSServerAddress(&error) {
                settings.dnsSettings = NEDNSSettings(servers: [dnsServer.value])
            }
            
            // IPv4
            var ipv4Addresses: [String] = []
            var ipv4Masks: [String] = []
            if let iterator = options.getInet4Address() {
                while iterator.hasNext() {
                    if let prefix = iterator.next() {
                        ipv4Addresses.append(prefix.address())
                        ipv4Masks.append(prefix.mask())
                    }
                }
            }
            
            if !ipv4Addresses.isEmpty {
                let ipv4Settings = NEIPv4Settings(addresses: ipv4Addresses, subnetMasks: ipv4Masks)
                var routes: [NEIPv4Route] = []
                
                if let routeIterator = options.getInet4RouteAddress(), routeIterator.hasNext() {
                    while routeIterator.hasNext() {
                        if let prefix = routeIterator.next() {
                            routes.append(NEIPv4Route(destinationAddress: prefix.address(), subnetMask: prefix.mask()))
                        }
                    }
                } else {
                    routes.append(NEIPv4Route.default())
                }
                
                ipv4Settings.includedRoutes = routes
                settings.ipv4Settings = ipv4Settings
            }
            
            // IPv6
            var ipv6Addresses: [String] = []
            var ipv6Prefixes: [NSNumber] = []
            if let iterator = options.getInet6Address() {
                while iterator.hasNext() {
                    if let prefix = iterator.next() {
                        ipv6Addresses.append(prefix.address())
                        ipv6Prefixes.append(NSNumber(value: prefix.prefix()))
                    }
                }
            }
            
            if !ipv6Addresses.isEmpty {
                let ipv6Settings = NEIPv6Settings(addresses: ipv6Addresses, networkPrefixLengths: ipv6Prefixes)
                ipv6Settings.includedRoutes = [NEIPv6Route.default()]
                settings.ipv6Settings = ipv6Settings
            }
        }
        
        // HTTP Proxy
        if options.isHTTPProxyEnabled() {
            let proxySettings = NEProxySettings()
            let proxyServer = NEProxyServer(address: options.getHTTPProxyServer(), port: Int(options.getHTTPProxyServerPort()))
            proxySettings.httpServer = proxyServer
            proxySettings.httpsServer = proxyServer
            proxySettings.httpEnabled = true
            proxySettings.httpsEnabled = true
            settings.proxySettings = proxySettings
        }
        
        networkSettings = settings
        try await tunnel.setTunnelNetworkSettings(settings)
        
        // Get tunnel file descriptor
        if let tunFd = tunnel.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32 {
            ret0_.pointee = tunFd
            return
        }
        
        let tunFdFromLoop = LibboxGetTunnelFileDescriptor()
        if tunFdFromLoop != -1 {
            ret0_.pointee = tunFdFromLoop
        } else {
            throw NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: "missing file descriptor"])
        }
    }
    
    func usePlatformAutoDetectControl() -> Bool { true }
    func autoDetectControl(_ fd: Int32) throws {}
    
    func findConnectionOwner(_ ipProtocol: Int32, sourceAddress: String?, sourcePort: Int32, destinationAddress: String?, destinationPort: Int32, ret0_: UnsafeMutablePointer<Int32>?) throws {
        throw NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: "not implemented"])
    }
    
    func packageName(byUid uid: Int32, error: NSErrorPointer) -> String { "" }
    
    func uid(byPackageName packageName: String?, ret0_: UnsafeMutablePointer<Int32>?) throws {
        throw NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: "not implemented"])
    }
    
    func useProcFS() -> Bool { false }
    
    func writeLog(_ message: String?) {
        guard let message = message else { return }
        tunnel?.writeMessage(message)
    }
    
    func usePlatformDefaultInterfaceMonitor() -> Bool { false }
    func startDefaultInterfaceMonitor(_ listener: (any LibboxInterfaceUpdateListenerProtocol)?) throws {}
    func closeDefaultInterfaceMonitor(_ listener: (any LibboxInterfaceUpdateListenerProtocol)?) throws {}
    
    func useGetter() -> Bool { false }
    
    func getInterfaces() throws -> any LibboxNetworkInterfaceIteratorProtocol {
        throw NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: "not implemented"])
    }
    
    func underNetworkExtension() -> Bool { true }
    func includeAllNetworks() -> Bool { false }
    
    func clearDNSCache() {
        guard let settings = networkSettings, let tunnel = tunnel else { return }
        tunnel.reasserting = true
        tunnel.setTunnelNetworkSettings(nil) { _ in }
        tunnel.setTunnelNetworkSettings(settings) { _ in }
        tunnel.reasserting = false
    }
    
    func readWIFIState() -> LibboxWIFIState? { nil }
    
    func sendNotification(_ notification: LibboxNotification?) throws {}
    
    // MARK: - LibboxCommandServerHandlerProtocol
    
    func getSystemProxyStatus() -> LibboxSystemProxyStatus? {
        let status = LibboxSystemProxyStatus()
        guard let settings = networkSettings?.proxySettings else { return status }
        status.available = settings.httpServer != nil
        status.enabled = settings.httpEnabled
        return status
    }
    
    func setSystemProxyEnabled(_ isEnabled: Bool) throws {
        guard let settings = networkSettings?.proxySettings else { return }
        guard settings.httpServer != nil else { return }
        guard settings.httpEnabled != isEnabled else { return }
        
        settings.httpEnabled = isEnabled
        settings.httpsEnabled = isEnabled
        
        try runBlocking { [self] in
            try await tunnel?.setTunnelNetworkSettings(networkSettings)
        }
    }
    
    func postServiceClose() {}
    
    func serviceReload() throws {
        // Not implemented
    }
}

// MARK: - Run Blocking Helper

private func runBlocking<T>(_ block: @escaping () async throws -> T) throws -> T {
    let semaphore = DispatchSemaphore(value: 0)
    var result: Result<T, Error>!
    
    Task.detached {
        do {
            let value = try await block()
            result = .success(value)
        } catch {
            result = .failure(error)
        }
        semaphore.signal()
    }
    
    semaphore.wait()
    return try result.get()
}

private func runBlocking<T>(_ block: @escaping () async -> T) -> T {
    let semaphore = DispatchSemaphore(value: 0)
    var value: T!
    
    Task.detached {
        value = await block()
        semaphore.signal()
    }
    
    semaphore.wait()
    return value
}
