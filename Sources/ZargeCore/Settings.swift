import Foundation

package struct Settings: Codable, Equatable {
  package var threshold = Threshold.default

  package init(threshold: Int = Threshold.default) {
    self.threshold = threshold
  }
}

/// Root-owned in production, so only the helper can change the threshold, and only after
/// the app asks it to. Anything missing, unreadable or out of range loads as the defaults.
package struct SettingsStore {
  package var url: URL

  package init(url: URL = URL(filePath: "/Library/Application Support/Zarge/settings.json")) {
    self.url = url
  }

  package func load() -> Settings {
    guard let data = try? Data(contentsOf: url),
          let settings = try? JSONDecoder().decode(Settings.self, from: data),
          Threshold.valid.contains(settings.threshold)
    else { return Settings() }
    return settings
  }

  package func save(_ settings: Settings) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONEncoder().encode(settings).write(to: url, options: .atomic)
  }
}
