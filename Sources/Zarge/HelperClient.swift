import Foundation
import ZargeCore

enum HelperClientError: LocalizedError {
  case badProxy

  var errorDescription: String? { "The helper's XPC interface didn't match." }
}

/// Talks to the root helper. Opens a connection per call: calls are rare (menu opens,
/// power events, slider releases), and a fresh connection never goes stale after the
/// helper restarts.
struct HelperClient {
  func status() async throws -> HelperStatus {
    try await call { proxy, reply in proxy.status(reply: reply) }
  }

  func setThreshold(_ threshold: Int) async throws -> HelperStatus {
    try await call { proxy, reply in proxy.setThreshold(threshold, reply: reply) }
  }

  private func call(
    _ send: (ZargeHelperProtocol, @escaping @Sendable (Data) -> Void) -> Void
  ) async throws -> HelperStatus {
    let connection = NSXPCConnection(machServiceName: ZargeIdentifiers.machService, options: .privileged)
    connection.remoteObjectInterface = NSXPCInterface(with: ZargeHelperProtocol.self)
    connection.setCodeSigningRequirement(CodeSigningRequirement.peer(identifier: ZargeIdentifiers.helper))
    connection.resume()
    defer { connection.invalidate() }

    let data: Data = try await withCheckedThrowingContinuation { continuation in
      // XPC calls exactly one of these two: the error handler or the reply.
      let proxy = connection.remoteObjectProxyWithErrorHandler { error in
        continuation.resume(throwing: error)
      }
      guard let helper = proxy as? ZargeHelperProtocol else {
        continuation.resume(throwing: HelperClientError.badProxy)
        return
      }
      send(helper) { data in continuation.resume(returning: data) }
    }
    return try HelperStatus(decoding: data)
  }
}
