import Foundation

class StorageManager {
    static let shared = StorageManager()
    
    private let fileManager = FileManager.default
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    public let ipaLibraryPath: URL
    public let signedAppsPath: URL
    public let certificatesPath: URL
    public let provisionsPath: URL
    
    private init() {
    var ipaLibraryDirectory: String { ipaLibraryPath.path }
    var signedAppsDirectory: String { signedAppsPath.path }
    var certificatesDirectory: String { certificatesPath.path }
    var provisionsDirectory: String { provisionsPath.path }
        ipaLibraryPath = documentsDirectory.appendingPathComponent("IPALibrary")
        signedAppsPath = documentsDirectory.appendingPathComponent("SignedApps")
        certificatesPath = documentsDirectory.appendingPathComponent("Certificates")
        provisionsPath = documentsDirectory.appendingPathComponent("Provisions")
    }
    
    func saveIPAs(_ ipas: [IPAFile]) {
        saveData(ipas, to: ipaLibraryPath.appendingPathComponent("ipas.json"), key: "ipas")
    }
    
    func loadIPAs() -> [IPAFile] {
        return loadData(from: ipaLibraryPath.appendingPathComponent("ipas.json"), key: "ipas") ?? []
    }
    
    func saveCertificates(_ certificates: [Certificate]) {
        saveData(certificates, to: certificatesPath.appendingPathComponent("certificates.json"), key: "certificates")
    }
    
    func loadCertificates() -> [Certificate] {
        return loadData(from: certificatesPath.appendingPathComponent("certificates.json"), key: "certificates") ?? []
    }
    
    func saveSignedApps(_ apps: [SignedApp]) {
        saveData(apps, to: signedAppsPath.appendingPathComponent("signedApps.json"), key: "signedApps")
    }
    
    func loadSignedApps() -> [SignedApp] {
        return loadData(from: signedAppsPath.appendingPathComponent("signedApps.json"), key: "signedApps") ?? []
    }
    
    func saveProfiles(_ profiles: [ProvisionProfile]) {
        saveData(profiles, to: provisionsPath.appendingPathComponent("profiles.json"), key: "profiles")
    }
    
    func loadProfiles() -> [ProvisionProfile] {
        return loadData(from: provisionsPath.appendingPathComponent("profiles.json"), key: "profiles") ?? []
    }
    
    private func saveData<T: Codable>(_ data: T, to url: URL, key: String) {
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: url)
        } catch {
            print("Failed to save to file, falling back to UserDefaults: \(error)")
            if let encoded = try? JSONEncoder().encode(data) {
                UserDefaults.standard.set(encoded, forKey: key)
            }
        }
    }
    
    private func loadData<T: Codable>(from url: URL, key: String) -> T? {
        if let data = try? Data(contentsOf: url) {
            return try? JSONDecoder().decode(T.self, from: data)
        } else if let fallbackData = UserDefaults.standard.data(forKey: key) {
            return try? JSONDecoder().decode(T.self, from: fallbackData)
        }
        return nil
    }
    
    func totalStorageUsed() -> Int64 {
        var total: Int64 = 0
        let urls = [ipaLibraryPath, signedAppsPath, certificatesPath, provisionsPath]
        
        for url in urls {
            if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let fileURL as URL in enumerator {
                    if let attrs = try? fileURL.resourceValues(forKeys: [.fileSizeKey]), let size = attrs.fileSize {
                        total += Int64(size)
                    }
                }
            }
        }
        return total
    }
    
    func clearCache() {
        let tempDir = fileManager.temporaryDirectory
        if let enumerator = fileManager.enumerator(at: tempDir, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }
}
