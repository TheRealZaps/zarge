import AppKit
import SwiftUI
import ZargeCore

/// Laid out like the system Now Playing panel: rows of artwork, a title over a secondary
/// line, and a trailing glyph, split by hairlines. The window behind it is the only glass,
/// so nothing in here uses glass (glass can't sample glass).
struct PanelView: View {
  @Bindable var model: AppModel

  var body: some View {
    VStack(spacing: 0) {
      StatusRow(model: model)

      Divider()

      switch model.daemonStatus {
      case .enabled:
        ThresholdRow(model: model)
      case .requiresApproval:
        ActionRow(text: "Allow the Zarge helper in System Settings, under Login Items & Extensions.")
      // macOS can report .notFound for a helper that is in the bundle but has never been
      // registered. register() gives the real error if it's actually missing.
      case .notRegistered, .notFound:
        ActionRow(text: "Zarge installs a small background helper that turns the MagSafe LED green at your chosen battery level.")
      @unknown default:
        NoteRow(symbol: "questionmark.circle", tint: .secondary, text: "Unknown helper state.")
      }

      if let error = model.errorMessage {
        Divider()
        NoteRow(symbol: "xmark.octagon.fill", tint: .red, text: error)
      }

      Divider()
      FooterRow(model: model)
    }
    .frame(width: 400)
    // Drag anywhere to move the panel. Child gestures (the threshold slider) win over this,
    // which AppKit's isMovableByWindowBackground doesn't guarantee for custom controls.
    .contentShape(.rect)
    .gesture(WindowDragGesture())
    .allowsWindowActivationEvents(true)
  }
}

private enum Metrics {
  static let artwork: CGFloat = 56
  static let rowPadding = EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)
  static let gap: CGFloat = 14
  static let title: CGFloat = 15
  static let body: CGFloat = 13
  static let led: CGFloat = 9
}

private enum Palette {
  // #E9C200: the icon's yellow. White text on it is unreadable (about 1.7:1), so the
  // label is near-black (about 12:1).
  static let primary = Color(red: 0xE9 / 255, green: 0xC2 / 255, blue: 0)
  static let onPrimary = Color.black.opacity(0.85)
}

private struct StatusRow: View {
  let model: AppModel

  var body: some View {
    HStack(spacing: Metrics.gap) {
      Image(nsImage: NSApp.applicationIconImage)
        .resizable()
        .frame(width: Metrics.artwork, height: Metrics.artwork)

      VStack(alignment: .leading, spacing: 2) {
        Text("Zarge")
          .font(.system(size: Metrics.title, weight: .semibold))
        subtitle
          .font(.system(size: Metrics.body))
          .foregroundStyle(.secondary)
          .monospacedDigit()
      }
      .lineLimit(1)

      Spacer(minLength: 0)
    }
    .padding(Metrics.rowPadding)
  }

  /// The helper's status with the slider's live value as the threshold, so the dot shows
  /// what the LED will do while the slider is still being dragged.
  private var liveHelper: HelperStatus? {
    guard var helper = model.helper else { return nil }
    helper.threshold = model.thresholdDraft
    return helper
  }

  @ViewBuilder private var subtitle: some View {
    if model.daemonStatus == .enabled, let helper = liveHelper {
      HStack(spacing: 6) {
        Text(helper.batteryPercent.map { "\($0)%" } ?? "?")
        // Derived from power state: reading ACLC back gives the last value written, not
        // the color on screen. No dot while unplugged, since the LED is off.
        if let led = helper.displayedLED {
          Circle()
            .fill(color(for: led))
            .frame(width: Metrics.led, height: Metrics.led)
            .animation(.easeOut(duration: 0.2), value: led)
            .help(tooltip(for: led, helper: helper))
        } else {
          Text("·")
        }
        Text(power(helper))
      }
    } else {
      Text(statusText)
    }
  }

  private var statusText: String {
    switch model.daemonStatus {
    case .enabled: "Helper not responding"
    case .requiresApproval: "Waiting for your approval"
    default: "Not installed"
    }
  }

  private func power(_ helper: HelperStatus) -> String {
    switch helper.onACPower {
    case true?: "plugged in"
    case false?: "on battery"
    case nil: "power unknown"
    }
  }

  private func tooltip(for led: MagSafeLED, helper: HelperStatus) -> String {
    switch led {
    case .green where helper.isEngaged: "MagSafe LED: green, held by Zarge at \(helper.threshold)%"
    case .green: "MagSafe LED: green, charged or charging paused"
    case .orange: "MagSafe LED: orange, charging"
    default: "MagSafe LED: \(led.description)"
    }
  }

  private func color(for led: MagSafeLED) -> Color {
    switch led {
    case .green: .green
    case .orange: .orange
    case .off: .secondary
    default: .red
    }
  }
}

private struct ThresholdRow: View {
  @Bindable var model: AppModel

  var body: some View {
    HStack(spacing: Metrics.gap) {
      Image(systemName: "bolt.fill")
        .font(.system(size: 22, weight: .semibold))
        .foregroundStyle(.secondary)
        .frame(width: Metrics.artwork)

      VStack(alignment: .leading, spacing: 6) {
        Text("Turn green at \(model.thresholdDraft)%")
          .font(.system(size: Metrics.title, weight: .semibold))
          .monospacedDigit()
        ThresholdSlider(value: $model.thresholdDraft) { editing in
          model.setEditingThreshold(editing)
        }
        .disabled(model.helper == nil)
      }
    }
    .padding(Metrics.rowPadding)
  }
}

/// A threshold slider whose track shows what the LED will do: orange below the thumb, where
/// macOS keeps charging orange, and green from the thumb up, where Zarge holds it green.
/// The system Slider can only color the part before the thumb, so this draws its own track.
private struct ThresholdSlider: View {
  @Binding var value: Int
  /// True when a drag starts, false when it ends (which saves). Arrow keys and VoiceOver
  /// report a start and an end per step.
  let onEditingChanged: (Bool) -> Void

  private let range = 50...100
  private let step = 5
  private let trackHeight: CGFloat = 6
  private let thumbSize = CGSize(width: 14, height: 22)

  @Environment(\.isEnabled) private var isEnabled
  @State private var isDragging = false

  var body: some View {
    GeometryReader { proxy in
      let usable = proxy.size.width - thumbSize.width
      let x = thumbSize.width / 2 + usable * fraction

      ZStack(alignment: .leading) {
        HStack(spacing: 0) {
          Capsule().fill(.orange).frame(width: x)
          Capsule().fill(.green)
        }
        .frame(height: trackHeight)

        Capsule()
          .fill(.white)
          .frame(width: thumbSize.width, height: thumbSize.height)
          .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
          .offset(x: x - thumbSize.width / 2)
      }
      .frame(maxHeight: .infinity)
      .contentShape(.rect)
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { drag in
            if !isDragging {
              isDragging = true
              onEditingChanged(true)
            }
            let position = (drag.location.x - thumbSize.width / 2) / max(usable, 1)
            value = snapped(Double(range.lowerBound) + position * Double(range.upperBound - range.lowerBound))
          }
          .onEnded { _ in
            isDragging = false
            onEditingChanged(false)
          }
      )
    }
    .frame(height: thumbSize.height)
    .opacity(isEnabled ? 1 : 0.4)
    .focusable()
    .focusEffectDisabled()
    .onKeyPress(.leftArrow) { nudge(-step) }
    .onKeyPress(.rightArrow) { nudge(step) }
    .accessibilityElement()
    .accessibilityLabel("Threshold")
    .accessibilityValue("\(value) percent")
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment: _ = nudge(step)
      case .decrement: _ = nudge(-step)
      @unknown default: break
      }
    }
  }

  /// Where the thumb sits along the track, clamped so a threshold saved outside the slider's
  /// range (the helper accepts 1 to 100) still draws on the track.
  private var fraction: Double {
    let clamped = min(max(value, range.lowerBound), range.upperBound)
    return Double(clamped - range.lowerBound) / Double(range.upperBound - range.lowerBound)
  }

  private func snapped(_ raw: Double) -> Int {
    let stepped = Int((raw / Double(step)).rounded()) * step
    return min(max(stepped, range.lowerBound), range.upperBound)
  }

  private func nudge(_ delta: Int) -> KeyPress.Result {
    let next = snapped(Double(value + delta))
    guard next != value else { return .handled }
    onEditingChanged(true)
    value = next
    onEditingChanged(false)
    return .handled
  }
}

/// Explains the next step; the button for it lives in the footer next to Done.
private struct ActionRow: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.system(size: Metrics.body))
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
    .padding(Metrics.rowPadding)
  }
}

private struct NoteRow: View {
  let symbol: String
  let tint: Color
  let text: String

  var body: some View {
    Label {
      Text(text).fixedSize(horizontal: false, vertical: true)
    } icon: {
      Image(systemName: symbol).foregroundStyle(tint)
    }
    .font(.system(size: Metrics.body))
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(Metrics.rowPadding)
  }
}

private struct FooterRow: View {
  let model: AppModel

  var body: some View {
    HStack {
      if model.daemonStatus == .enabled || model.daemonStatus == .requiresApproval {
        Button("Uninstall Helper") { Task { await model.uninstall() } }
          .disabled(model.isBusy)
      }
      Spacer()
      // The trailing-most button is the default action, so Done only takes Return when
      // there's no primary action to its right.
      Button("Done") { NSApp.keyWindow?.close() }
        .keyboardShortcut(hasPrimary ? nil : .defaultAction)
      primaryButton
    }
    .buttonStyle(.borderless)
    .font(.system(size: Metrics.body))
    .padding(.horizontal, Metrics.rowPadding.leading)
    .padding(.vertical, 12)
  }

  private var hasPrimary: Bool {
    switch model.daemonStatus {
    case .notRegistered, .notFound, .requiresApproval: true
    default: false
    }
  }

  @ViewBuilder private var primaryButton: some View {
    switch model.daemonStatus {
    case .notRegistered, .notFound:
      PrimaryButton(title: "Install Helper") { Task { await model.install() } }
        .disabled(model.isBusy)
    case .requiresApproval:
      PrimaryButton(title: "Open System Settings") { model.openLoginItems() }
    default:
      EmptyView()
    }
  }
}

private struct PrimaryButton: View {
  let title: String
  let action: () -> Void

  var body: some View {
    Button(title, action: action)
      .buttonStyle(PrimaryCapsuleStyle())
      .keyboardShortcut(.defaultAction)
  }
}

/// A yellow capsule with a dark label. .borderedProminent always draws a white label,
/// which can't be read on yellow.
private struct PrimaryCapsuleStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: Metrics.body, weight: .semibold))
      .foregroundStyle(Palette.onPrimary)
      .padding(.horizontal, 14)
      .padding(.vertical, 6)
      .background(Palette.primary.opacity(configuration.isPressed ? 0.8 : 1), in: .capsule)
      .opacity(isEnabled ? 1 : 0.45)
      .contentShape(.capsule)
  }
}
