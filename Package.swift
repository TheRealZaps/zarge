// swift-tools-version: 6.2
import PackageDescription

let approachableConcurrency: [SwiftSetting] = [
  .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
  .enableUpcomingFeature("InferIsolatedConformances"),
]

let package = Package(
  name: "Zarge",
  platforms: [.macOS(.v26)],
  products: [
    .executable(name: "Zarge", targets: ["Zarge"]),
    .executable(name: "zarge-helper", targets: ["ZargeHelper"]),
  ],
  targets: [
    // The AppleSMC user-client struct, declared in C so Swift imports its exact layout.
    .target(name: "CSMC"),
    // Shared by the app and the helper. A library, so it stays nonisolated.
    .target(
      name: "ZargeCore",
      dependencies: ["CSMC"],
      swiftSettings: approachableConcurrency
    ),
    // Root launchd daemon: watches power events and writes the MagSafe LED.
    .executableTarget(
      name: "ZargeHelper",
      dependencies: ["ZargeCore"],
      swiftSettings: approachableConcurrency + [.defaultIsolation(MainActor.self)]
    ),
    // Menu bar app: installs the helper and sets the threshold over XPC.
    .executableTarget(
      name: "Zarge",
      dependencies: ["ZargeCore"],
      swiftSettings: approachableConcurrency + [.defaultIsolation(MainActor.self)]
    ),
    .testTarget(
      name: "ZargeCoreTests",
      dependencies: ["ZargeCore", "CSMC"],
      swiftSettings: approachableConcurrency
    ),
  ]
)
