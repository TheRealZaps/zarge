import AppKit
import SwiftUI

/// A borderless window whose whole background is Liquid Glass, like the system Now Playing
/// panel. The SwiftUI content lives inside the NSGlassEffectView (as its contentView, which
/// is the only placement AppKit guarantees sits in the glass), and the window itself is
/// transparent so the glass can see the desktop. The glass sits in a container clipped to
/// its own rounded shape, so nothing can draw in the window's square corners.
final class GlassPanel: NSWindow {
  init(rootView: some View, cornerRadius: CGFloat = 22) {
    super.init(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
    title = "Zarge"
    isOpaque = false
    backgroundColor = .clear
    hasShadow = true
    // Dragging is handled by WindowDragGesture in PanelView, which yields to controls.
    isMovableByWindowBackground = false
    isReleasedWhenClosed = false

    let host = SelfSizingHostingView(rootView: rootView)
    host.sizingOptions = [.intrinsicContentSize]
    host.translatesAutoresizingMaskIntoConstraints = false

    let glass = NSGlassEffectView()
    glass.style = .regular
    glass.cornerRadius = cornerRadius
    glass.contentView = host
    glass.translatesAutoresizingMaskIntoConstraints = false

    // While the window is key, the glass adds an active-state layer whose shading spills
    // past its rounded outline. The window's rectangle stops it, so the 22pt corners showed
    // dark square patches (and the shadow, built from the window's alpha, went square too).
    // Clipping a plain container to the same continuous rounded rect keeps every pixel
    // outside the glass outline fully transparent, so the shadow follows the curve.
    let container = NSView()
    container.wantsLayer = true
    container.clipsToBounds = true
    container.layer?.cornerRadius = cornerRadius
    container.layer?.cornerCurve = .continuous
    container.layer?.masksToBounds = true
    container.addSubview(glass)
    contentView = container

    NSLayoutConstraint.activate([
      glass.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      glass.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      glass.topAnchor.constraint(equalTo: container.topAnchor),
      glass.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      host.leadingAnchor.constraint(equalTo: glass.leadingAnchor),
      host.trailingAnchor.constraint(equalTo: glass.trailingAnchor),
      host.topAnchor.constraint(equalTo: glass.topAnchor),
      host.bottomAnchor.constraint(equalTo: glass.bottomAnchor),
    ])
    setContentSize(host.fittingSize)
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }

  /// Borderless windows have no close button, so performClose would just beep.
  override func performClose(_ sender: Any?) { close() }

  /// Esc closes the panel, like dismissing a menu.
  override func cancelOperation(_ sender: Any?) { close() }

  override func setFrame(_ frameRect: NSRect, display flag: Bool) {
    super.setFrame(frameRect, display: flag)
    // The shadow follows the glass outline; recompute it whenever the size changes.
    invalidateShadow()
  }
}

/// Resizes its window to fit the SwiftUI content whenever that content changes size, for
/// example when an error row appears. Auto Layout alone doesn't resize a borderless window.
private final class SelfSizingHostingView<Content: View>: NSHostingView<Content> {
  override func invalidateIntrinsicContentSize() {
    super.invalidateIntrinsicContentSize()
    // Measure after SwiftUI finishes the update that triggered this.
    Task { @MainActor [weak self] in self?.fitWindow() }
  }

  private func fitWindow() {
    guard let window else { return }
    let size = fittingSize
    guard window.frame.size != size else { return }
    var frame = window.frame
    frame.origin.y += frame.height - size.height  // keep the top edge where it is
    frame.size = size
    window.setFrame(frame, display: true)
  }
}
