import UIKit

class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        setupAppearance()
    }
    
    private func setupTabs() {
        let appsVC = AppLibraryViewController()
        appsVC.title = "Apps"
        let appsNav = UINavigationController(rootViewController: appsVC)
        appsNav.tabBarItem = UITabBarItem(title: "Apps", image: UIImage(systemName: "square.grid.2x2"), tag: 0)
        
        let signedVC = SignedAppsViewController()
        signedVC.title = "Signed"
        let signedNav = UINavigationController(rootViewController: signedVC)
        signedNav.tabBarItem = UITabBarItem(title: "Signed", image: UIImage(systemName: "checkmark.seal"), tag: 1)
        
        let certsVC = CertificateListViewController()
        certsVC.title = "Certs"
        let certsNav = UINavigationController(rootViewController: certsVC)
        certsNav.tabBarItem = UITabBarItem(title: "Certs", image: UIImage(systemName: "lock.shield"), tag: 2)
        
        let filesVC = FileManagerViewController()
        filesVC.title = "Files"
        let filesNav = UINavigationController(rootViewController: filesVC)
        filesNav.tabBarItem = UITabBarItem(title: "Files", image: UIImage(systemName: "folder"), tag: 3)
        
        let settingsVC = SettingsViewController()
        settingsVC.title = "Settings"
        let settingsNav = UINavigationController(rootViewController: settingsVC)
        settingsNav.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gearshape"), tag: 4)
        
        self.viewControllers = [appsNav, signedNav, certsNav, filesNav, settingsNav]
    }
    
    private func setupAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        appearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
        
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
        tabBar.isTranslucent = true
    }
}
