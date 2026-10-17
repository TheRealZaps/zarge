import Foundation
import Security

/// Bundle and launchd names. They must match Resources/ and scripts/build-app.sh.
package enum ZargeIdentifiers {
  package static let app = "dev.zarge.Zarge"
  package static let helper = "dev.zarge.Zarge.helper"
  package static let machService = helper
  package static let daemonPlistName = "\(helper).plist"
}

/// What the helper reports to the app. Sent as JSON so the XPC interface stays primitive.
package struct HelperStatus: Codable, Sendable, Equatable {
  package var batteryPercent: Int?
  package var onACPower: Bool?
  /// The raw `ACLC` read-back. It echoes the last value written, not the color on screen,
  /// so show `displayedLED` instead.
  package var led: MagSafeLED?
  /// Optional so a status from an older helper, which never sent it, still decodes.
  package var isCharging: Bool?
  package var threshold: Int
  package var error: String?

  package init(
    batteryPercent: Int?, onACPower: Bool?, led: MagSafeLED?, isCharging: Bool? = nil,
    threshold: Int, error: String? = nil
  ) {
    self.batteryPercent = batteryPercent
    self.onACPower = onACPower
    self.led = led
    self.isCharging = isCharging
    self.threshold = threshold
    self.error = error
  }

  /// True while zarge is the one holding the LED green.
  package var isEngaged: Bool {
    guard let batteryPercent, let onACPower else { return false }
    return desiredLED(batteryPercent: batteryPercent, onACPower: onACPower, threshold: threshold) == .green
  }

  /// The color the LED shows, or nil when it is off or a reading is missing. Charging only
  /// matters below the threshold, so a missing `isCharging` hides nothing while engaged.
  package var displayedLED: MagSafeLED? {
    guard let onACPower, let batteryPercent else { return nil }
    if isEngaged { return .green }
    guard let isCharging else { return nil }
    return ZargeCore.displayedLED(
      onACPower: onACPower, batteryPercent: batteryPercent, threshold: threshold, isCharging: isCharging
    )
  }

  package func encoded() -> Data {
    // A struct of optionals and integers cannot fail to encode.
    try! JSONEncoder().encode(self)
  }

  package init(decoding data: Data) throws {
    self = try JSONDecoder().decode(HelperStatus.self, from: data)
  }
}

@objc package protocol ZargeHelperProtocol {
  func status(reply: @escaping @Sendable (Data) -> Void)
  /// Replies with the status after the change, with `error` set if `threshold` was rejected.
  func setThreshold(_ threshold: Int, reply: @escaping @Sendable (Data) -> Void)
}

package enum CodeSigningRequirement {
  /// The requirement the other end of the XPC connection must meet: signed by the same
  /// team as this process. Ad hoc builds have no team, so they fall back to the identifier
  /// alone, which any local process could fake. Only ship team-signed builds.
  package static func peer(identifier: String) -> String {
    guard let team = currentTeamID() else { return "identifier \"\(identifier)\"" }
    return "anchor apple generic and identifier \"\(identifier)\" and certificate leaf[subject.OU] = \"\(team)\""
  }

  package static func currentTeamID() -> String? {
    var code: SecCode?
    guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
    var staticCode: SecStaticCode?
    guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return nil }
    var info: CFDictionary?
    let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
    guard SecCodeCopySigningInformation(staticCode, flags, &info) == errSecSuccess,
          let info = info as? [String: Any]
    else { return nil }
    return info[kSecCodeInfoTeamIdentifier as String] as? String
  }
}
