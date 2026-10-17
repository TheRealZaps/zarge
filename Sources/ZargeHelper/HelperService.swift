import Foundation
import ZargeCore

/// The object the app talks to. XPC calls it on a private queue; each call hops to the
/// main actor, where the controller lives.
nonisolated final class HelperService: NSObject, ZargeHelperProtocol, Sendable {
  private let controller: LEDController

  init(controller: LEDController) {
    self.controller = controller
  }

  func status(reply: @escaping @Sendable (Data) -> Void) {
    Task { @MainActor in reply(controller.status().encoded()) }
  }

  func setThreshold(_ threshold: Int, reply: @escaping @Sendable (Data) -> Void) {
    Task { @MainActor in reply(controller.setThreshold(threshold).encoded()) }
  }
}

nonisolated final class ListenerDelegate: NSObject, NSXPCListenerDelegate, Sendable {
  private let service: HelperService
  private let clientRequirement = CodeSigningRequirement.peer(identifier: ZargeIdentifiers.app)

  init(service: HelperService) {
    self.service = service
  }

  func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
    // Rejects any client that isn't the Zarge app signed by the same team as this helper.
    connection.setCodeSigningRequirement(clientRequirement)
    connection.exportedInterface = NSXPCInterface(with: ZargeHelperProtocol.self)
    connection.exportedObject = service
    connection.resume()
    return true
  }
}
