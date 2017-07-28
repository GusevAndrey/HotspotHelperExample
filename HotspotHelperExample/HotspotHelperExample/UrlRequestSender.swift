import Foundation
import NetworkExtension

/// Helper class doing exapmle URL request during handling connection to Wi-Fi
final class UrlRequestSender: NSObject {

    // MARK: -  Properties

    let url: URL
    let completion: (Data?, Error?) -> Void

    fileprivate var responseData = Data()

    private let delegateQueue = OperationQueue()
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral        
        return URLSession(configuration: configuration, delegate: self, delegateQueue: self.delegateQueue)
    }()

    // MARK: - Init & Deinit

    init(with url: URL, completion: @escaping (Data?, Error?) -> Void) {
        self.url = url
        self.completion = completion

        super.init()
    }

    deinit {
        stop()
    }

    // MARK: - Public methods

    func start(with command: NEHotspotHelperCommand) {
        let urlRequest = NSMutableURLRequest(url: url)
        urlRequest.bind(to: command) // Bind request with command. Otherwice request will fail with no internet connection error 

        // You can configure and hanlde URL request as needed here

        session.dataTask(with: urlRequest as URLRequest).resume()
    }

    func stop() {
        session.invalidateAndCancel()
    }

}

// MARK: - URLSessionTaskDelegate

extension UrlRequestSender: URLSessionTaskDelegate {

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard error == nil else {
            NSLog("Request failed: \(error!)")
            completion(nil, error)
            return
        }

        NSLog("Request finished")
        completion(responseData, nil)
    }

}

// MARK: - URLSessionDataDelegate

extension UrlRequestSender: URLSessionDataDelegate {

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {

        NSLog("Got URL responce data")
        responseData.append(data)

    }

}
