//
//  PacketTunnelProvider.swift
//  PacketTunnel
//

import NetworkExtension
import Libbox

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private var platformInterface: ExtensionPlatformInterface?
    private var config: String?
    
    private let appGroupId = "group.com.example.v2rayBoxExample"
    
    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        NSLog("[PacketTunnel] Starting tunnel...")
        
        guard let configString = options?["Config"] as? String else {
            NSLog("[PacketTunnel] Config not provided")
            completionHandler(NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: "Config not provided"]))
            return
        }
        
        let coreEngine = (options?["CoreEngine"] as? String) ?? "singbox"
        NSLog("[PacketTunnel] Config received, length: \(configString.count), core: \(coreEngine)")
        config = configString
        
        if coreEngine == "xray" {
            startXrayTunnel(config: configString, completionHandler: completionHandler)
        } else {
            startSingboxTunnel(config: configString, completionHandler: completionHandler)
        }
    }
    
    private func startSingboxTunnel(config configString: String, completionHandler: @escaping (Error?) -> Void) {
        do {
            let fileManager = FileManager.default
            guard let sharedDir = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
                NSLog("[PacketTunnel] Failed to get shared container")
                completionHandler(NSError(domain: "V2rayBox", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to get shared container"]))
                return
            }
            
            let workingDir = sharedDir.appendingPathComponent("working", isDirectory: true)
            let cacheDir = sharedDir.appendingPathComponent("Library/Caches", isDirectory: true)
            
            try fileManager.createDirectory(at: workingDir, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            
            NSLog("[PacketTunnel] Directories created")
            
            platformInterface = ExtensionPlatformInterface(tunnel: self)
            
            let opts = MobileSetupOptions()
            opts.basePath = sharedDir.path
            opts.workingDir = workingDir.path
            opts.tempDir = cacheDir.path
            opts.listen = ""
            opts.secret = ""
            opts.debug = false
            opts.mode = 0
            opts.fixAndroidStack = false
            
            var error: NSError?
            MobileSetup(opts, platformInterface, &error)
            if let error = error {
                NSLog("[PacketTunnel] MobileSetup error: \(error.localizedDescription)")
                throw error
            }
            
            NSLog("[PacketTunnel] MobileSetup completed")
            
            MobileStart(nil, configString, &error)
            if let error = error {
                NSLog("[PacketTunnel] MobileStart error: \(error.localizedDescription)")
                throw error
            }
            
            NSLog("[PacketTunnel] sing-box started successfully")
            completionHandler(nil)
            
        } catch {
            NSLog("[PacketTunnel] Error: \(error.localizedDescription)")
            completionHandler(error)
        }
    }
    
    private func startXrayTunnel(config configString: String, completionHandler: @escaping (Error?) -> Void) {
        // Xray-core integration requires libXray framework.
        // If libXray is available, use it here. Otherwise, log an error.
        NSLog("[PacketTunnel] Xray-core tunnel start requested")
        NSLog("[PacketTunnel] Note: Xray-core requires libXray framework integration in the PacketTunnel extension")
        
        // TODO: Integrate libXray framework here when available
        // For now, fall back to sing-box if Xray framework is not available
        NSLog("[PacketTunnel] Falling back to sing-box core")
        startSingboxTunnel(config: configString, completionHandler: completionHandler)
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        NSLog("[PacketTunnel] Stopping tunnel, reason: \(reason.rawValue)")
        
        var error: NSError?
        MobileStop(&error)
        if let error = error {
            NSLog("[PacketTunnel] MobileStop error: \(error.localizedDescription)")
        }
        
        MobileClose(0)
        platformInterface?.reset()
        
        NSLog("[PacketTunnel] Tunnel stopped")
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard let message = String(data: messageData, encoding: .utf8) else {
            completionHandler?(nil)
            return
        }
        if message == "stats" {
            completionHandler?("0,0".data(using: .utf8))
        } else {
            completionHandler?(nil)
        }
    }
    
    // sleep/wake lifecycle handled by MobilePause/MobileWake when iOS backgrounding support is needed
}

// MARK: - Platform Interface

class ExtensionPlatformInterface: NSObject, LibboxPlatformInterfaceProtocol {
    private weak var tunnel: PacketTunnelProvider?
    private var networkSettings: NEPacketTunnelNetworkSettings?
    
    init(tunnel: PacketTunnelProvider) {
        self.tunnel = tunnel
        super.init()
    }
    
    func reset() {
        networkSettings = nil
    }
    
    func openTun(_ options: (any LibboxTunOptionsProtocol)?, ret0_: UnsafeMutablePointer<Int32>?) throws {
        NSLog("[PlatformInterface] openTun called")
        
        guard let options = options, let ret0_ = ret0_, let tunnel = tunnel else {
            throw NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid parameters"])
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        var resultError: Error?
        
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        
        if options.getAutoRoute() {
            settings.mtu = NSNumber(value: options.getMTU())
            
            var dnsServers = ["8.8.8.8", "8.8.4.4"]
            do {
                let dnsBox = try options.getDNSServerAddress()
                let dnsStr = dnsBox.value
                if !dnsStr.isEmpty {
                    dnsServers = dnsStr.components(separatedBy: "\n").filter { !$0.isEmpty }
                }
            } catch {}
            settings.dnsSettings = NEDNSSettings(servers: dnsServers)
            
            var ipv4Addr: [String] = []
            var ipv4Mask: [String] = []
            if let iter = options.getInet4Address() {
                while iter.hasNext() {
                    if let p = iter.next() {
                        ipv4Addr.append(p.address())
                        ipv4Mask.append(p.mask())
                    }
                }
            }
            if !ipv4Addr.isEmpty {
                let ipv4 = NEIPv4Settings(addresses: ipv4Addr, subnetMasks: ipv4Mask)
                ipv4.includedRoutes = [NEIPv4Route.default()]
                settings.ipv4Settings = ipv4
            } else {
                let ipv4 = NEIPv4Settings(addresses: ["172.19.0.1"], subnetMasks: ["255.255.255.252"])
                ipv4.includedRoutes = [NEIPv4Route.default()]
                settings.ipv4Settings = ipv4
            }
            
            var ipv6Addr: [String] = []
            var ipv6Prefix: [NSNumber] = []
            if let iter = options.getInet6Address() {
                while iter.hasNext() {
                    if let p = iter.next() {
                        ipv6Addr.append(p.address())
                        ipv6Prefix.append(NSNumber(value: p.prefix()))
                    }
                }
            }
            if !ipv6Addr.isEmpty {
                let ipv6 = NEIPv6Settings(addresses: ipv6Addr, networkPrefixLengths: ipv6Prefix)
                ipv6.includedRoutes = [NEIPv6Route.default()]
                settings.ipv6Settings = ipv6
            }
            
            // HTTP proxy settings if provided
            let proxyServer = options.getHTTPProxyServer()
            let proxyPort = options.getHTTPProxyServerPort()
            if !proxyServer.isEmpty && proxyPort > 0 {
                let proxySettings = NEProxySettings()
                proxySettings.httpServer = NEProxyServer(address: proxyServer, port: Int(proxyPort))
                proxySettings.httpsServer = NEProxyServer(address: proxyServer, port: Int(proxyPort))
                proxySettings.httpEnabled = true
                proxySettings.httpsEnabled = true
                
                var bypassDomains: [String] = []
                if let iter = options.getHTTPProxyBypassDomain() {
                    while iter.hasNext() {
                        bypassDomains.append(iter.next())
                    }
                }
                proxySettings.exceptionList = bypassDomains
                
                var matchDomains: [String] = []
                if let iter = options.getHTTPProxyMatchDomain() {
                    while iter.hasNext() {
                        matchDomains.append(iter.next())
                    }
                }
                proxySettings.matchDomains = matchDomains.isEmpty ? nil : matchDomains
                settings.proxySettings = proxySettings
            }
        } else {
            settings.mtu = NSNumber(value: 9000)
            settings.dnsSettings = NEDNSSettings(servers: ["8.8.8.8"])
            
            let ipv4 = NEIPv4Settings(addresses: ["172.19.0.1"], subnetMasks: ["255.255.255.252"])
            ipv4.includedRoutes = [NEIPv4Route.default()]
            settings.ipv4Settings = ipv4
        }
        
        networkSettings = settings
        
        NSLog("[PlatformInterface] Setting tunnel network settings...")
        tunnel.setTunnelNetworkSettings(settings) { error in
            if let error = error {
                NSLog("[PlatformInterface] setTunnelNetworkSettings error: \(error.localizedDescription)")
            }
            resultError = error
            semaphore.signal()
        }
        semaphore.wait()
        
        if let error = resultError {
            throw error
        }
        
        let fd = LibboxGetTunnelFileDescriptor()
        NSLog("[PlatformInterface] Got file descriptor: \(fd)")
        
        if fd != -1 {
            ret0_.pointee = fd
        } else {
            throw NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing file descriptor"])
        }
    }
    
    func usePlatformAutoDetectControl() -> Bool { false }
    func autoDetectControl(_ fd: Int32) throws {}
    
    func findConnectionOwner(_ ipProtocol: Int32, sourceAddress: String?, sourcePort: Int32, destinationAddress: String?, destinationPort: Int32) throws -> LibboxConnectionOwner {
        throw NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: "not supported on iOS"])
    }
    
    func useProcFS() -> Bool { false }
    
    func startDefaultInterfaceMonitor(_ listener: (any LibboxInterfaceUpdateListenerProtocol)?) throws {}
    func closeDefaultInterfaceMonitor(_ listener: (any LibboxInterfaceUpdateListenerProtocol)?) throws {}
    
    func getInterfaces() throws -> any LibboxNetworkInterfaceIteratorProtocol {
        throw NSError(domain: "V2rayBox", code: -1, userInfo: [NSLocalizedDescriptionKey: "not implemented"])
    }
    
    func underNetworkExtension() -> Bool { true }
    func includeAllNetworks() -> Bool { false }
    
    func localDNSTransport() -> (any LibboxLocalDNSTransportProtocol)? { nil }
    func systemCertificates() -> (any LibboxStringIteratorProtocol)? { nil }
    
    func clearDNSCache() {
        guard let s = networkSettings, let t = tunnel else { return }
        t.reasserting = true
        t.setTunnelNetworkSettings(nil) { _ in }
        t.setTunnelNetworkSettings(s) { _ in }
        t.reasserting = false
    }
    
    func readWIFIState() -> LibboxWIFIState? { nil }
    func send(_ notification: LibboxNotification?) throws {}
}
