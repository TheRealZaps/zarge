import Foundation
import ZargeCore

func usage() {
  print("""
    zarge-helper: keeps the MagSafe LED green at a battery threshold.

    Usage:
      zarge-helper run      run the daemon (launchd starts this as root)
      zarge-helper status   print battery, AC, LED and charging state; writes nothing
    """)
}

func runDaemon() -> Never {
  guard getuid() == 0 else {
    log.fault("run needs root; install the helper from the Zarge app")
    print("zarge-helper: run needs root. Install the helper from the Zarge app.")
    exit(1)
  }

  let smc: SMC
  do {
    smc = try SMC()
  } catch {
    log.fault("open SMC: \(error.description, privacy: .public)")
    exit(1)
  }
  guard smc.hasMagSafeLED else {
    log.fault("MagSafe LED key (ACLC) not present on this hardware")
    exit(1)
  }

  let controller = LEDController(smc: smc, settings: SettingsStore())
  let delegate = ListenerDelegate(service: HelperService(controller: controller))
  let listener = NSXPCListener(machServiceName: ZargeIdentifiers.machService)
  listener.delegate = delegate
  listener.resume()

  signal(SIGTERM, SIG_IGN)
  let sigterm = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
  sigterm.setEventHandler {
    MainActor.assumeIsolated {
      log.notice("SIGTERM, releasing LED")
      controller.releaseLED()
      exit(0)
    }
  }
  sigterm.resume()

  controller.start()

  // The power notification source lives on the main run loop, so run it rather than dispatchMain().
  while true {
    withExtendedLifetime((listener, delegate, sigterm)) {
      _ = RunLoop.main.run(mode: .default, before: .distantFuture)
    }
  }
}

func printStatus() -> Int32 {
  do {
    let smc = try SMC()
    return report(smc)
  } catch {
    print("zarge-helper: \(error)")
    return 1
  }
}

func report(_ smc: borrowing SMC) -> Int32 {
  var failed = false
  func line<T>(_ label: String, _ result: Result<T, SMCError>, format: (T) -> String = { "\($0)" }) {
    switch result {
    case .success(let value): print("\(label) \(format(value))")
    case .failure(let error):
      failed = true
      print("\(label) error: \(error)")
    }
  }
  line("battery:   ", Result { () throws(SMCError) in try smc.batteryPercent() }, format: { "\($0)%" })
  line("plugged-in:", Result { () throws(SMCError) in try smc.isOnACPower() })
  line("led:       ", Result { () throws(SMCError) in try smc.magSafeLED() })
  print("charging:   \(isBatteryCharging().map(String.init(describing:)) ?? "unknown")")
  print("settings:   threshold \(SettingsStore().load().threshold)%")
  return failed ? 1 : 0
}

switch CommandLine.arguments.dropFirst().first {
case "run":
  runDaemon()
case "status":
  exit(printStatus())
case "-h", "--help", "help":
  usage()
default:
  usage()
  exit(2)
}
