import Foundation

struct ProvisionProfile: Codable, Identifiable {
    let id: String
    var name: String
    var appIDName: String
    var teamName: String
    var teamIdentifier: String
    var bundleIdentifier: String
    var creationDate: Date
    var expirationDate: Date
    var uuid: String
    var filePath: String
    var isExpired: Bool { expirationDate < Date() }
    var entitlements: [String: Any]
    var deviceUDIDs: [String]
    
    enum CodingKeys: String, CodingKey {
        case id, name, appIDName, teamName, teamIdentifier, bundleIdentifier, creationDate, expirationDate, uuid, filePath, entitlementsData, deviceUDIDs
    }
    
    init(id: String, name: String, appIDName: String, teamName: String, teamIdentifier: String, bundleIdentifier: String, creationDate: Date, expirationDate: Date, uuid: String, filePath: String, entitlements: [String: Any], deviceUDIDs: [String]) {
        self.id = id
        self.name = name
        self.appIDName = appIDName
        self.teamName = teamName
        self.teamIdentifier = teamIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.creationDate = creationDate
        self.expirationDate = expirationDate
        self.uuid = uuid
        self.filePath = filePath
        self.entitlements = entitlements
        self.deviceUDIDs = deviceUDIDs
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        appIDName = try container.decode(String.self, forKey: .appIDName)
        teamName = try container.decode(String.self, forKey: .teamName)
        teamIdentifier = try container.decode(String.self, forKey: .teamIdentifier)
        bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        creationDate = try container.decode(Date.self, forKey: .creationDate)
        expirationDate = try container.decode(Date.self, forKey: .expirationDate)
        uuid = try container.decode(String.self, forKey: .uuid)
        filePath = try container.decode(String.self, forKey: .filePath)
        deviceUDIDs = try container.decode([String].self, forKey: .deviceUDIDs)
        
        let data = try container.decode(Data.self, forKey: .entitlementsData)
        if let dict = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
            entitlements = dict
        } else {
            entitlements = [:]
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(appIDName, forKey: .appIDName)
        try container.encode(teamName, forKey: .teamName)
        try container.encode(teamIdentifier, forKey: .teamIdentifier)
        try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
        try container.encode(creationDate, forKey: .creationDate)
        try container.encode(expirationDate, forKey: .expirationDate)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(filePath, forKey: .filePath)
        try container.encode(deviceUDIDs, forKey: .deviceUDIDs)
        
        let data = try PropertyListSerialization.data(fromPropertyList: entitlements, format: .binary, options: 0)
        try container.encode(data, forKey: .entitlementsData)
    }
}
