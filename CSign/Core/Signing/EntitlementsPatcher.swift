import Foundation

// MARK: - EntitlementsPatcher
class EntitlementsPatcher {

    /// Generate entitlements plist data from a provisioning profile
    static func generateEntitlements(profile: ProvisionProfile, bundleId: String) -> Data? {
        var entitlements = profile.entitlements

        // Update application-identifier with correct team prefix and bundle ID
        if !profile.teamIdentifier.isEmpty {
            entitlements["application-identifier"] = "\(profile.teamIdentifier).\(bundleId)"
        }

        // Update team identifier
        entitlements["com.apple.developer.team-identifier"] = profile.teamIdentifier

        // Update keychain access groups
        if var keychainGroups = entitlements["keychain-access-groups"] as? [String] {
            keychainGroups = keychainGroups.map { group in
                if group.contains("*") {
                    return "\(profile.teamIdentifier).\(bundleId)"
                }
                return group
            }
            entitlements["keychain-access-groups"] = keychainGroups
        } else {
            entitlements["keychain-access-groups"] = ["\(profile.teamIdentifier).\(bundleId)"]
        }

        // Update app groups if present
        if let appGroups = entitlements["com.apple.security.application-groups"] as? [String] {
            entitlements["com.apple.security.application-groups"] = appGroups
        }

        // Ensure get-task-allow matches profile type
        // Development profiles have get-task-allow = true
        // Distribution profiles have get-task-allow = false
        if entitlements["get-task-allow"] == nil {
            entitlements["get-task-allow"] = true
        }

        return serializeEntitlements(entitlements)
    }

    /// Generate minimal entitlements for ad-hoc signing (no profile)
    static func generateMinimalEntitlements(bundleId: String, teamId: String = "") -> Data? {
        var entitlements: [String: Any] = [:]

        if !teamId.isEmpty {
            entitlements["application-identifier"] = "\(teamId).\(bundleId)"
            entitlements["com.apple.developer.team-identifier"] = teamId
            entitlements["keychain-access-groups"] = ["\(teamId).\(bundleId)"]
        }

        entitlements["get-task-allow"] = true

        return serializeEntitlements(entitlements)
    }

    /// Patch an existing entitlements plist with new bundle ID
    static func patchEntitlements(at path: String, newBundleId: String, teamId: String) -> Bool {
        guard var entitlements = loadEntitlements(from: path) else { return false }

        entitlements["application-identifier"] = "\(teamId).\(newBundleId)"
        entitlements["com.apple.developer.team-identifier"] = teamId

        if var keychainGroups = entitlements["keychain-access-groups"] as? [String] {
            keychainGroups = keychainGroups.map { group in
                let parts = group.split(separator: ".", maxSplits: 1)
                if parts.count > 1 {
                    return "\(teamId).\(newBundleId)"
                }
                return group
            }
            entitlements["keychain-access-groups"] = keychainGroups
        }

        guard let data = serializeEntitlements(entitlements) else { return false }

        do {
            try data.write(to: URL(fileURLWithPath: path))
            return true
        } catch {
            return false
        }
    }

    /// Read entitlements from an embedded.mobileprovision inside an app bundle
    static func readEntitlementsFromApp(appPath: String) -> [String: Any]? {
        let profilePath = appPath + "/embedded.mobileprovision"
        guard let profile = CertificateParser.parseProvisioningProfile(at: profilePath) else {
            return nil
        }
        return profile.entitlements
    }

    /// Write entitlements to a file
    static func writeEntitlements(_ entitlements: [String: Any], to path: String) -> Bool {
        guard let data = serializeEntitlements(entitlements) else { return false }
        do {
            try data.write(to: URL(fileURLWithPath: path))
            return true
        } catch {
            return false
        }
    }

    /// Merge two entitlements dictionaries (base + override)
    static func mergeEntitlements(base: [String: Any], override: [String: Any]) -> [String: Any] {
        var merged = base
        for (key, value) in override {
            merged[key] = value
        }
        return merged
    }

    // MARK: - Private Helpers

    private static func loadEntitlements(from path: String) -> [String: Any]? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    }

    private static func serializeEntitlements(_ entitlements: [String: Any]) -> Data? {
        return try? PropertyListSerialization.data(
            fromPropertyList: entitlements,
            format: .xml,
            options: 0
        )
    }
}
