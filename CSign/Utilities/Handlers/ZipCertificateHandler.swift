import Foundation
import Zip

class ZipCertificateHandler {
    static func extractCertificate(from zipURL: URL, completion: @escaping (URL?, URL?) -> Void) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
            try Zip.unzipFile(zipURL, destination: tempDir, overwrite: true, password: nil)
            
            var p12URL: URL? = nil
            var provisionURL: URL? = nil
            
            if let enumerator = FileManager.default.enumerator(at: tempDir, includingPropertiesForKeys: nil) {
                for case let fileURL as URL in enumerator {
                    if fileURL.pathExtension.lowercased() == "p12" {
                        p12URL = fileURL
                    } else if fileURL.pathExtension.lowercased() == "mobileprovision" {
                        provisionURL = fileURL
                    }
                }
            }
            completion(p12URL, provisionURL)
        } catch {
            completion(nil, nil)
        }
    }
}
