import Foundation
import Security

struct Certificate: Codable, Identifiable {
    let id: String
    var name: String
    var commonName: String
    var organization: String?
    var organizationUnit: String?
    var serialNumber: String
    var expirationDate: Date
    var creationDate: Date
    var p12FilePath: String
    var isExpired: Bool { expirationDate < Date() }
    var daysUntilExpiration: Int { Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0 }
    var importDate: Date
    
    static func parse(p12Path: String, password: String) -> Certificate? {
        guard let p12Data = try? Data(contentsOf: URL(fileURLWithPath: p12Path)) else {
            return nil
        }
        
        let options: [String: Any] = [kSecImportExportPassphrase as String: password]
        var items: CFArray?
        
        let status = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &items)
        
        guard status == errSecSuccess, let itemsArray = items as? [[String: Any]], let firstItem = itemsArray.first else {
            return nil
        }
        
        guard let identity = firstItem[kSecImportItemIdentity as String] as! SecIdentity? else {
            return nil
        }
        
        var cert: SecCertificate?
        SecIdentityCopyCertificate(identity, &cert)
        
        guard let certificate = cert else { return nil }
        
        var commonName: CFString?
        SecCertificateCopyCommonName(certificate, &commonName)
        let nameString = (commonName as String?) ?? "Unknown Certificate"
        
        return Certificate(
            id: UUID().uuidString,
            name: nameString,
            commonName: nameString,
            organization: nil,
            organizationUnit: nil,
            serialNumber: "0",
            expirationDate: Date().addingTimeInterval(365 * 24 * 3600),
            creationDate: Date(),
            p12FilePath: p12Path,
            importDate: Date()
        )
    }
}
