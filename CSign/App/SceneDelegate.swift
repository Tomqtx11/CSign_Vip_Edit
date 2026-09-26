import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let window = UIWindow(windowScene: windowScene)
        let mainTabBarController = MainTabBarController()
        window.rootViewController = mainTabBarController
        self.window = window
        window.makeKeyAndVisible()
        
        if let urlContext = connectionOptions.urlContexts.first {
            handleIncomingURLContext(urlContext)
        }
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let urlContext = URLContexts.first {
            handleIncomingURLContext(urlContext)
        }
    }
    
    private func handleIncomingURLContext(_ context: UIOpenURLContext) {
        let url = context.url
        print("Scene handled incoming URL: \(url)")
    }

    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}
}
