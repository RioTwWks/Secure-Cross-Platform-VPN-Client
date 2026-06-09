import Foundation

class XrayProcess {
    static let shared = XrayProcess()
    
    private var process: Process?
    private(set) var isRunning: Bool = false
    private let lock = NSLock()
    
    private init() {}
    
    private func defaultCorePaths(binaryName: String) -> [String] {
        var paths: [String] = []
        if let customPath = ProcessInfo.processInfo.environment["V2RAY_BOX_XRAY_PATH"], !customPath.isEmpty {
            paths.append(customPath)
        }
        if let coreDir = ProcessInfo.processInfo.environment["V2RAY_BOX_CORE_DIR"], !coreDir.isEmpty {
            paths.append("\(coreDir)/\(binaryName)")
        }
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            if let bundleId = Bundle.main.bundleIdentifier, !bundleId.isEmpty {
                paths.append(appSupport.appendingPathComponent(bundleId).appendingPathComponent("v2ray_box/cores/\(binaryName)").path)
            }
            paths.append(appSupport.appendingPathComponent("v2ray_box/cores/\(binaryName)").path)
        }
        return paths
    }
    
    private func bundleCorePaths(binaryName: String) -> [String] {
        var paths: [String] = []
        
        if let executablePath = Bundle.main.executablePath {
            let contentsPath = (executablePath as NSString).deletingLastPathComponent
            paths.append("\(contentsPath)/../Frameworks/\(binaryName)")
            paths.append("\(contentsPath)/../Resources/\(binaryName)")
            paths.append("\(contentsPath)/\(binaryName)")
        }
        if let resourcePath = Bundle.main.resourcePath {
            paths.append("\(resourcePath)/../Frameworks/\(binaryName)")
            paths.append("\(resourcePath)/\(binaryName)")
        }
        
        let bundle = Bundle(for: type(of: self))
        if let bundlePath = bundle.resourcePath {
            paths.append("\(bundlePath)/../Frameworks/\(binaryName)")
            paths.append("\(bundlePath)/Frameworks/\(binaryName)")
            paths.append("\(bundlePath)/\(binaryName)")
        }
        
        return paths
    }
    
    private func ensureExecutable(path: String) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return false }
        if fm.isExecutableFile(atPath: path) { return true }
        do {
            try fm.setAttributes([.posixPermissions: NSNumber(value: Int16(0o755))], ofItemAtPath: path)
        } catch {
            print("V2rayBox: Failed to chmod xray binary at \(path): \(error)")
        }
        return fm.isExecutableFile(atPath: path)
    }
    
    private func uniquePaths(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for path in paths where !path.isEmpty {
            if !seen.contains(path) {
                seen.insert(path)
                result.append(path)
            }
        }
        return result
    }
    
    func getBinaryPath() -> String? {
        let binaryName = "xray"
        let possiblePaths = uniquePaths(defaultCorePaths(binaryName: binaryName) + bundleCorePaths(binaryName: binaryName))
        
        for path in possiblePaths {
            if ensureExecutable(path: path) {
                print("V2rayBox: Found xray binary at \(path)")
                return path
            }
        }
        
        print("V2rayBox: xray binary not found in: \(possiblePaths)")
        return nil
    }
    
    private func getAssetDirectory(binaryPath: String, configPath: String) -> String {
        let binaryDir = (binaryPath as NSString).deletingLastPathComponent
        let geoipPath = "\(binaryDir)/geoip.dat"
        let geositePath = "\(binaryDir)/geosite.dat"
        if FileManager.default.fileExists(atPath: geoipPath) && FileManager.default.fileExists(atPath: geositePath) {
            return binaryDir
        }
        return (configPath as NSString).deletingLastPathComponent
    }
    
    func getVersion() -> String {
        guard let binaryPath = getBinaryPath() else { return "" }
        
        do {
            let proc = Process()
            let pipe = Pipe()
            proc.executableURL = URL(fileURLWithPath: binaryPath)
            proc.arguments = ["version"]
            proc.standardOutput = pipe
            proc.standardError = pipe
            try proc.run()
            proc.waitUntilExit()
            
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            if let match = output.range(of: #"Xray (\S+)"#, options: .regularExpression) {
                let versionLine = output[match]
                let version = versionLine.replacingOccurrences(of: "Xray ", with: "")
                return version
            }
            return output.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } catch {
            print("V2rayBox: Failed to get xray version: \(error)")
            return ""
        }
    }
    
    func start(configPath: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        if isRunning {
            print("V2rayBox: xray is already running")
            return true
        }
        
        guard let binaryPath = getBinaryPath() else {
            print("V2rayBox: xray binary not found")
            return false
        }
        
        do {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: binaryPath)
            proc.arguments = ["run", "-c", configPath]
            var environment = ProcessInfo.processInfo.environment
            environment["XRAY_LOCATION_ASSET"] = getAssetDirectory(binaryPath: binaryPath, configPath: configPath)
            proc.environment = environment
            
            let outputPipe = Pipe()
            proc.standardOutput = outputPipe
            proc.standardError = outputPipe
            
            proc.terminationHandler = { [weak self] p in
                print("V2rayBox: xray process exited with code: \(p.terminationStatus)")
                self?.lock.lock()
                self?.isRunning = false
                self?.process = nil
                self?.lock.unlock()
            }
            
            try proc.run()
            process = proc
            isRunning = true
            
            DispatchQueue.global(qos: .background).async {
                outputPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if let line = String(data: data, encoding: .utf8), !line.isEmpty {
                        print("XrayCore: \(line)")
                    }
                }
            }
            
            Thread.sleep(forTimeInterval: 0.5)
            if proc.isRunning {
                print("V2rayBox: xray started successfully")
                return true
            } else {
                print("V2rayBox: xray process died immediately")
                isRunning = false
                process = nil
                return false
            }
        } catch {
            print("V2rayBox: Failed to start xray: \(error)")
            isRunning = false
            process = nil
            return false
        }
    }
    
    func stop() {
        lock.lock()
        defer { lock.unlock() }
        
        guard let proc = process else { return }
        
        print("V2rayBox: Stopping xray process")
        proc.terminate()
        proc.waitUntilExit()
        
        process = nil
        isRunning = false
        print("V2rayBox: xray stopped")
    }
}
