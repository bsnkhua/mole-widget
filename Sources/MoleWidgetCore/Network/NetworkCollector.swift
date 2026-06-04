import Foundation
import SystemConfiguration
import Darwin

/// Collects live network I/O counters and primary interface info from the OS.
public final class NetworkCollector {
    public init() {}

    /// Returns cumulative byte counters summed across all non-loopback interfaces,
    /// or nil if `getifaddrs` fails.
    public func ioCounters() -> NetIOCounters? {
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let base = ifap else { return nil }
        defer { freeifaddrs(base) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0

        var cursor: UnsafeMutablePointer<ifaddrs>? = base
        while let ifa = cursor {
            defer { cursor = ifa.pointee.ifa_next }

            // Skip loopback interfaces.
            guard (ifa.pointee.ifa_flags & UInt32(IFF_LOOPBACK)) == 0 else { continue }

            // AF_LINK addresses carry the interface data struct (if_data) in ifa_data.
            guard ifa.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_LINK) else { continue }

            guard let dataPtr = ifa.pointee.ifa_data else { continue }
            let ifData = dataPtr.assumingMemoryBound(to: if_data.self).pointee
            totalIn  += UInt64(ifData.ifi_ibytes)
            totalOut += UInt64(ifData.ifi_obytes)
        }

        return NetIOCounters(bytesIn: totalIn, bytesOut: totalOut)
    }

    /// Returns the primary network interface name and its IPv4 address,
    /// or nil when the machine is offline or the dynamic store is unavailable.
    public func info() -> NetworkInfo? {
        guard let store = SCDynamicStoreCreate(nil, "mole-widget" as CFString, nil, nil) else {
            return nil
        }

        guard
            let raw = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString),
            let dict = raw as? [String: Any],
            let iface = dict["PrimaryInterface"] as? String
        else {
            return nil
        }

        let ip = ipv4Address(for: iface)
        return NetworkInfo(interfaceName: iface, localIP: ip)
    }

    // MARK: - Private helpers

    /// Finds the IPv4 address of the named interface via a second getifaddrs pass.
    private func ipv4Address(for name: String) -> String? {
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let base = ifap else { return nil }
        defer { freeifaddrs(base) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = base
        while let ifa = cursor {
            defer { cursor = ifa.pointee.ifa_next }

            guard
                String(cString: ifa.pointee.ifa_name) == name,
                ifa.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_INET),
                let addrPtr = ifa.pointee.ifa_addr
            else { continue }

            var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            return addrPtr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { sinPtr in
                var addr = sinPtr.pointee.sin_addr
                guard let cstr = inet_ntop(AF_INET, &addr, &buf, socklen_t(INET_ADDRSTRLEN)) else {
                    return nil
                }
                return String(cString: cstr)
            }
        }
        return nil
    }
}
