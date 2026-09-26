import Foundation

enum FileType: String {
    case ipa
    case p12
    case mobileprovision
    case dylib
    case plist
    case image
    case text
    case binary
    case directory
    case unknown
}

class FileSystemHelper {
    static let shared = FileSystemHelper()
    private let fileManager = FileManager.default
    
    private init() {}
    
    func listContents(of directory: String) -> [(name: String, path: String, isDirectory: Bool, size: Int64, modDate: Date)] {
        var contents: [(name: String, path: String, isDirectory: Bool, size: Int64, modDate: Date)] = []
        let url = URL(fileURLWithPath: directory)
        
        do {
            let items = try fileManager.contentsOfDirectory(atPath: directory)
            for item in items {
                let itemPath = url.appendingPathComponent(item).path
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: itemPath, isDirectory: &isDir) {
                    let attrs = try fileManager.attributesOfItem(atPath: itemPath)
                    let size = attrs[.size] as? Int64 ?? 0
                    let modDate = attrs[.modificationDate] as? Date ?? Date()
                    contents.append((name: item, path: itemPath, isDirectory: isDir.boolValue, size: size, modDate: modDate))
                }
            }
        } catch {
            print("Error listing contents: \(error)")
        }
        return contents
    }
    
    func fileSize(at path: String) -> Int64 {
        do {
            let attrs = try fileManager.attributesOfItem(atPath: path)
            return attrs[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    func fileType(at path: String) -> FileType {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir) else { return .unknown }
        if isDir.boolValue { return .directory }
        
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "ipa": return .ipa
        case "p12": return .p12
        case "mobileprovision": return .mobileprovision
        case "dylib": return .dylib
        case "plist": return .plist
        case "png", "jpg", "jpeg": return .image
        case "txt", "log", "strings", "json", "xml", "html", "css", "js": return .text
        case "bin": return .binary
        default: return .unknown
        }
    }
    
    func deleteItem(at path: String) throws {
        try fileManager.removeItem(atPath: path)
    }
    
    func copyItem(from: String, to: String) throws {
        try fileManager.copyItem(atPath: from, toPath: to)
    }
    
    func moveItem(from: String, to: String) throws {
        try fileManager.moveItem(atPath: from, toPath: to)
    }
    
    func createDirectory(at path: String) throws {
        try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
    }
    
    func isReadableFile(at path: String) -> Bool {
        return fileManager.isReadableFile(atPath: path)
    }
    
    func iconName(for fileType: FileType) -> String {
        switch fileType {
        case .directory: return "folder.fill"
        case .ipa: return "app.fill"
        case .p12: return "key.fill"
        case .mobileprovision: return "doc.badge.gearshape.fill"
        case .dylib: return "puzzlepiece.fill"
        case .plist: return "list.bullet.rectangle"
        case .image: return "photo.fill"
        case .text: return "doc.text.fill"
        case .binary: return "chevron.left.forwardslash.chevron.right"
        case .unknown: return "doc.fill"
        }
    }
}
