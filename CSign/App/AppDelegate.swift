import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Configure app appearance
        UINavigationBar.appearance().tintColor = .systemBlue
        UITabBar.appearance().tintColor = .systemBlue
        
        // Create documents directory structure
        createDirectoryStructure()
        
        return true
    }
    
    private func createDirectoryStructure() {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        let directories = ["IPALibrary", "SignedApps", "Certificates", "Provisions"]
        
        for dir in directories {
            let dirPath = documentsDirectory.appendingPathComponent(dir)
            if !fileManager.fileExists(atPath: dirPath.path) {
                do {
                    try fileManager.createDirectory(at: dirPath, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print("Error creating directory \(dir): \(error.localizedDescription)")
                }
            }
        }
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return handleIncomingURL(url)
    }
    
    private func handleIncomingURL(_ url: URL) -> Bool {
        let fileExtension = url.pathExtension.lowercased()
        
        switch fileExtension {
        case "ipa":
            print("Importing IPA: \(url.lastPathComponent)")
            return true
        case "p12":
            print("Importing Certificate: \(url.lastPathComponent)")
            return true
        case "mobileprovision":
            print("Importing Provisioning Profile: \(url.lastPathComponent)")
            return true
        default:
            if url.scheme == "csign" {
                print("Handled csign URL scheme")
                return true
            }
            return false
        }
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
}
