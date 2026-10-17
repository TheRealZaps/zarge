/// Values of the `ACLC` SMC key, which drives the MagSafe connector LED.
package enum MagSafeLED: UInt8, Sendable, Codable, CustomStringConvertible {
  case system = 0x00
  case off = 0x01
  case green = 0x03
  case orange = 0x04
  case errorOnce = 0x05
  case errorPermSlow = 0x06
  case errorPermFast = 0x07
  case errorPermOff = 0x19

  /// Decodes a raw `ACLC` byte. Some firmware reports green as 0x02. Anything unrecognized
  /// reads as orange, so the daemon never mistakes it for the state it wants and rewrites it.
  package init(smcValue: UInt8) {
    self = if smcValue == 0x02 { .green } else { MagSafeLED(rawValue: smcValue) ?? .orange }
  }

  package var description: String {
    switch self {
    case .system: "system"
    case .off: "off"
    case .green: "green"
    case .orange: "orange"
    case .errorOnce: "error-once"
    case .errorPermSlow: "error-perm-slow"
    case .errorPermFast: "error-perm-fast"
    case .errorPermOff: "error-perm-off"
    }
  }
}

package enum SMCKeys {
  package static let magSafeLED: SMCKey = "ACLC"
  package static let acPower: SMCKey = "AC-W"
  package static let batteryCharge: SMCKey = "BUIC"
}

extension SMC {
  package func batteryPercent() throws(SMCError) -> Int {
    let value = try read(SMCKeys.batteryCharge)
    guard value.count == 1 else { throw .unexpectedSize(SMCKeys.batteryCharge, expected: 1, actual: value.count) }
    return Int(value[0])
  }

  package func isOnACPower() throws(SMCError) -> Bool {
    let value = try read(SMCKeys.acPower)
    return value.count == 1 && Int8(bitPattern: value[0]) > 0
  }

  package func magSafeLED() throws(SMCError) -> MagSafeLED {
    let value = try read(SMCKeys.magSafeLED)
    guard value.count == 1 else { throw .unexpectedSize(SMCKeys.magSafeLED, expected: 1, actual: value.count) }
    return MagSafeLED(smcValue: value[0])
  }

  package func setMagSafeLED(_ state: MagSafeLED) throws(SMCError) {
    try write(SMCKeys.magSafeLED, [state.rawValue])
  }

  package var hasMagSafeLED: Bool {
    (try? read(SMCKeys.magSafeLED)) != nil
  }
}
