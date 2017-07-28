import UIKit
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var reachability: Reachability!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        registerReachabilityForWifi()

        ExampleHotspotHelper.register(withDisplayName: "ExampleHotspotHelper")

        return true
    }


    func applicationDidBecomeActive(_ application: UIApplication) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { isSuccess, error in
            if !isSuccess {
                NSLog("Filed to reguster for notifications: \(String(describing: error))")
            }
        }
    }
}

// MARK: - Reachability

fileprivate extension AppDelegate {

    func registerReachabilityForWifi() {
        reachability = Reachability()
        reachability.notificationCenter.addObserver(self, selector: #selector(handleRechabilitiy(notification:)),
                                                    name: ReachabilityChangedNotification, object: nil)
        try! reachability.startNotifier()
    }

    @objc func handleRechabilitiy(notification: NSNotification) {        
        NSLog("Reachability status: \(reachability.currentReachabilityString)")
    }

}
