import Foundation

struct SignedApp: Codable, Identifiable {
    let id: String
    var originalApp: String
    var bundleName: String
    var bundleIdentifier: String
    var version: String
    var certificateName: String
    var signedIPAPath: String
    var signDate: Date
    var signLog: String
    var installed: Bool
    var fileSize: Int64
}
