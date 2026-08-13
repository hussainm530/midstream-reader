import UIKit

/// Classic app lifecycle. `UISceneDelegate` is iOS 13, so this is the only
/// option on a 12.5.8 device -- and the simpler one regardless for a
/// single-window app.
@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let nav = UINavigationController(rootViewController: LibraryViewController())
        nav.navigationBar.tintColor = UIColor(red: 0.54, green: 0.35, blue: 0.17, alpha: 1)

        let w = UIWindow(frame: UIScreen.main.bounds)
        w.rootViewController = nav
        w.makeKeyAndVisible()
        window = w
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Opportunistic: if the tailnet happens to be reachable, deliver
        // whatever accumulated offline. Fails quietly when it is not.
        SyncClient.shared.flush()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        SyncClient.shared.flush()
    }
}
