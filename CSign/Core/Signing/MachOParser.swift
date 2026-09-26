import Foundation

// MARK: - Mach-O Constants
enum MachOConstants {
    static let MH_MAGIC_64: UInt32 = 0xFEEDFACF
    static let MH_CIGAM_64: UInt32 = 0xCFFAEDFE
    static let FAT_MAGIC: UInt32 = 0xCAFEBABE
    static let FAT_CIGAM: UInt32 = 0xBEBAFECA
    static let MH_MAGIC: UInt32 = 0xFEEDFACE
    static let MH_CIGAM: UInt32 = 0xCEFAEDFE

    static let LC_SEGMENT_64: UInt32 = 0x19
    static let LC_CODE_SIGNATURE: UInt32 = 0x1D
    static let LC_LOAD_DYLIB: UInt32 = 0x0C
    static let LC_LOAD_WEAK_DYLIB: UInt32 = 0x80000018
    static let LC_RPATH: UInt32 = 0x8000001C
    static let LC_ID_DYLIB: UInt32 = 0x0D
    static let LC_REEXPORT_DYLIB: UInt32 = 0x8000001F
    static let LC_REQ_DYLD: UInt32 = 0x80000000

    static let CPU_TYPE_ARM64: UInt32 = 0x0100000C
    static let CPU_TYPE_X86_64: UInt32 = 0x01000007
}

// MARK: - Mach-O Structures
struct MachOHeader64 {
    let magic: UInt32
    let cpuType: UInt32
    let cpuSubtype: UInt32
    let fileType: UInt32
    let numberOfCommands: UInt32
    let sizeOfCommands: UInt32
    let flags: UInt32
    let reserved: UInt32

    static let size = 32
}

struct LoadCommand {
    let cmd: UInt32
    let cmdSize: UInt32
    let offset: UInt64
}

struct LinkeditDataCommand {
    let cmd: UInt32
    let cmdSize: UInt32
    let dataOffset: UInt32
    let dataSize: UInt32
}

struct FatHeader {
    let magic: UInt32
    let numberOfArchitectures: UInt32
}

struct FatArch {
    let cpuType: UInt32
    let cpuSubtype: UInt32
    let offset: UInt32
    let size: UInt32
    let align: UInt32
}

// MARK: - MachOParser
class MachOParser {

    enum MachOError: LocalizedError {
        case invalidFile
        case notMachO
        case readFailed
        case unsupportedFormat

        var errorDescription: String? {
            switch self {
            case .invalidFile: return "File does not exist or cannot be read"
            case .notMachO: return "File is not a valid Mach-O binary"
            case .readFailed: return "Failed to read binary data"
            case .unsupportedFormat: return "Unsupported Mach-O format"
            }
        }
    }

    struct BinaryInfo {
        let path: String
        let isFat: Bool
        let is64Bit: Bool
        let cpuType: UInt32
        let loadCommands: [LoadCommand]
        let hasCodeSignature: Bool
        let codeSignatureOffset: UInt32?
        let codeSignatureSize: UInt32?
    }

    // MARK: - Public Methods

    /// Check if a file is a Mach-O binary
    static func isMachO(at path: String) -> Bool {
        guard let handle = FileHandle(forReadingAtPath: path) else { return false }
        defer { handle.closeFile() }

        let magicData = handle.readData(ofLength: 4)
        guard magicData.count == 4 else { return false }

        let magic = magicData.withUnsafeBytes { $0.load(as: UInt32.self) }
        return magic == MachOConstants.MH_MAGIC_64 ||
               magic == MachOConstants.MH_CIGAM_64 ||
               magic == MachOConstants.MH_MAGIC ||
               magic == MachOConstants.MH_CIGAM ||
               magic == MachOConstants.FAT_MAGIC ||
               magic == MachOConstants.FAT_CIGAM
    }

    /// Check if a file is a FAT (universal) binary
    static func isFatBinary(at path: String) -> Bool {
        guard let handle = FileHandle(forReadingAtPath: path) else { return false }
        defer { handle.closeFile() }

        let magicData = handle.readData(ofLength: 4)
        guard magicData.count == 4 else { return false }

        let magic = magicData.withUnsafeBytes { $0.load(as: UInt32.self) }
        return magic == MachOConstants.FAT_MAGIC || magic == MachOConstants.FAT_CIGAM
    }

    /// Parse a Mach-O binary and return info
    static func parse(at path: String) throws -> BinaryInfo {
        guard FileManager.default.fileExists(atPath: path) else {
            throw MachOError.invalidFile
        }

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            throw MachOError.readFailed
        }

        guard data.count >= 4 else { throw MachOError.notMachO }

        let magic = data.withUnsafeBytes { $0.load(as: UInt32.self) }

        if magic == MachOConstants.FAT_MAGIC || magic == MachOConstants.FAT_CIGAM {
            return try parseFatBinary(data: data, path: path)
        } else if magic == MachOConstants.MH_MAGIC_64 || magic == MachOConstants.MH_CIGAM_64 {
            return try parseMachO64(data: data, offset: 0, path: path, isFat: false)
        } else if magic == MachOConstants.MH_MAGIC || magic == MachOConstants.MH_CIGAM {
            // 32-bit not fully supported but detect it
            return BinaryInfo(path: path, isFat: false, is64Bit: false,
                            cpuType: 0, loadCommands: [],
                            hasCodeSignature: false,
                            codeSignatureOffset: nil, codeSignatureSize: nil)
        } else {
            throw MachOError.notMachO
        }
    }

    /// Find all Mach-O executables in an .app bundle
    static func findMachOFiles(in appPath: String) -> [String] {
        var machOFiles: [String] = []
        let fm = FileManager.default

        // Main executable
        if let infoPlistData = fm.contents(atPath: appPath + "/Info.plist"),
           let plist = try? PropertyListSerialization.propertyList(from: infoPlistData, format: nil) as? [String: Any],
           let execName = plist["CFBundleExecutable"] as? String {
            let execPath = appPath + "/" + execName
            if isMachO(at: execPath) {
                machOFiles.append(execPath)
            }
        }

        // Frameworks
        let frameworksPath = appPath + "/Frameworks"
        if let frameworks = try? fm.contentsOfDirectory(atPath: frameworksPath) {
            for framework in frameworks {
                let fwPath = frameworksPath + "/" + framework
                if framework.hasSuffix(".framework") {
                    let fwName = (framework as NSString).deletingPathExtension
                    let binaryPath = fwPath + "/" + fwName
                    if isMachO(at: binaryPath) {
                        machOFiles.append(binaryPath)
                    }
                } else if framework.hasSuffix(".dylib") {
                    if isMachO(at: fwPath) {
                        machOFiles.append(fwPath)
                    }
                }
            }
        }

        // PlugIns / App Extensions
        let plugInsPath = appPath + "/PlugIns"
        if let plugins = try? fm.contentsOfDirectory(atPath: plugInsPath) {
            for plugin in plugins where plugin.hasSuffix(".appex") {
                let pluginPath = plugInsPath + "/" + plugin
                // Recursively find Mach-Os in appex
                let nestedFiles = findMachOFiles(in: pluginPath)
                machOFiles.append(contentsOf: nestedFiles)
            }
        }

        return machOFiles
    }

    /// Read the list of load commands from a Mach-O 64-bit binary
    static func readLoadCommands(from path: String) throws -> [LoadCommand] {
        let info = try parse(at: path)
        return info.loadCommands
    }

    // MARK: - Private Methods

    private static func parseFatBinary(data: Data, path: String) throws -> BinaryInfo {
        guard data.count >= 8 else { throw MachOError.readFailed }

        let nArch = data.withUnsafeBytes { ptr -> UInt32 in
            let val = ptr.load(fromByteOffset: 4, as: UInt32.self)
            return UInt32(bigEndian: val)
        }

        // Find arm64 slice
        var arm64Offset: UInt32 = 0
        for i in 0..<nArch {
            let archOffset = 8 + Int(i) * 20
            guard data.count >= archOffset + 20 else { break }

            let cpuType = data.withUnsafeBytes { ptr -> UInt32 in
                UInt32(bigEndian: ptr.load(fromByteOffset: archOffset, as: UInt32.self))
            }
            let sliceOffset = data.withUnsafeBytes { ptr -> UInt32 in
                UInt32(bigEndian: ptr.load(fromByteOffset: archOffset + 8, as: UInt32.self))
            }

            if cpuType == MachOConstants.CPU_TYPE_ARM64 {
                arm64Offset = sliceOffset
                break
            }
        }

        if arm64Offset == 0 && nArch > 0 {
            // Use first slice
            arm64Offset = data.withUnsafeBytes { ptr -> UInt32 in
                UInt32(bigEndian: ptr.load(fromByteOffset: 16, as: UInt32.self))
            }
        }

        return try parseMachO64(data: data, offset: UInt64(arm64Offset), path: path, isFat: true)
    }

    private static func parseMachO64(data: Data, offset: UInt64, path: String, isFat: Bool) throws -> BinaryInfo {
        let baseOffset = Int(offset)
        guard data.count >= baseOffset + MachOHeader64.size else {
            throw MachOError.readFailed
        }

        let header: MachOHeader64 = data.withUnsafeBytes { ptr in
            MachOHeader64(
                magic: ptr.load(fromByteOffset: baseOffset, as: UInt32.self),
                cpuType: ptr.load(fromByteOffset: baseOffset + 4, as: UInt32.self),
                cpuSubtype: ptr.load(fromByteOffset: baseOffset + 8, as: UInt32.self),
                fileType: ptr.load(fromByteOffset: baseOffset + 12, as: UInt32.self),
                numberOfCommands: ptr.load(fromByteOffset: baseOffset + 16, as: UInt32.self),
                sizeOfCommands: ptr.load(fromByteOffset: baseOffset + 20, as: UInt32.self),
                flags: ptr.load(fromByteOffset: baseOffset + 24, as: UInt32.self),
                reserved: ptr.load(fromByteOffset: baseOffset + 28, as: UInt32.self)
            )
        }

        var loadCommands: [LoadCommand] = []
        var hasCodeSig = false
        var codeSigOffset: UInt32?
        var codeSigSize: UInt32?

        var cmdOffset = baseOffset + MachOHeader64.size

        for _ in 0..<header.numberOfCommands {
            guard data.count >= cmdOffset + 8 else { break }

            let cmd = data.withUnsafeBytes { $0.load(fromByteOffset: cmdOffset, as: UInt32.self) }
            let cmdSize = data.withUnsafeBytes { $0.load(fromByteOffset: cmdOffset + 4, as: UInt32.self) }

            let loadCmd = LoadCommand(cmd: cmd, cmdSize: cmdSize, offset: UInt64(cmdOffset))
            loadCommands.append(loadCmd)

            if cmd == MachOConstants.LC_CODE_SIGNATURE {
                hasCodeSig = true
                if data.count >= cmdOffset + 16 {
                    codeSigOffset = data.withUnsafeBytes {
                        $0.load(fromByteOffset: cmdOffset + 8, as: UInt32.self)
                    }
                    codeSigSize = data.withUnsafeBytes {
                        $0.load(fromByteOffset: cmdOffset + 12, as: UInt32.self)
                    }
                }
            }

            cmdOffset += Int(cmdSize)
        }

        return BinaryInfo(
            path: path,
            isFat: isFat,
            is64Bit: true,
            cpuType: header.cpuType,
            loadCommands: loadCommands,
            hasCodeSignature: hasCodeSig,
            codeSignatureOffset: codeSigOffset,
            codeSignatureSize: codeSigSize
        )
    }
}
