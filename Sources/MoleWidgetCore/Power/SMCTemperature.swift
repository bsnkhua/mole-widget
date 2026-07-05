import Foundation
import IOKit

/// Reads the SoC (CPU) temperature from AppleSMC.
///
/// Apple Silicon exposes per-core die temperatures under FourCC keys in the
/// `Tp…` family (`Tg…` is GPU, `Tm…` is memory). The specific sub-codes differ
/// every generation (M1 `Tp01/Tp05…`, M5 `Tp0X/Tp0O…`), so instead of a
/// hardcoded per-generation table this scans the SMC key list once, keeps every
/// `Tp…` sensor that reports a plausible temperature, and averages them. Absent
/// families (Intel Macs, sandboxed processes) simply yield `nil`.
///
/// No root or entitlement is required — a read-only `AppleSMC` connection is
/// enough. Being a private API, it rules out App Store sandboxing, which does
/// not apply to this directly-distributed app.
public final class SMCTemperature {
    private var connection: io_connect_t = 0
    private var cpuKeys: [UInt32]?  // cached after the first scan

    public init() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return }
        IOServiceOpen(service, mach_task_self_, 0, &connection)
        IOObjectRelease(service)
    }

    deinit {
        if connection != 0 { IOServiceClose(connection) }
    }

    /// Average of all `Tp…` core sensors, in °C, or `nil` when unavailable.
    public func cpuTemperature() -> Double? {
        guard connection != 0 else { return nil }

        let keys = cpuKeys ?? discoverCPUKeys()
        cpuKeys = keys
        guard !keys.isEmpty else { return nil }

        var sum = 0.0
        var count = 0
        for key in keys {
            if let value = readFloat(key), value > 0, value < 130 {
                sum += Double(value)
                count += 1
            }
        }
        return count > 0 ? sum / Double(count) : nil
    }

    /// One-time scan of the whole key list, collecting `Tp…` float sensors that
    /// currently read a plausible temperature.
    private func discoverCPUKeys() -> [UInt32] {
        var result: [UInt32] = []
        for index in 0..<keyCount() {
            let key = key(atIndex: index)
            let name = Self.fourCCString(key)
            guard name.hasPrefix("Tp") else { continue }
            if let value = readFloat(key), value > 0, value < 130 {
                result.append(key)
            }
        }
        return result
    }

    // MARK: - SMC protocol

    private func call(_ input: inout SMCParamStruct, _ output: inout SMCParamStruct) -> kern_return_t {
        let size = MemoryLayout<SMCParamStruct>.stride
        var outSize = size
        return IOConnectCallStructMethod(connection, KERNEL_INDEX_SMC, &input, size, &output, &outSize)
    }

    private func keyCount() -> UInt32 {
        var input = SMCParamStruct()
        var info = SMCParamStruct()
        input.key = Self.fourCC("#KEY")
        input.data8 = CMD_READ_KEYINFO
        guard call(&input, &info) == kIOReturnSuccess else { return 0 }
        input.keyInfo.dataSize = info.keyInfo.dataSize
        input.data8 = CMD_READ_BYTES
        var output = SMCParamStruct()
        guard call(&input, &output) == kIOReturnSuccess else { return 0 }
        let b = output.bytes
        return (UInt32(b.0) << 24) | (UInt32(b.1) << 16) | (UInt32(b.2) << 8) | UInt32(b.3)
    }

    private func key(atIndex index: UInt32) -> UInt32 {
        var input = SMCParamStruct()
        var output = SMCParamStruct()
        input.data8 = CMD_READ_INDEX
        input.data32 = index
        guard call(&input, &output) == kIOReturnSuccess else { return 0 }
        return output.key
    }

    /// Reads a key whose type is `flt ` (little-endian Float32); nil otherwise.
    private func readFloat(_ key: UInt32) -> Float? {
        var input = SMCParamStruct()
        var info = SMCParamStruct()
        input.key = key
        input.data8 = CMD_READ_KEYINFO
        guard call(&input, &info) == kIOReturnSuccess else { return nil }
        guard info.keyInfo.dataType == Self.fourCC("flt "), info.keyInfo.dataSize == 4 else { return nil }
        input.keyInfo = info.keyInfo
        input.data8 = CMD_READ_BYTES
        var output = SMCParamStruct()
        guard call(&input, &output) == kIOReturnSuccess else { return nil }
        let b = output.bytes
        return [b.0, b.1, b.2, b.3].withUnsafeBytes { $0.load(as: Float.self) }
    }

    // MARK: - FourCC helpers

    static func fourCC(_ s: String) -> UInt32 {
        var result: UInt32 = 0
        for byte in s.utf8 { result = (result << 8) + UInt32(byte) }
        return result
    }

    static func fourCCString(_ value: UInt32) -> String {
        let bytes = [UInt8((value >> 24) & 0xff), UInt8((value >> 16) & 0xff),
                     UInt8((value >> 8) & 0xff), UInt8(value & 0xff)]
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }
}

// MARK: - Raw SMC structs (must match the AppleSMC kernel struct layout, 80 bytes)

private let KERNEL_INDEX_SMC: UInt32 = 2
private let CMD_READ_BYTES: UInt8 = 5
private let CMD_READ_KEYINFO: UInt8 = 9
private let CMD_READ_INDEX: UInt8 = 8

private typealias SMCBytes = (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
)

private struct SMCVersion {
    var major: UInt8 = 0, minor: UInt8 = 0, build: UInt8 = 0, reserved: UInt8 = 0
    var release: UInt16 = 0
}

private struct SMCPLimitData {
    var version: UInt16 = 0, length: UInt16 = 0
    var cpuPLimit: UInt32 = 0, gpuPLimit: UInt32 = 0, memPLimit: UInt32 = 0
}

/// `dataAttributes` is followed by 3 explicit pad bytes so this matches the C
/// struct's 12-byte size; without them Swift packs it to 9 and the enclosing
/// struct drops to 76 bytes, which the kernel rejects with kIOReturnBadArgument.
private struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
    var pad0: UInt8 = 0, pad1: UInt8 = 0, pad2: UInt8 = 0
}

private struct SMCParamStruct {
    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
}
