/// Raw per-process sample (cumulative CPU time in nanoseconds).
public struct ProcSample: Equatable {
    public let pid: Int32
    public let name: String
    public let cpuTimeNs: UInt64
    public let memoryBytes: UInt64

    public init(pid: Int32, name: String, cpuTimeNs: UInt64, memoryBytes: UInt64) {
        self.pid = pid
        self.name = name
        self.cpuTimeNs = cpuTimeNs
        self.memoryBytes = memoryBytes
    }
}

/// Ready-to-display process row.
/// cpuFraction: 1.0 == one full core (like top).
public struct ProcessUsage: Equatable {
    public let pid: Int32 // stable identity for SwiftUI lists (names can repeat)
    public let name: String
    public let cpuFraction: Double
    public let memoryBytes: UInt64

    public init(pid: Int32, name: String, cpuFraction: Double, memoryBytes: UInt64) {
        self.pid = pid
        self.name = name
        self.cpuFraction = cpuFraction
        self.memoryBytes = memoryBytes
    }
}
