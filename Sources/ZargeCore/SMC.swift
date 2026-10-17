import CSMC
import IOKit

package enum SMCError: Error, Equatable, CustomStringConvertible {
  case serviceNotFound
  case openFailed(kern_return_t)
  case callFailed(kern_return_t)
  case keyNotFound(SMCKey)
  case smcResult(SMCKey, UInt8)
  case unexpectedSize(SMCKey, expected: Int, actual: Int)

  package var description: String {
    switch self {
    case .serviceNotFound: "AppleSMC service not found"
    case .openFailed(let kr): "could not open AppleSMC (kern_return \(kr))"
    case .callFailed(let kr): "AppleSMC call failed (kern_return \(kr))"
    case .keyNotFound(let key): "SMC key \(key) not present on this hardware"
    case .smcResult(let key, let code): "SMC key \(key) returned result 0x\(String(code, radix: 16))"
    case .unexpectedSize(let key, let expected, let actual):
      "SMC key \(key) has \(actual) bytes, expected \(expected)"
    }
  }
}

/// A four-character SMC key such as `ACLC`.
package struct SMCKey: Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
  package let code: UInt32

  package init(_ name: String) {
    let bytes = Array(name.utf8)
    precondition(bytes.count == 4, "SMC keys are four ASCII characters: \(name)")
    code = bytes.reduce(0) { $0 << 8 | UInt32($1) }
  }

  package init(stringLiteral value: String) { self.init(value) }

  package var description: String {
    String(decoding: [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: code >> $0) }, as: UTF8.self)
  }
}

/// An open connection to the AppleSMC driver. Reading works as any user; writing needs root.
package struct SMC: ~Copyable {
  private enum Selector {
    static let handleYPCEvent: UInt32 = 2
  }

  private enum Command {
    static let readBytes: UInt8 = 5
    static let writeBytes: UInt8 = 6
    static let readKeyInfo: UInt8 = 9
  }

  private static let keyNotFoundResult: UInt8 = 0x84
  private static let maxValueSize = 32

  private let connection: io_connect_t

  package init() throws(SMCError) {
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
    guard service != IO_OBJECT_NULL else { throw .serviceNotFound }
    defer { IOObjectRelease(service) }

    var connection: io_connect_t = IO_OBJECT_NULL
    let result = IOServiceOpen(service, csmc_task_self(), 0, &connection)
    guard result == kIOReturnSuccess else { throw .openFailed(result) }
    self.connection = connection
  }

  deinit {
    IOServiceClose(connection)
  }

  package func read(_ key: SMCKey) throws(SMCError) -> [UInt8] {
    let info = try keyInfo(key)

    var input = SMCParamStruct()
    input.key = key.code
    input.keyInfo.dataSize = info.dataSize
    input.data8 = Command.readBytes
    let output = try call(input, key: key)

    let count = min(Int(info.dataSize), Self.maxValueSize)
    return withUnsafeBytes(of: output.bytes) { Array($0.prefix(count)) }
  }

  /// Writes `value`, which must be exactly the key's size.
  package func write(_ key: SMCKey, _ value: [UInt8]) throws(SMCError) {
    let info = try keyInfo(key)
    guard Int(info.dataSize) == value.count, value.count <= Self.maxValueSize else {
      throw .unexpectedSize(key, expected: Int(info.dataSize), actual: value.count)
    }

    var input = SMCParamStruct()
    input.key = key.code
    input.keyInfo.dataSize = info.dataSize
    input.data8 = Command.writeBytes
    withUnsafeMutableBytes(of: &input.bytes) { $0.copyBytes(from: value) }
    _ = try call(input, key: key)
  }

  private func keyInfo(_ key: SMCKey) throws(SMCError) -> SMCKeyInfo {
    var input = SMCParamStruct()
    input.key = key.code
    input.data8 = Command.readKeyInfo
    return try call(input, key: key).keyInfo
  }

  private func call(_ input: SMCParamStruct, key: SMCKey) throws(SMCError) -> SMCParamStruct {
    var input = input
    var output = SMCParamStruct()
    var outputSize = MemoryLayout<SMCParamStruct>.stride
    let result = IOConnectCallStructMethod(
      connection, Selector.handleYPCEvent,
      &input, MemoryLayout<SMCParamStruct>.stride,
      &output, &outputSize
    )
    guard result == kIOReturnSuccess else { throw .callFailed(result) }

    switch output.result {
    case 0: return output
    case Self.keyNotFoundResult: throw .keyNotFound(key)
    default: throw .smcResult(key, output.result)
    }
  }
}
