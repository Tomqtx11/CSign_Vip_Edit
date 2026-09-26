import Foundation
import Network
import UIKit

class OTAInstaller {
    static let shared = OTAInstaller()
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var serverPort: UInt16 = 8765
    private var timeoutTimer: Timer?
    
    private var currentIpaPath: String?
    private var currentBundleId: String?
    private var currentBundleName: String?
    
    private init() {}
    
    func installApp(ipaPath: String, bundleId: String, bundleName: String, completion: @escaping (Bool, String?) -> Void) {
        self.currentIpaPath = ipaPath
        self.currentBundleId = bundleId
        self.currentBundleName = bundleName
        
        do {
            if listener != nil {
                stopServer()
            }
            
            let parameters = NWParameters.tcp
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: serverPort) ?? .any)
            
            listener?.stateUpdateHandler = { [weak self] state in
                guard let self = self else { return }
                switch state {
                case .ready:
                    guard let port = self.listener?.port else {
                        completion(false, "Failed to get server port")
                        return
                    }
                    self.serverPort = port.rawValue
                    self.triggerInstall(completion: completion)
                    self.startTimeout()
                case .failed(let error):
                    self.stopServer()
                    completion(false, "Server failed: \(error.localizedDescription)")
                default:
                    break
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: .global())
            
        } catch {
            completion(false, "Failed to start server: \(error.localizedDescription)")
        }
    }
    
    private func triggerInstall(completion: @escaping (Bool, String?) -> Void) {
        let manifestURLString = "https://127.0.0.1:\(serverPort)/manifest.plist"
        let itmsURLString = "itms-services://?action=download-manifest&url=\(manifestURLString)"
        
        guard let url = URL(string: itmsURLString) else {
            completion(false, "Invalid URL")
            return
        }
        
        DispatchQueue.main.async {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:]) { success in
                    if success {
                        completion(true, nil)
                    } else {
                        completion(false, "Failed to open itms-services URL")
                    }
                }
            } else {
                completion(false, "Cannot open itms-services URL")
            }
        }
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connections.append(connection)
        connection.stateUpdateHandler = { [weak self] state in
            if case .failed = state {
                self?.connections.removeAll(where: { $0 === connection })
            }
        }
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self, let data = data, !data.isEmpty else {
                connection.cancel()
                return
            }
            
            if let requestString = String(data: data, encoding: .utf8) {
                if requestString.contains("GET /manifest.plist") {
                    self.serveManifest(to: connection)
                } else if requestString.contains("GET /app.ipa") {
                    self.serveIPA(to: connection)
                } else {
                    self.serveNotFound(to: connection)
                }
            }
        }
        connection.start(queue: .global())
    }
    
    private func serveManifest(to connection: NWConnection) {
        let ipaURL = "http://127.0.0.1:\(serverPort)/app.ipa"
        let manifestContent = ManifestGenerator.generateManifest(
            ipaURL: ipaURL,
            bundleId: currentBundleId ?? "com.unknown",
            bundleName: currentBundleName ?? "Unknown"
        )
        
        let manifestData = manifestContent.data(using: .utf8) ?? Data()
        sendResponse(to: connection, contentType: "text/xml", data: manifestData)
    }
    
    private func serveIPA(to connection: NWConnection) {
        guard let path = currentIpaPath,
              let fileData = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            serveNotFound(to: connection)
            return
        }
        sendResponse(to: connection, contentType: "application/octet-stream", data: fileData)
    }
    
    private func serveNotFound(to connection: NWConnection) {
        let response = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n"
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }
    
    private func sendResponse(to connection: NWConnection, contentType: String, data: Data) {
        let header = "HTTP/1.1 200 OK\r\nContent-Type: \(contentType)\r\nContent-Length: \(data.count)\r\n\r\n"
        var responseData = header.data(using: .utf8) ?? Data()
        responseData.append(data)
        
        connection.send(content: responseData, completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }
    
    private func startTimeout() {
        DispatchQueue.main.async {
            self.timeoutTimer?.invalidate()
            self.timeoutTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: false) { [weak self] _ in
                self?.stopServer()
            }
        }
    }
    
    func stopServer() {
        listener?.cancel()
        listener = nil
        connections.forEach { $0.cancel() }
        connections.removeAll()
        
        DispatchQueue.main.async {
            self.timeoutTimer?.invalidate()
            self.timeoutTimer = nil
        }
    }
}
