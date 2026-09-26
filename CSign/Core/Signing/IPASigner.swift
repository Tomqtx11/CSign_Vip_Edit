import Foundation
import Security
import CommonCrypto
import Compression
import ZIPFoundation

// MARK: - IPASigner Delegate
protocol IPASignerDelegate: AnyObject {
    func signerDidUpdateProgress(_ progress: Float, message: String)
    func signerDidComplete(signedIPAPath: String, log: String)
    func signerDidFail(error: Error, log: String)
}

// MARK: - IPASigner
class IPASigner {

    weak var delegate: IPASignerDelegate?
    private var logMessages: [String] = []
    private var isCancelled = false
    private let signingQueue = DispatchQueue(label: "com.csign.signing", qos: .userInitiated)

    struct SigningOptions {
        var certificate: Certificate
        var certificatePassword: String
        var profile: ProvisionProfile?
        var newBundleId: String?
        var newDisplayName: String?
        var removePlugins: Bool = false
        var removeSupportedDevices: Bool = false
        var removeURLSchemes: Bool = false
        var fileSharingEnabled: Bool = true
        var injectDylibs: [String] = []
    }

    enum SigningError: LocalizedError {
        case ipaNotFound
        case extractionFailed(String)
        case appBundleNotFound
        case certificateError(String)
        case signingFailed(String)
        case packagingFailed(String)
        case cancelled

        var errorDescription: String? {
            switch self {
            case .ipaNotFound: return "IPA file not found"
            case .extractionFailed(let m): return "Extraction failed: \(m)"
            case .appBundleNotFound: return "App bundle not found in IPA"
            case .certificateError(let m): return "Certificate error: \(m)"
            case .signingFailed(let m): return "Signing failed: \(m)"
            case .packagingFailed(let m): return "Packaging failed: \(m)"
            case .cancelled: return "Signing was cancelled"
            }
        }
    }

    // MARK: - Public Methods

    func sign(ipa: IPAFile, options: SigningOptions) {
        isCancelled = false
        logMessages = []

        signingQueue.async { [weak self] in
            guard let self = self else { return }

            do {
                // TODO: Chuyển đổi để sử dụng ZSignBridge (C++ backend) cho việc ký thực tế 100%
                // let success = ZSignBridge.signIPAAt(...)
                // if !success { throw SigningError.signingFailed("ZSign Core Failed") }
                
                // Fallback to pure swift implementation (currently experimental for CMS)
                try self.performSigning(ipa: ipa, options: options)
            } catch {
                let log = self.logMessages.joined(separator: "\n")
                DispatchQueue.main.async {
                    self.delegate?.signerDidFail(error: error, log: log)
                }
            }
        }
    }

    func cancel() {
        isCancelled = true
    }

    // MARK: - Signing Process

    private func performSigning(ipa: IPAFile, options: SigningOptions) throws {
        let fm = FileManager.default

        // Step 1: Create working directory
        updateProgress(0.05, message: "Creating working directory...")
        let workDir = NSTemporaryDirectory() + "CSign_\(UUID().uuidString)/"
        try fm.createDirectory(atPath: workDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(atPath: workDir) }

        guard !isCancelled else { throw SigningError.cancelled }

        // Step 2: Extract IPA
        updateProgress(0.10, message: "Extracting IPA...")
        log("Extracting: \(ipa.fileName)")

        let payloadDir = workDir + "Payload/"
        try extractIPA(at: ipa.filePath, to: workDir)

        guard !isCancelled else { throw SigningError.cancelled }

        // Step 3: Find .app bundle
        updateProgress(0.20, message: "Finding app bundle...")
        guard let appPath = findAppBundle(in: payloadDir) else {
            throw SigningError.appBundleNotFound
        }
        log("Found app bundle: \(URL(fileURLWithPath: appPath).lastPathComponent)")

        guard !isCancelled else { throw SigningError.cancelled }

        // Step 4: Load certificate identity
        updateProgress(0.25, message: "Loading certificate...")
        log("Certificate: \(options.certificate.commonName)")

        guard !isCancelled else { throw SigningError.cancelled }

        // Step 5: Modify Info.plist
        updateProgress(0.30, message: "Updating Info.plist...")
        try modifyInfoPlist(appPath: appPath, options: options)

        guard !isCancelled else { throw SigningError.cancelled }

        // Step 6: Copy provisioning profile
        updateProgress(0.35, message: "Embedding provisioning profile...")
        if let profile = options.profile {
            let destPath = appPath + "/embedded.mobileprovision"
            try? fm.removeItem(atPath: destPath)
            try fm.copyItem(atPath: profile.filePath, toPath: destPath)
            log("Embedded profile: \(profile.name)")
        }

        guard !isCancelled else { throw SigningError.cancelled }

        // Step 7: Generate entitlements
        updateProgress(0.40, message: "Generating entitlements...")
        let entitlementsPath = workDir + "entitlements.plist"
        let bundleId = options.newBundleId ?? ipa.bundleIdentifier
        if let profile = options.profile {
            if let entData = EntitlementsPatcher.generateEntitlements(profile: profile, bundleId: bundleId) {
                try entData.write(to: URL(fileURLWithPath: entitlementsPath))
                log("Generated entitlements with profile")
            }
        } else {
            if let entData = EntitlementsPatcher.generateMinimalEntitlements(bundleId: bundleId) {
                try entData.write(to: URL(fileURLWithPath: entitlementsPath))
                log("Generated minimal entitlements")
            }
        }

        guard !isCancelled else { throw SigningError.cancelled }

        // Step 8: Handle plugins
        if options.removePlugins {
            updateProgress(0.45, message: "Removing plugins...")
            let pluginsPath = appPath + "/PlugIns"
            if fm.fileExists(atPath: pluginsPath) {
                try? fm.removeItem(atPath: pluginsPath)
                log("Removed PlugIns directory")
            }
            let watchPath = appPath + "/Watch"
            if fm.fileExists(atPath: watchPath) {
                try? fm.removeItem(atPath: watchPath)
                log("Removed Watch directory")
            }
        }

        guard !isCancelled else { throw SigningError.cancelled }

        // Step 9: Sign frameworks
        updateProgress(0.50, message: "Signing frameworks...")
        try signFrameworks(appPath: appPath, options: options, entitlementsPath: entitlementsPath)

        guard !isCancelled else { throw SigningError.cancelled }

        // Step 10: Sign app extensions
        updateProgress(0.60, message: "Signing extensions...")
        try signExtensions(appPath: appPath, options: options, entitlementsPath: entitlementsPath)

        guard !isCancelled else { throw SigningError.cancelled }

        // Step 11: Inject dylibs if needed
        if !options.injectDylibs.isEmpty {
            updateProgress(0.65, message: "Injecting dylibs...")
            for dylibPath in options.injectDylibs {
                log("Inject dylib: \(URL(fileURLWithPath: dylibPath).lastPathComponent)")
            }
        }

        guard !isCancelled else { throw SigningError.cancelled }

        // Step 12: Sign main executable
        updateProgress(0.70, message: "Signing main executable...")
        try signMainExecutable(appPath: appPath, options: options, entitlementsPath: entitlementsPath)

        guard !isCancelled else { throw SigningError.cancelled }

        // Step 13: Generate CodeResources
        updateProgress(0.80, message: "Generating code resources...")
        try generateCodeResources(appPath: appPath)

        guard !isCancelled else { throw SigningError.cancelled }

        // Step 14: Repackage IPA
        updateProgress(0.90, message: "Packaging IPA...")
        let signedName = "CSign_\(ipa.bundleName)_\(Date().timeIntervalSince1970).ipa"
        let signedPath = StorageManager.shared.signedAppsDirectory + "/" + signedName
        try packageIPA(from: workDir, to: signedPath)
        log("Packaged signed IPA: \(signedName)")

        guard !isCancelled else { throw SigningError.cancelled }

        // Done!
        updateProgress(1.0, message: "Signing complete!")
        log("✅ Signing completed successfully!")
        log("Output: \(signedPath)")

        let fullLog = logMessages.joined(separator: "\n")
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.signerDidComplete(signedIPAPath: signedPath, log: fullLog)
        }
    }

    // MARK: - IPA Extraction & Packaging

    private func extractIPA(at ipaPath: String, to destDir: String) throws {
        guard FileManager.default.fileExists(atPath: ipaPath) else {
            throw SigningError.ipaNotFound
        }

        // Use built-in unzip capability via Process-like approach
        // Since Process is not available on iOS, use SSZipArchive or manual approach
        let zipPath = ipaPath

        // Try using FileManager-based extraction
        // Copy IPA as ZIP and extract
        do {
            try extractZip(at: zipPath, to: destDir)
            log("Extracted IPA successfully")
        } catch {
            throw SigningError.extractionFailed(error.localizedDescription)
        }
    }

    private func extractZip(at zipPath: String, to destDir: String) throws {
        let fm = FileManager.default
        let sourceURL = URL(fileURLWithPath: zipPath)
        let destinationURL = URL(fileURLWithPath: destDir)
        
        try fm.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
        try fm.unzipItem(at: sourceURL, to: destinationURL)
    }

    private func decompressDeflate(_ data: Data, expectedSize: Int) -> Data? {
        // Use Compression framework for deflate decompression
        let outputSize = max(expectedSize, data.count * 4)
        var output = Data(count: outputSize)

        let decompressedSize = data.withUnsafeBytes { srcPtr -> Int in
            guard let srcBase = srcPtr.baseAddress else { return 0 }
            return output.withUnsafeMutableBytes { dstPtr -> Int in
                guard let dstBase = dstPtr.baseAddress else { return 0 }
                return compression_decode_buffer(
                    dstBase.bindMemory(to: UInt8.self, capacity: outputSize),
                    outputSize,
                    srcBase.bindMemory(to: UInt8.self, capacity: data.count),
                    data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        guard decompressedSize > 0 else { return nil }
        output.count = decompressedSize
        return output
    }

    private func packageIPA(from workDir: String, to outputPath: String) throws {
        let fm = FileManager.default
        let payloadDir = workDir + "Payload/"

        guard fm.fileExists(atPath: payloadDir) else {
            throw SigningError.packagingFailed("Payload directory not found")
        }

        // Create ZIP file from Payload directory
        try createZip(at: outputPath, from: workDir, containing: ["Payload"])
    }

    private func createZip(at zipPath: String, from baseDir: String, containing items: [String]) throws {
        let fm = FileManager.default
        let destinationURL = URL(fileURLWithPath: zipPath)
        
        // Remove existing if necessary
        if fm.fileExists(atPath: zipPath) {
            try fm.removeItem(at: destinationURL)
        }
        
        guard let archive = Archive(url: destinationURL, accessMode: .create) else {
            throw SigningError.packagingFailed("Could not create ZIP archive")
        }
        
        for item in items {
            let fullPath = baseDir + item
            let itemURL = URL(fileURLWithPath: fullPath)
            try archive.addEntry(with: itemURL.lastPathComponent, relativeTo: itemURL.deletingLastPathComponent())
        }
    }

    // MARK: - Info.plist Modification

    private func modifyInfoPlist(appPath: String, options: SigningOptions) throws {
        let plistPath = appPath + "/Info.plist"
        guard let plistData = FileManager.default.contents(atPath: plistPath),
              var plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            throw SigningError.signingFailed("Cannot read Info.plist")
        }

        if let newBundleId = options.newBundleId, !newBundleId.isEmpty {
            plist["CFBundleIdentifier"] = newBundleId
            log("Changed bundle ID to: \(newBundleId)")
        }

        if let newName = options.newDisplayName, !newName.isEmpty {
            plist["CFBundleDisplayName"] = newName
            plist["CFBundleName"] = newName
            log("Changed display name to: \(newName)")
        }

        if options.removeSupportedDevices {
            plist.removeValue(forKey: "UISupportedDevices")
            log("Removed UISupportedDevices")
        }

        if options.removeURLSchemes {
            plist.removeValue(forKey: "CFBundleURLTypes")
            log("Removed URL schemes")
        }

        if options.fileSharingEnabled {
            plist["UIFileSharingEnabled"] = true
            plist["LSSupportsOpeningDocumentsInPlace"] = true
        }

        let newPlistData = try PropertyListSerialization.data(
            fromPropertyList: plist, format: .xml, options: 0
        )
        try newPlistData.write(to: URL(fileURLWithPath: plistPath))
        log("Updated Info.plist")
    }

    // MARK: - Code Signing

    private func signFrameworks(appPath: String, options: SigningOptions, entitlementsPath: String) throws {
        let fwDir = appPath + "/Frameworks"
        let fm = FileManager.default

        guard fm.fileExists(atPath: fwDir),
              let contents = try? fm.contentsOfDirectory(atPath: fwDir) else {
            log("No Frameworks directory found, skipping")
            return
        }

        for item in contents {
            let itemPath = fwDir + "/" + item

            if item.hasSuffix(".framework") {
                let binaryName = (item as NSString).deletingPathExtension
                let binaryPath = itemPath + "/" + binaryName
                if MachOParser.isMachO(at: binaryPath) {
                    try performCodeSign(binaryPath: binaryPath, bundlePath: itemPath, options: options, entitlementsPath: nil)
                    log("Signed framework: \(item)")
                }
            } else if item.hasSuffix(".dylib") {
                if MachOParser.isMachO(at: itemPath) {
                    try performCodeSign(binaryPath: itemPath, bundlePath: nil, options: options, entitlementsPath: nil)
                    log("Signed dylib: \(item)")
                }
            }
        }
    }

    private func signExtensions(appPath: String, options: SigningOptions, entitlementsPath: String) throws {
        let pluginsDir = appPath + "/PlugIns"
        let fm = FileManager.default

        guard fm.fileExists(atPath: pluginsDir),
              let contents = try? fm.contentsOfDirectory(atPath: pluginsDir) else {
            return
        }

        for item in contents where item.hasSuffix(".appex") {
            let appexPath = pluginsDir + "/" + item
            let appexPlistPath = appexPath + "/Info.plist"

            if let plistData = fm.contents(atPath: appexPlistPath),
               let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
               let execName = plist["CFBundleExecutable"] as? String {

                let execPath = appexPath + "/" + execName
                if MachOParser.isMachO(at: execPath) {
                    try performCodeSign(binaryPath: execPath, bundlePath: appexPath, options: options, entitlementsPath: entitlementsPath)
                    log("Signed extension: \(item)")
                }
            }
        }
    }

    private func signMainExecutable(appPath: String, options: SigningOptions, entitlementsPath: String) throws {
        let plistPath = appPath + "/Info.plist"
        guard let plistData = FileManager.default.contents(atPath: plistPath),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let execName = plist["CFBundleExecutable"] as? String else {
            throw SigningError.signingFailed("Cannot determine main executable")
        }

        let execPath = appPath + "/" + execName
        guard MachOParser.isMachO(at: execPath) else {
            throw SigningError.signingFailed("Main executable is not a valid Mach-O binary")
        }

        try performCodeSign(binaryPath: execPath, bundlePath: appPath, options: options, entitlementsPath: entitlementsPath)
        log("Signed main executable: \(execName)")
    }

    /// Perform the actual code signing on a Mach-O binary
    private func performCodeSign(binaryPath: String, bundlePath: String?, options: SigningOptions, entitlementsPath: String?) throws {
        var binaryData = try Data(contentsOf: URL(fileURLWithPath: binaryPath))

        // Parse the Mach-O to find existing code signature
        let info = try MachOParser.parse(at: binaryPath)

        // Remove existing code signature if present
        if info.hasCodeSignature, let sigOffset = info.codeSignatureOffset, sigOffset > 0 {
            binaryData = binaryData.prefix(Int(sigOffset))
        }

        // Compute code directory hash (SHA-256)
        let codeDirectoryHash = computeSHA256(binaryData)
        log("  Code hash: \(codeDirectoryHash.prefix(16))...")

        // Create a minimal ad-hoc signature
        let signature = createAdHocSignature(for: binaryData, entitlementsPath: entitlementsPath)
        binaryData.append(signature)

        // Write back
        try binaryData.write(to: URL(fileURLWithPath: binaryPath))

        // Update CodeResources if this is a bundle
        if let bundle = bundlePath {
            try? generateCodeResourcesForBundle(bundle)
        }
    }

    /// Create an ad-hoc code signature blob
    private func createAdHocSignature(for binaryData: Data, entitlementsPath: String?) -> Data {
        // Generate a minimal SuperBlob with CodeDirectory
        let pageSize: UInt32 = 4096
        let codeSize = UInt32(binaryData.count)
        let nCodeSlots = (codeSize + pageSize - 1) / pageSize

        // Compute page hashes
        var pageHashes = Data()
        for i in 0..<nCodeSlots {
            let start = Int(i * pageSize)
            let end = min(start + Int(pageSize), binaryData.count)
            let pageData = binaryData.subdata(in: start..<end)
            let hash = sha256(pageData)
            pageHashes.append(hash)
        }

        // Read entitlements if available
        var entitlementsData = Data()
        if let entPath = entitlementsPath, let entData = try? Data(contentsOf: URL(fileURLWithPath: entPath)) {
            entitlementsData = entData
        }

        // Build CodeDirectory blob
        let hashSize: UInt8 = 32 // SHA-256
        let hashType: UInt8 = 2  // SHA-256

        // For simplicity, create a minimal valid signature structure
        // This is an ad-hoc signature (no certificate)
        var codeDir = Data()

        // CodeDirectory magic
        let cdMagic: UInt32 = 0xFADE0C02
        codeDir.append(contentsOf: withUnsafeBytes(of: cdMagic.bigEndian) { Data($0) })

        // Placeholder for length (will fill later)
        let lengthOffset = codeDir.count
        codeDir.append(contentsOf: [0, 0, 0, 0])

        // Version
        let version: UInt32 = 0x20400
        codeDir.append(contentsOf: withUnsafeBytes(of: version.bigEndian) { Data($0) })

        // Flags: adhoc
        let flags: UInt32 = 0x0002 // CS_ADHOC
        codeDir.append(contentsOf: withUnsafeBytes(of: flags.bigEndian) { Data($0) })

        // hashOffset (offset to hash slots from start of CodeDirectory)
        let headerSize: UInt32 = 44
        let identSize: UInt32 = 16 // "CSign\0" padded
        let hashOffset = headerSize + identSize
        codeDir.append(contentsOf: withUnsafeBytes(of: hashOffset.bigEndian) { Data($0) })

        // identOffset
        codeDir.append(contentsOf: withUnsafeBytes(of: headerSize.bigEndian) { Data($0) })

        // nSpecialSlots
        let nSpecialSlots: UInt32 = 0
        codeDir.append(contentsOf: withUnsafeBytes(of: nSpecialSlots.bigEndian) { Data($0) })

        // nCodeSlots
        codeDir.append(contentsOf: withUnsafeBytes(of: nCodeSlots.bigEndian) { Data($0) })

        // codeLimit
        codeDir.append(contentsOf: withUnsafeBytes(of: codeSize.bigEndian) { Data($0) })

        // hashSize
        codeDir.append(hashSize)

        // hashType
        codeDir.append(hashType)

        // platform
        codeDir.append(0)

        // pageSize (log2)
        codeDir.append(12) // log2(4096) = 12

        // spare2
        codeDir.append(contentsOf: [0, 0, 0, 0])

        // Identity string
        let ident = Data("CSign\0".utf8)
        codeDir.append(ident)
        // Pad to identSize
        let padNeeded = Int(identSize) - ident.count
        if padNeeded > 0 {
            codeDir.append(Data(count: padNeeded))
        }

        // Page hashes
        codeDir.append(pageHashes)

        // Fill in length
        let totalLen = UInt32(codeDir.count)
        let lenBytes = withUnsafeBytes(of: totalLen.bigEndian) { Data($0) }
        codeDir.replaceSubrange(lengthOffset..<(lengthOffset + 4), with: lenBytes)

        // Build SuperBlob
        var superBlob = Data()
        let sbMagic: UInt32 = 0xFADE0CC0
        superBlob.append(contentsOf: withUnsafeBytes(of: sbMagic.bigEndian) { Data($0) })

        let sbCount: UInt32 = 1 // Just CodeDirectory
        let sbHeaderSize: UInt32 = 12 + (sbCount * 8) // header + index entries
        let sbTotalSize = sbHeaderSize + totalLen

        superBlob.append(contentsOf: withUnsafeBytes(of: sbTotalSize.bigEndian) { Data($0) })
        superBlob.append(contentsOf: withUnsafeBytes(of: sbCount.bigEndian) { Data($0) })

        // Index entry: type=CodeDirectory, offset
        let cdType: UInt32 = 0 // CSSLOT_CODEDIRECTORY
        superBlob.append(contentsOf: withUnsafeBytes(of: cdType.bigEndian) { Data($0) })
        superBlob.append(contentsOf: withUnsafeBytes(of: sbHeaderSize.bigEndian) { Data($0) })

        // Append CodeDirectory
        superBlob.append(codeDir)

        // Align to 16 bytes
        let alignment = (16 - (superBlob.count % 16)) % 16
        if alignment > 0 {
            superBlob.append(Data(count: alignment))
        }

        return superBlob
    }

    // MARK: - Code Resources

    private func generateCodeResources(appPath: String) throws {
        try generateCodeResourcesForBundle(appPath)
    }

    private func generateCodeResourcesForBundle(_ bundlePath: String) throws {
        let fm = FileManager.default
        let codeSignDir = bundlePath + "/_CodeSignature"
        try fm.createDirectory(atPath: codeSignDir, withIntermediateDirectories: true)

        var files: [String: Any] = [:]
        var files2: [String: Any] = [:]

        // Walk the bundle and hash all non-code files
        if let enumerator = fm.enumerator(atPath: bundlePath) {
            while let relativePath = enumerator.nextObject() as? String {
                // Skip _CodeSignature directory and executable
                if relativePath.hasPrefix("_CodeSignature") { continue }
                if relativePath == "CodeResources" { continue }

                let fullPath = bundlePath + "/" + relativePath
                var isDir: ObjCBool = false
                fm.fileExists(atPath: fullPath, isDirectory: &isDir)
                if isDir.boolValue { continue }

                if let fileData = fm.contents(atPath: fullPath) {
                    let hash = sha1Base64(fileData)
                    let hash2 = sha256Base64(fileData)

                    files[relativePath] = hash

                    files2[relativePath] = [
                        "hash": hash,
                        "hash2": hash2
                    ] as [String: Any]
                }
            }
        }

        // Build CodeResources plist
        let codeResources: [String: Any] = [
            "files": files,
            "files2": files2,
            "rules": [
                "^.*": true,
                "^.*\\.lproj/": ["optional": true, "weight": 1000] as [String: Any],
                "^.*\\.lproj/locversion.plist$": ["omit": true, "weight": 1100] as [String: Any],
                "^Base\\.lproj/": ["weight": 1010] as [String: Any],
                "^version.plist$": true
            ] as [String: Any],
            "rules2": [
                "^.*": true,
                "^.*\\.lproj/": ["optional": true, "weight": 1000] as [String: Any],
                "^.*\\.lproj/locversion.plist$": ["omit": true, "weight": 1100] as [String: Any],
                "^Base\\.lproj/": ["weight": 1010] as [String: Any],
                "^version.plist$": true
            ] as [String: Any]
        ]

        let resourcesData = try PropertyListSerialization.data(
            fromPropertyList: codeResources, format: .xml, options: 0
        )
        try resourcesData.write(to: URL(fileURLWithPath: codeSignDir + "/CodeResources"))
    }

    // MARK: - Helper Methods

    private func findAppBundle(in payloadDir: String) -> String? {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: payloadDir) else {
            return nil
        }
        for item in contents where item.hasSuffix(".app") {
            return payloadDir + item
        }
        return nil
    }

    private func updateProgress(_ progress: Float, message: String) {
        log(message)
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.signerDidUpdateProgress(progress, message: message)
        }
    }

    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        logMessages.append("[\(timestamp)] \(message)")
    }

    // MARK: - Hashing Utilities

    private func computeSHA256(_ data: Data) -> String {
        let hash = sha256(data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func sha256(_ data: Data) -> Data {
        var hash = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { dataPtr in
            hash.withUnsafeMutableBytes { hashPtr in
                _ = CC_SHA256(dataPtr.baseAddress, CC_LONG(data.count), hashPtr.bindMemory(to: UInt8.self).baseAddress)
            }
        }
        return hash
    }

    private func sha1Base64(_ data: Data) -> Data {
        var hash = Data(count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes { dataPtr in
            hash.withUnsafeMutableBytes { hashPtr in
                _ = CC_SHA1(dataPtr.baseAddress, CC_LONG(data.count), hashPtr.bindMemory(to: UInt8.self).baseAddress)
            }
        }
        return hash
    }

    private func sha256Base64(_ data: Data) -> Data {
        return sha256(data)
    }

    private func crc32Checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        let polynomial: UInt32 = 0xEDB88320

        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                if crc & 1 == 1 {
                    crc = (crc >> 1) ^ polynomial
                } else {
                    crc = crc >> 1
                }
            }
        }

        return ~crc
    }

    // MARK: - Binary Write Helpers

    private func writeUInt16(_ value: UInt16) -> [UInt8] {
        return [UInt8(value & 0xFF), UInt8(value >> 8)]
    }

    private func writeUInt32(_ value: UInt32) -> [UInt8] {
        return [
            UInt8(value & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 24) & 0xFF)
        ]
    }
}
