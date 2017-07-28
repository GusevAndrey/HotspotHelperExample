import Foundation
import NetworkExtension
import UIKit
import UserNotifications


final class ExampleHotspotHelper {

    /// The result is always nil until helper is registered
    static var activeNetwork: NEHotspotNetwork? {
        guard let network = NEHotspotHelper.managedSupportedNetworkInterfaces()?.first as? NEHotspotNetwork else {
            // According to documentation this should mean no active wifi-network connection
            return nil
        }

        // In fact empty network is returned if there is no active networks (despite of documentation...)
        let isEmptyNetwork = (network.ssid == "" && network.bssid == "" && network.signalStrength == 0.0)
        return isEmptyNetwork ? nil : network
    }

    /// Handler could be successefuly registered at max once for a run and could not be reconfigured
    /// so for this example made it static class
    private init() { /* Do nothing */ }

    static func register(withDisplayName displayName: String? = nil, completion: ((_ isRegistered: Bool) -> Void)? = nil) {
        queue.async {
            guard NEHotspotHelper.register(options: options(withDisplayName: displayName), queue: queue, handler: hotspotHandler) else {
                // Hotspot helper have to be registered once and only once at a run                
                assertionFailure("Failed to register as a hotspot helper (NOTE: Simulator does not support hotspot helper)")
                completion?(false)
                return
            }

            NSLog("Hotspot helper is registered")

            // NOTE: There is an active network on application launch caused receiving evaluate/maintain command
            if let network = activeNetwork {
                // You could handle the network connected before helper is registered here
                NSLog("Connected network before helper registration ssid: <\(network.ssid)> bssid: <\(network.bssid)>")
            }

            completion?(true)
        }
    }

    @discardableResult static func performLogoff() -> Bool {
        guard let network = activeNetwork else {
            NSLog("Has logoff started: \(false)")
            return false
        }

        let hasLogoffStarted = NEHotspotHelper.logoff(network)
        NSLog("Has logoff started: \(hasLogoffStarted)")

        return hasLogoffStarted
    }

}

// MARK: - Private Methods

fileprivate extension ExampleHotspotHelper {

    // Serial queue to handle hotspot helper callbacks
    static let queue = DispatchQueue(label: "HotspotHelperQueue", qos: .userInitiated)

    static let hotspotHandler: NEHotspotHelperHandler = { command in
        let application = UIApplication.shared
        let backgroundTime = (application.applicationState == .background)
            ? "Remaining time: \(application.backgroundTimeRemaining)"
            : "Running foreground"

        NSLog("Did receive command: \(command). \(backgroundTime)")

        switch command.commandType {
        case .none:
            assertionFailure("Should not ever receive .none command")
            break

        case .filterScanList:
            handle(filterScanList: command)

        case .evaluate:
            handle(evaluate: command)

        case .authenticate:
            handle(authenticate: command)

        case .presentUI:
            handle(presentUI: command)

        case .maintain:
            handle(maintain: command)

        case .logoff:
            handle(logoff: command)            
        }
    }

    static func options(withDisplayName displayName: String?) -> [String : NSObject]? {
        guard let displayName = displayName else {
            return nil
        }

        // Currently only one options is supported: kNEHotspotHelperOptionDisplayNamed
        return [kNEHotspotHelperOptionDisplayName : displayName as NSObject]
    }

}

// MARK: - Command Handlers

fileprivate extension ExampleHotspotHelper {

    static func handle(filterScanList command: NEHotspotHelperCommand) {
        guard let networkList = command.networkList else {
            NSLog("<ERROR> No network list provided for filterScanList command: \(command)")
            command.createResponse(.temporaryFailure).deliver()
            return
        }

        NSLog("FilterScanList:\n\(networkList.map { String(describing: $0) }.joined(separator: "\n"))")

        let response = command.createResponse(.success)

        let ssidToFilter = "MyWiFiNework"
        if let indexOfNetwork = networkList.index(where: { $0.ssid == ssidToFilter }) {
            let network = networkList[indexOfNetwork]

            // Set password if needed for secured networks
            let myWiFiNeworkPassword = "MySuperSecurePassword"
            network.setPassword(myWiFiNeworkPassword)

            NSLog("Filter network: \(network)")
            response.setNetworkList([network])
        }

        response.deliver()
    }

    static func handle(evaluate command: NEHotspotHelperCommand) {
        guard let network = command.network else {
            NSLog("<ERROR> No network provided for evaluation command: \(command)")
            command.createResponse(.temporaryFailure).deliver()
            return
        }

        NSLog("Evaluate network: \(network)")

        // NOTE: In production you should not set hight confidence for all the networks you receive
        network.setConfidence(.high)

        let response = command.createResponse(.success)
        response.setNetwork(network)
        response.deliver()
    }

    static func handle(authenticate command: NEHotspotHelperCommand) {
        guard let network = command.network else {
            NSLog("<ERROR> No network provided for authenticate command: \(command)")
            command.createResponse(.temporaryFailure).deliver()
            return
        }

        NSLog("Authenticate network: \(network)")

        // NOTE: Here you can considere network connected if no UI needed

        if UIApplication.shared.applicationState == .background {
            let content = UNMutableNotificationContent()
            content.title = "Authentication Required"
            content.body = "Open App to connect to: \(network.ssid)"
            let request = UNNotificationRequest(identifier: "UIRequiredNotification", content: content, trigger: nil)

            UNUserNotificationCenter.current().add(request) { error in
                let result: NEHotspotHelperResult = (error != nil)
                    ? .temporaryFailure
                    : .uiRequired
                command.createResponse(result).deliver()
            }
        }
        else {
            command.createResponse(.uiRequired).deliver()
        }
    }

    static var urlSender: UrlRequestSender?

    static func handle(presentUI command: NEHotspotHelperCommand) {
        guard let network = command.network else {
            NSLog("<ERROR> No network provided for presentUI command: \(command)")
            command.createResponse(.temporaryFailure).deliver()
            return
        }

        NSLog("present UI for network: \(network)")

        // NOTE: Here you can handle authentication for infinit ammount of time
        // Send example URL request. You can sand any request you want.        
        urlSender = UrlRequestSender(with: URL(string: "http://touch.kaspersky.com")!) { responce, error in
            NSLog("present UI for network: \(network) has finished")
            let result: NEHotspotHelperResult = (error != nil)
                ? .temporaryFailure
                : .success
            command.createResponse(result).deliver()
        }
        urlSender?.start(with: command)
    }

    static func handle(maintain command: NEHotspotHelperCommand) {
        guard let network = command.network else {
            NSLog("<ERROR> No network provided for maintain command: \(command)")
            command.createResponse(.temporaryFailure).deliver()
            return
        }

        if network.didJustJoin {
            // Just connect to network that has been evaluated before
            NSLog("Handle newly connected network: \(network)")
            command.createResponse(.authenticationRequired).deliver()
        }
        else {
            // Still connected to the network (maintain is called every 300 sec while connected)
            NSLog("Maintain connection for network: \(network)")
            command.createResponse(.success).deliver()
        }
    }

    static func handle(logoff command: NEHotspotHelperCommand) {
        guard let network = command.network else {
            NSLog("<ERROR> No network provided for logoff command: \(command)")
            command.createResponse(.temporaryFailure).deliver()
            return
        }

        // Perform any actions for complete authentication and clean up

        NSLog("Logging off from network: \(network)")
        command.createResponse(.success).deliver()
    }
}

//MARK: - Workaround for NEHotspotHelper nullability misdeclaration (iOS SDK 10.2) NOTE: Fixed in iOS11
/*!
 * @return
 *   nil if no network interfaces are being managed,
 *   non-nil NSArray of NEHotspotNetwork objects otherwise.
 */
fileprivate extension NEHotspotHelper {
    static func managedSupportedNetworkInterfaces() -> [Any]? {
        var result: [Any]!
        if let unmanaged = NEHotspotHelper.perform(#selector(NEHotspotHelper.supportedNetworkInterfaces)) {
            result = unmanaged.takeUnretainedValue() as? [Any]
        }
        
        return result
    }
}
