import IOKit.ps

/// Whether the internal battery is charging right now, from IOPowerSources (what the menu
/// bar battery shows). False when full or when macOS holds the charge, for example with
/// Optimized Battery Charging. Nil when there is no internal battery or no reading.
package func isBatteryCharging() -> Bool? {
  guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
        let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
  else { return nil }

  for source in sources {
    guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
          description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
          let charging = description[kIOPSIsChargingKey] as? Bool
    else { continue }
    let charged = description[kIOPSIsChargedKey] as? Bool ?? false
    return charging && !charged
  }
  return nil
}
