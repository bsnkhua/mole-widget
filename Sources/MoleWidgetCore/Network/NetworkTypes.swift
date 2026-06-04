import Foundation

/// Cumulative I/O byte counters since system boot (sum across all non-loopback interfaces).
public struct NetIOCounters: Equatable {
    public let bytesIn: UInt64
    public let bytesOut: UInt64

    public init(bytesIn: UInt64, bytesOut: UInt64) {
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
    }
}

/// Current download/upload rates in bytes per second.
public struct NetIORates: Equatable {
    public let download: Double
    public let upload: Double

    public init(download: Double, upload: Double) {
        self.download = download
        self.upload = upload
    }
}

/// Primary network interface name and its IPv4 address.
public struct NetworkInfo: Equatable {
    public let interfaceName: String
    public let localIP: String?

    public init(interfaceName: String, localIP: String?) {
        self.interfaceName = interfaceName
        self.localIP = localIP
    }
}
