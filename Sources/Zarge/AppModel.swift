import AppKit
import Observation
import ServiceManagement
import ZargeCore

@Observable
final class AppModel {
  private(set) var daemonStatus: SMAppService.Status
  private(set) var helper: HelperStatus?
  private(set) var errorMessage: String?
  private(set) var isBusy = false
  var thresholdDraft = Threshold.default

  private let daemon = SMAppService.daemon(plistName: ZargeIdentifiers.daemonPlistName)
  private let client = HelperClient()
  /// Bumped for every helper request. Replies can land out of order (a power-event refresh
  /// that started before a threshold change), so only the newest one is applied.
  private var latestRequest = 0
  /// While the slider is held, replies must not move it out from under the cursor.
  private var isEditingThreshold = false

  init() {
    daemonStatus = daemon.status
    Task { await watchPower() }
  }

  /// The one place status is fetched from, besides the threshold reply: on launch and on
  /// every return to the app (AppDelegate), and after power events (`watchPower()`).
  func refresh() async {
    daemonStatus = daemon.status
    guard daemonStatus == .enabled else {
      helper = nil
      return
    }
    await request { try await $0.status() }
  }

  func install() async {
    await perform {
      try daemon.register()
    }
    // On a first install register() throws "Operation not permitted" and leaves the daemon
    // waiting for the user's OK in System Settings. That's the expected path, not a failure.
    if daemon.status == .requiresApproval {
      errorMessage = nil
      SMAppService.openSystemSettingsLoginItems()
    }
  }

  func uninstall() async {
    await perform {
      try await daemon.unregister()
    }
  }

  func openLoginItems() {
    SMAppService.openSystemSettingsLoginItems()
  }

  /// Called by the slider when a drag starts and ends. Ending a drag saves the value.
  func setEditingThreshold(_ editing: Bool) {
    isEditingThreshold = editing
    if !editing { Task { await commitThreshold() } }
  }

  /// The reply carries the new threshold, and the status dot derives its color from it, so
  /// the dot is right as soon as the reply lands. Charging changes still arrive through
  /// `watchPower()`.
  func commitThreshold() async {
    let value = thresholdDraft
    guard value != helper?.threshold else { return }
    await request { try await $0.setThreshold(value) }
  }

  /// Sends one request and applies its reply only if no newer request started meanwhile.
  private func request(_ send: (HelperClient) async throws -> HelperStatus) async {
    latestRequest += 1
    let id = latestRequest
    do {
      let status = try await send(client)
      guard id == latestRequest else { return }
      helper = status
      errorMessage = status.error
      if !isEditingThreshold { thresholdDraft = status.threshold }
    } catch {
      guard id == latestRequest else { return }
      helper = nil
      errorMessage = "Helper isn't responding. \(error.localizedDescription)"
    }
  }

  private func perform(_ action: () async throws -> Void) async {
    isBusy = true
    defer { isBusy = false }
    errorMessage = nil
    do {
      try await action()
    } catch {
      errorMessage = error.localizedDescription
    }
    await refresh()
  }

  /// Keeps the readings current while the window is open. The helper waits 750 ms for
  /// power events to settle before it writes the LED, so read a moment after that.
  private func watchPower() async {
    for await _ in powerSourceChanges() {
      try? await Task.sleep(for: .seconds(1))
      await refresh()
    }
  }
}
