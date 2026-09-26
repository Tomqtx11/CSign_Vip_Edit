import Foundation
import Security

// MARK: - CertificateParser
class CertificateParser {

    enum ParseError: LocalizedError {
        case fileNotFound
        case invalidP12(String)
        case invalidProfile
        case extractionFailed

        var errorDescription: String? {
            switch self {
            case .fileNotFound: return "File not found"
            case .invalidP12(let msg): return "Invalid P12 file: \(msg)"
            case .invalidProfile: return "Invalid provisioning profile"
            case .extractionFailed: return "Failed to extract certificate data"
            }
        }
    }

    // MARK: - P12 Certificate Parsing

    /// Parse a PKCS12 (.p12) file and return a Certificate model
    static func parsePKCS12(at path: String, password: String) -> Certificate? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        guard let p12Data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }

        let options: [String: Any] = [kSecImportExportPassphrase as String: password]
        var rawItems: CFArray?

        let status = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &rawItems)

        guard status == errSecSuccess,
              let items = rawItems as? [[String: Any]],
              let firstItem = items.first else {
            return nil
        }

        guard let identity = firstItem[kSecImportItemIdentity as String] else {
            return nil
        }

        let secIdentity = identity as! SecIdentity
        var certRef: SecCertificate?
        SecIdentityCopyCertificate(secIdentity, &certRef)

        guard let certificate = certRef else { return nil }

        // Extract certificate details
        let commonName = extractCommonName(from: certificate)
        let summary = SecCertificateCopySubjectSummary(certificate) as String? ?? "Unknown"

        var organization: String?
        var orgUnit: String?
        var serialNumber = ""
        var creationDate = Date()
        var expirationDate = Date().addingTimeInterval(365 * 24 * 3600)

        // Try to get detailed values
        if let certData = SecCertificateCopyData(certificate) as Data? {
            let details = parseCertificateDetails(from: certData)
            organization = details.organization
            orgUnit = details.orgUnit
            serialNumber = details.serialNumber
            if let notBefore = details.notBefore { creationDate = notBefore }
            if let notAfter = details.notAfter { expirationDate = notAfter }
        }

        // Get serial from cert if not parsed
        if serialNumber.isEmpty {
            if let serialData = SecCertificateCopySerialNumberData(certificate, nil) as Data? {
                serialNumber = serialData.map { String(format: "%02X", $0) }.joined(separator: ":")
            }
        }

        return Certificate(
            id: UUID().uuidString,
            name: summary,
            commonName: commonName ?? summary,
            organization: organization,
            organizationUnit: orgUnit,
            serialNumber: serialNumber,
            expirationDate: expirationDate,
            creationDate: creationDate,
            p12FilePath: path,
            importDate: Date()
        )
    }

    /// Extract the private key from a P12 file
    static func extractIdentity(from p12Path: String, password: String) -> (SecIdentity, SecCertificate, SecKey)? {
        guard let p12Data = try? Data(contentsOf: URL(fileURLWithPath: p12Path)) else { return nil }

        let options: [String: Any] = [kSecImportExportPassphrase as String: password]
        var rawItems: CFArray?

        let status = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &rawItems)
        guard status == errSecSuccess,
              let items = rawItems as? [[String: Any]],
              let firstItem = items.first,
              let identity = firstItem[kSecImportItemIdentity as String] else {
            return nil
        }

        let secIdentity = identity as! SecIdentity

        var certRef: SecCertificate?
        SecIdentityCopyCertificate(secIdentity, &certRef)
        guard let cert = certRef else { return nil }

        var keyRef: SecKey?
        SecIdentityCopyPrivateKey(secIdentity, &keyRef)
        guard let key = keyRef else { return nil }

        return (secIdentity, cert, key)
    }

    // MARK: - Provisioning Profile Parsing

    /// Parse a .mobileprovision file
    static func parseProvisioningProfile(at path: String) -> ProvisionProfile? {
        guard FileManager.default.fileExists(atPath: path),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }

        // Extract the plist from the CMS signed data
        guard let plistData = extractPlistFromProvision(data) else { return nil }

        guard let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            return nil
        }

        let name = plist["Name"] as? String ?? "Unknown"
        let appIDName = plist["AppIDName"] as? String ?? ""
        let teamName = plist["TeamName"] as? String ?? ""
        let uuid = plist["UUID"] as? String ?? UUID().uuidString

        let teamIds = plist["TeamIdentifier"] as? [String] ?? []
        let teamId = teamIds.first ?? ""

        let creationDate = plist["CreationDate"] as? Date ?? Date()
        let expirationDate = plist["ExpirationDate"] as? Date ?? Date()

        let entitlements = plist["Entitlements"] as? [String: Any] ?? [:]
        let appId = entitlements["application-identifier"] as? String ?? ""

        // Extract bundle identifier from application-identifier (remove team prefix)
        var bundleId = appId
        if bundleId.contains(".") {
            let parts = bundleId.split(separator: ".", maxSplits: 1)
            if parts.count > 1 {
                bundleId = String(parts[1])
            }
        }

        // Device UDIDs
        let devices = plist["ProvisionedDevices"] as? [String] ?? []

        return ProvisionProfile(
            id: UUID().uuidString,
            name: name,
            appIDName: appIDName,
            teamName: teamName,
            teamIdentifier: teamId,
            bundleIdentifier: bundleId,
            creationDate: creationDate,
            expirationDate: expirationDate,
            uuid: uuid,
            filePath: path,
            entitlements: entitlements,
            deviceUDIDs: devices
        )
    }

    /// Extract entitlements from a provisioning profile
    static func extractEntitlements(from profile: ProvisionProfile) -> [String: Any] {
        return profile.entitlements
    }

    // MARK: - Private Helpers

    private static func extractCommonName(from certificate: SecCertificate) -> String? {
        var commonName: CFString?
        let status = SecCertificateCopyCommonName(certificate, &commonName)
        if status == errSecSuccess, let name = commonName as String? {
            return name
        }
        return nil
    }

    /// Extract plist data from a CMS-signed provisioning profile
    private static func extractPlistFromProvision(_ data: Data) -> Data? {
        // Find the plist XML within the CMS envelope
        guard let xmlStart = findSequence(in: data, target: Data("<?xml".utf8)),
              let plistEnd = findSequence(in: data, target: Data("</plist>".utf8)) else {
            return nil
        }

        let endIndex = plistEnd + "</plist>".count
        guard endIndex <= data.count else { return nil }

        return data.subdata(in: xmlStart..<endIndex)
    }

    private static func findSequence(in data: Data, target: Data) -> Int? {
        guard target.count <= data.count else { return nil }

        let targetBytes = [UInt8](target)
        let dataBytes = [UInt8](data)

        outer: for i in 0...(dataBytes.count - targetBytes.count) {
            for j in 0..<targetBytes.count {
                if dataBytes[i + j] != targetBytes[j] {
                    continue outer
                }
            }
            return i
        }
        return nil
    }

    /// Parse certificate DER data for detailed fields
    private static func parseCertificateDetails(from derData: Data) -> (organization: String?, orgUnit: String?, serialNumber: String, notBefore: Date?, notAfter: Date?) {
        // Simple OID-based extraction from DER data
        let bytes = [UInt8](derData)

        var organization: String?
        var orgUnit: String?
        var serialNumber = ""
        var notBefore: Date?
        var notAfter: Date?

        // OID for Organization: 2.5.4.10 = 55 04 0A
        if let orgStr = findOIDValue(in: bytes, oid: [0x55, 0x04, 0x0A]) {
            organization = orgStr
        }

        // OID for Org Unit: 2.5.4.11 = 55 04 0B
        if let ouStr = findOIDValue(in: bytes, oid: [0x55, 0x04, 0x0B]) {
            orgUnit = ouStr
        }

        // Parse validity dates from the certificate
        // Look for UTCTime (tag 0x17) or GeneralizedTime (tag 0x18)
        let dates = findDates(in: bytes)
        if dates.count >= 2 {
            notBefore = dates[0]
            notAfter = dates[1]
        }

        return (organization, orgUnit, serialNumber, notBefore, notAfter)
    }

    private static func findOIDValue(in bytes: [UInt8], oid: [UInt8]) -> String? {
        for i in 0..<(bytes.count - oid.count - 4) {
            if bytes[i] == 0x06 { // OID tag
                let oidLen = Int(bytes[i + 1])
                if i + 2 + oidLen <= bytes.count && oidLen >= oid.count {
                    let oidBytes = Array(bytes[(i + 2)..<(i + 2 + oidLen)])
                    if oidBytes.prefix(oid.count).elementsEqual(oid) {
                        // Next should be the value (usually UTF8String 0x0C or PrintableString 0x13)
                        let valueStart = i + 2 + oidLen
                        if valueStart + 2 < bytes.count {
                            let valueTag = bytes[valueStart]
                            if valueTag == 0x0C || valueTag == 0x13 || valueTag == 0x16 {
                                let valueLen = Int(bytes[valueStart + 1])
                                let strStart = valueStart + 2
                                if strStart + valueLen <= bytes.count {
                                    return String(bytes: Array(bytes[strStart..<(strStart + valueLen)]), encoding: .utf8)
                                }
                            }
                        }
                    }
                }
            }
        }
        return nil
    }

    private static func findDates(in bytes: [UInt8]) -> [Date] {
        var dates: [Date] = []
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for i in 0..<(bytes.count - 2) {
            if bytes[i] == 0x17 { // UTCTime
                let len = Int(bytes[i + 1])
                if i + 2 + len <= bytes.count {
                    let timeBytes = Array(bytes[(i + 2)..<(i + 2 + len)])
                    if let timeStr = String(bytes: timeBytes, encoding: .ascii) {
                        formatter.dateFormat = "yyMMddHHmmss'Z'"
                        if let date = formatter.date(from: timeStr) {
                            dates.append(date)
                        }
                    }
                }
            } else if bytes[i] == 0x18 { // GeneralizedTime
                let len = Int(bytes[i + 1])
                if i + 2 + len <= bytes.count {
                    let timeBytes = Array(bytes[(i + 2)..<(i + 2 + len)])
                    if let timeStr = String(bytes: timeBytes, encoding: .ascii) {
                        formatter.dateFormat = "yyyyMMddHHmmss'Z'"
                        if let date = formatter.date(from: timeStr) {
                            dates.append(date)
                        }
                    }
                }
            }
        }

        return dates
    }
}
