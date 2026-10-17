package enum Threshold {
  package static let `default` = 90
  package static let valid = 1...100
}

/// The LED state zarge wants: green while plugged in at or above `threshold`, otherwise
/// handed back to macOS.
package func desiredLED(batteryPercent: Int, onACPower: Bool, threshold: Int) -> MagSafeLED {
  onACPower && batteryPercent >= threshold ? .green : .system
}

/// The state to write, or nil to leave the LED alone.
///
/// `ACLC` reads back the last value written, not the color the LED shows (after writing
/// `.system` it can read orange while unplugged), so the decision rests on `lastWritten`,
/// which is nil until the first write. The read-back only matters for green: firmware can
/// drop the override (after sleep, for one), so a green target is rewritten whenever the
/// key no longer reads green. A failed read-back is nil and counts as not green.
package func ledToWrite(desired: MagSafeLED, lastWritten: MagSafeLED?, readBack: MagSafeLED?) -> MagSafeLED? {
  if desired != lastWritten { return desired }
  if desired == .green && readBack != .green { return desired }
  return nil
}

/// The color the MagSafe LED actually shows, derived from power state instead of read back:
/// off (nil) when unplugged, green while zarge holds it, otherwise what macOS shows, which
/// is orange while charging and green when full or when charging is paused.
package func displayedLED(onACPower: Bool, batteryPercent: Int, threshold: Int, isCharging: Bool) -> MagSafeLED? {
  guard onACPower else { return nil }
  if desiredLED(batteryPercent: batteryPercent, onACPower: onACPower, threshold: threshold) == .green {
    return .green
  }
  return isCharging ? .orange : .green
}
