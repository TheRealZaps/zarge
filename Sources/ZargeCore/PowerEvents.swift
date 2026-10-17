import Foundation
import IOKit.ps

/// Yields whenever macOS reports a power-source change: plug, unplug, charging state, or
/// battery percentage. Events that arrive faster than they are consumed collapse into one.
///
/// The notification source runs on the main run loop, so the process must run it
/// (`RunLoop.main.run()` or an app's event loop), not `dispatchMain()`.
package func powerSourceChanges() -> AsyncStream<Void> {
  AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
    let callbackContext = PowerCallbackContext(continuation: continuation)
    // Balanced by the release in onTermination. The C callback only borrows it.
    let context = Unmanaged.passRetained(callbackContext).toOpaque()

    let callback: IOPowerSourceCallbackType = { context in
      guard let context else { return }
      Unmanaged<PowerCallbackContext>.fromOpaque(context)
        .takeUnretainedValue().continuation.yield()
    }
    guard let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() else {
      Unmanaged<PowerCallbackContext>.fromOpaque(context).release()
      continuation.finish()
      return
    }

    let runLoopSource = RunLoopSource(source)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    continuation.onTermination = { _ in
      // Tear down on the main thread, where the callback runs, so no callback can be
      // mid-flight when the context it reads is released.
      DispatchQueue.main.async {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource.source, .defaultMode)
        Unmanaged.passUnretained(callbackContext).release()
      }
    }
  }
}

/// The C callback's context. Immutable, and the continuation is Sendable, so this is too.
private final class PowerCallbackContext: Sendable {
  let continuation: AsyncStream<Void>.Continuation

  init(continuation: AsyncStream<Void>.Continuation) {
    self.continuation = continuation
  }
}

/// Carries the run-loop source into the termination handler. CFRunLoopSource isn't marked
/// Sendable, but this box never changes it, and adding and removing CF run-loop sources is
/// thread-safe.
private final class RunLoopSource: @unchecked Sendable {
  let source: CFRunLoopSource

  init(_ source: CFRunLoopSource) {
    self.source = source
  }
}
