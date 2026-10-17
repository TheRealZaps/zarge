import Foundation
import os
import ZargeCore

let log = Logger(subsystem: ZargeIdentifiers.helper, category: "daemon")

/// Owns the SMC connection and decides what the LED shows. Everything runs on the main actor:
/// power events, XPC requests, and SIGTERM all hop here, so no state is shared across threads.
final class LEDController {
  /// macOS reports a burst of changes around plug and unplug. Waiting for them to settle
  /// avoids writing the LED against a half-updated reading.
  private static let settleDelay = Duration.milliseconds(750)

  private let smc: SMC
  private let settings: SettingsStore
  private(set) var threshold: Int
  private var settleTask: Task<Void, Never>?
  /// The last state written successfully. `ACLC` can't say what the LED shows, so this is
  /// what decides whether to write. Nil at start, so the first step always writes.
  private var lastWritten: MagSafeLED?

  init(smc: consuming SMC, settings: SettingsStore) {
    self.smc = smc
    self.settings = settings
    threshold = settings.load().threshold
  }

  func start() {
    log.notice("zarge helper started, threshold=\(self.threshold, privacy: .public)")
    step()
    Task {
      for await _ in powerSourceChanges() {
        scheduleStep()
      }
    }
  }

  func status() -> HelperStatus {
    var errors: [String] = []
    func attempt<T>(_ read: () throws(SMCError) -> T) -> T? {
      do { return try read() } catch {
        errors.append(error.description)
        return nil
      }
    }
    return HelperStatus(
      batteryPercent: attempt { () throws(SMCError) in try smc.batteryPercent() },
      onACPower: attempt { () throws(SMCError) in try smc.isOnACPower() },
      led: attempt { () throws(SMCError) in try smc.magSafeLED() },
      isCharging: isBatteryCharging(),
      threshold: threshold,
      error: errors.isEmpty ? nil : errors.joined(separator: "; ")
    )
  }

  func setThreshold(_ value: Int) -> HelperStatus {
    guard Threshold.valid.contains(value) else {
      var status = status()
      status.error = "threshold must be \(Threshold.valid.lowerBound) to \(Threshold.valid.upperBound)"
      return status
    }
    do {
      try settings.save(Settings(threshold: value))
    } catch {
      var status = status()
      status.error = "could not save threshold: \(error.localizedDescription)"
      return status
    }
    threshold = value
    log.notice("threshold set to \(value, privacy: .public)")
    step()
    return status()
  }

  /// Gives the LED back to macOS. Called on SIGTERM, which launchd sends when the app
  /// unregisters the helper, so uninstalling never leaves the LED stuck green.
  func releaseLED() {
    settleTask?.cancel()
    do {
      try smc.setMagSafeLED(.system)
      lastWritten = .system
    } catch {
      log.error("release LED: \(error.description, privacy: .public)")
    }
  }

  private func scheduleStep() {
    settleTask?.cancel()
    settleTask = Task {
      try? await Task.sleep(for: Self.settleDelay)
      guard !Task.isCancelled else { return }
      step()
    }
  }

  private func step() {
    do {
      let battery = try smc.batteryPercent()
      let onAC = try smc.isOnACPower()
      let desired = desiredLED(batteryPercent: battery, onACPower: onAC, threshold: threshold)
      // Only a hint for re-asserting green; a failed read must not block the write.
      let readBack = try? smc.magSafeLED()
      guard let next = ledToWrite(desired: desired, lastWritten: lastWritten, readBack: readBack) else {
        return
      }
      log.info("battery=\(battery, privacy: .public)% ac=\(onAC, privacy: .public) last=\(self.lastWritten?.description ?? "none", privacy: .public) read=\(readBack?.description ?? "failed", privacy: .public) -> \(next, privacy: .public)")
      try smc.setMagSafeLED(next)
      lastWritten = next
    } catch {
      log.error("step: \(error.description, privacy: .public)")
    }
  }
}
