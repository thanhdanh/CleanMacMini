import Foundation
import IOKit

/// Reads a representative CPU/device temperature directly from AppleSMC.
/// Sensor availability varies by Mac model, so callers must handle `nil`.
final class TemperatureSampler: @unchecked Sendable {
    private var connection: io_connect_t = 0
    private var activeSensorKeys: [String]?

    private let sensorKeys = [
        // Intel CPU proximity / package / die sensors.
        "TC0P", "TC0D", "TC0E", "TC0F", "TC0H", "TC0C"
    ] + (1...16).map { String(format: "Tp%02d", $0) }

    deinit {
        if connection != 0 {
            IOServiceClose(connection)
        }
    }

    func sample() -> Double? {
        guard openIfNeeded() else { return nil }
        let candidates = activeSensorKeys ?? sensorKeys
        let readings = candidates.compactMap { key -> (String, Double)? in
            guard let value = readTemperature(key), value > 0, value < 130 else { return nil }
            return (key, value)
        }
        if activeSensorKeys == nil, !readings.isEmpty {
            activeSensorKeys = readings.map(\.0)
        }
        return readings.map(\.1).max()
    }

    private func openIfNeeded() -> Bool {
        if connection != 0 { return true }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        return IOServiceOpen(service, mach_task_self_, 0, &connection) == KERN_SUCCESS
    }

    private func readTemperature(_ key: String) -> Double? {
        var input = SMCParamStruct()
        var output = SMCParamStruct()
        input.key = fourCharacterCode(key)
        input.data8 = SMCCommand.readKeyInfo.rawValue
        guard call(&input, output: &output) else { return nil }

        let dataSize = output.keyInfo.dataSize
        let dataType = output.keyInfo.dataType
        guard dataSize > 0, dataSize <= 32 else { return nil }
        input.keyInfo.dataSize = dataSize
        input.data8 = SMCCommand.readBytes.rawValue
        guard call(&input, output: &output) else { return nil }

        let bytes = withUnsafeBytes(of: output.bytes) { Array($0) }
        switch dataType {
        case fourCharacterCode("sp78"):
            guard bytes.count >= 2 else { return nil }
            let raw = Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
            return Double(raw) / 256
        case fourCharacterCode("flt "):
            guard bytes.count >= 4 else { return nil }
            let raw = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
            return Double(Float(bitPattern: raw))
        case fourCharacterCode("fpe2"):
            guard bytes.count >= 2 else { return nil }
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4
        default:
            return nil
        }
    }

    private func call(_ input: inout SMCParamStruct, output: inout SMCParamStruct) -> Bool {
        let inputSize = MemoryLayout<SMCParamStruct>.stride
        var outputSize = MemoryLayout<SMCParamStruct>.stride
        let result = withUnsafePointer(to: &input) { inputPointer in
            withUnsafeMutablePointer(to: &output) { outputPointer in
                IOConnectCallStructMethod(
                    connection,
                    2,
                    inputPointer,
                    inputSize,
                    outputPointer,
                    &outputSize
                )
            }
        }
        return result == KERN_SUCCESS
    }

    private func fourCharacterCode(_ string: String) -> UInt32 {
        let bytes = Array(string.utf8)
        precondition(bytes.count == 4)
        return bytes.reduce(0) { ($0 << 8) | UInt32($1) }
    }
}

private enum SMCCommand: UInt8 {
    case readBytes = 5
    case readKeyInfo = 9
}

private struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

private struct SMCPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

private struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
    var padding: (UInt8, UInt8, UInt8) = (0, 0, 0)
}

private struct SMCParamStruct {
    var key: UInt32 = 0
    var version = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    ) = (
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0
    )
}
