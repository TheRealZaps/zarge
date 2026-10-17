import CSMC
import Foundation
import Testing
@testable import ZargeCore

@Test func `SMCParamStruct matches the 80-byte AppleSMC layout`() {
  #expect(MemoryLayout<SMCParamStruct>.size == 80)
  #expect(MemoryLayout<SMCParamStruct>.offset(of: \.keyInfo) == 28)
  #expect(MemoryLayout<SMCParamStruct>.offset(of: \.data32) == 44)
  #expect(MemoryLayout<SMCParamStruct>.offset(of: \.bytes) == 48)
}

@Test func `SMC keys encode as big-endian four-character codes`() {
  #expect(SMCKey("ACLC").code == 0x4143_4C43)
  #expect(SMCKey("AC-W").description == "AC-W")
}

@Test(arguments: [
  // desired, last written, read-back, expected write
  (MagSafeLED.green, MagSafeLED?.none, MagSafeLED?.none, MagSafeLED?.some(.green)),
  (.system, nil, .orange, .system),
  (.system, .system, .orange, nil),
  (.system, .system, .green, nil),
  (.green, .green, .green, nil),
  (.green, .green, .orange, .green),
  (.green, .green, .system, .green),
  (.green, .green, nil, .green),
  (.system, .green, .green, .system),
  (.green, .system, .green, .green),
])
func `writes on a change of target, and re-asserts green the firmware dropped`(
  desired: MagSafeLED, lastWritten: MagSafeLED?, readBack: MagSafeLED?, expected: MagSafeLED?
) {
  #expect(ledToWrite(desired: desired, lastWritten: lastWritten, readBack: readBack) == expected)
}

@Test(arguments: [
  // on AC, battery, threshold, charging, expected LED
  (false, 50, 90, true, MagSafeLED?.none),
  (false, 95, 90, false, nil),
  (true, 50, 90, true, .orange),
  (true, 80, 90, false, .green),
  (true, 90, 90, true, .green),
  (true, 95, 90, true, .green),
  (true, 95, 90, false, .green),
])
func `derives the LED color from power state`(
  onAC: Bool, battery: Int, threshold: Int, charging: Bool, expected: MagSafeLED?
) {
  #expect(displayedLED(onACPower: onAC, batteryPercent: battery, threshold: threshold, isCharging: charging) == expected)
}

@Test(arguments: [
  (UInt8(0x00), MagSafeLED.system),
  (0x02, .green),
  (0x03, .green),
  (0x04, .orange),
  (0x19, .errorPermOff),
  (0x42, .orange),
])
func `decodes raw ACLC bytes`(raw: UInt8, expected: MagSafeLED) {
  #expect(MagSafeLED(smcValue: raw) == expected)
}

@Test func `status survives the XPC JSON round trip`() throws {
  let status = HelperStatus(batteryPercent: 92, onACPower: true, led: .orange, isCharging: true, threshold: 90)
  #expect(try HelperStatus(decoding: status.encoded()) == status)
  #expect(status.isEngaged)
  #expect(status.displayedLED == .green)
}

@Test func `status from a helper without isCharging still decodes`() throws {
  let json = #"{"batteryPercent":60,"onACPower":true,"led":4,"threshold":90}"#
  let status = try HelperStatus(decoding: Data(json.utf8))
  #expect(status.isCharging == nil)
  #expect(status.displayedLED == nil)
}

@Test(arguments: [
  // battery, on AC, charging, expected dot
  (Int?.some(95), Bool?.some(true), Bool?.none, MagSafeLED?.some(.green)),
  (60, true, true, .orange),
  (60, true, false, .green),
  (60, false, true, nil),
  (60, true, nil, nil),
  (nil, true, true, nil),
])
func `status dot follows the threshold, not the read-back`(
  battery: Int?, onAC: Bool?, charging: Bool?, expected: MagSafeLED?
) {
  // The read-back says orange in every case; the dot must ignore it.
  let status = HelperStatus(batteryPercent: battery, onACPower: onAC, led: .orange, isCharging: charging, threshold: 90)
  #expect(status.displayedLED == expected)
}

@Test func `status with failed reads is never engaged`() {
  let status = HelperStatus(batteryPercent: nil, onACPower: true, led: nil, threshold: 90, error: "boom")
  #expect(!status.isEngaged)
}

@Test func `settings round-trip through the store`() throws {
  let store = SettingsStore(url: temporarySettingsURL())
  #expect(store.load() == Settings())
  try store.save(Settings(threshold: 75))
  #expect(store.load() == Settings(threshold: 75))
}

@Test(arguments: [
  #"{"threshold":0}"#,
  #"{"threshold":101}"#,
  #"{"threshold":"ninety"}"#,
  "not json",
])
func `unreadable or out-of-range settings load as the default`(contents: String) throws {
  let url = temporarySettingsURL()
  try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
  try Data(contents.utf8).write(to: url)
  #expect(SettingsStore(url: url).load().threshold == Threshold.default)
}

private func temporarySettingsURL() -> URL {
  FileManager.default.temporaryDirectory
    .appending(path: "zarge-tests-\(UUID().uuidString)")
    .appending(path: "settings.json")
}
