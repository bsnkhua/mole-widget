import Darwin

/// Collects per-process CPU time and memory via the libproc API.
public struct ProcessCollector {

    // Mach timebase for converting mach ticks to nanoseconds.
    // Initialised once at construction (immutable on a running system).
    private let timebaseNumer: UInt64
    private let timebaseDenom: UInt64

    public init() {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        timebaseNumer = UInt64(info.numer)
        timebaseDenom = UInt64(info.denom)
    }

    /// Returns a snapshot of all accessible processes.
    /// Processes owned by other users that return EPERM are silently skipped.
    public func sample() -> [ProcSample] {
        // Phase 1: determine the required buffer size.
        let capacity = proc_listallpids(nil, 0)
        guard capacity > 0 else { return [] }

        // Phase 2: fill the pid buffer (over-allocate slightly in case new pids appear).
        var pids = [pid_t](repeating: 0, count: Int(capacity) + 16)
        let filled = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.stride))
        guard filled > 0 else { return [] }

        var results: [ProcSample] = []
        results.reserveCapacity(Int(filled))

        // 64-byte buffer for process names (MAXCOMLEN is 16, but proc_name pads to MAXPATHLEN).
        var nameBuf = [CChar](repeating: 0, count: 64)

        for i in 0..<Int(filled) {
            let pid = pids[i]
            guard pid > 0 else { continue } // skip pid 0 (kernel)

            // Fetch rusage_info_v2 for CPU time and memory footprint.
            var info = rusage_info_v2()
            let ret = withUnsafeMutablePointer(to: &info) { ptr in
                ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { reboundPtr in
                    // proc_pid_rusage takes an UnsafeMutablePointer<rusage_info_t?> (nullable pointer).
                    proc_pid_rusage(pid, RUSAGE_INFO_V2, reboundPtr)
                }
            }
            guard ret == 0 else { continue } // EPERM for other users, etc.

            // Fetch process name.
            nameBuf.withUnsafeMutableBufferPointer { buf in
                _ = proc_name(pid, buf.baseAddress, UInt32(buf.count))
            }
            let name = String(cString: nameBuf)
            guard !name.isEmpty else { continue }

            // ri_user_time + ri_system_time are in mach absolute time units.
            // Convert to nanoseconds: ns = ticks * numer / denom.
            let machTicks = info.ri_user_time &+ info.ri_system_time
            let cpuNs = machTicks &* timebaseNumer / timebaseDenom

            results.append(ProcSample(
                pid: pid,
                name: name,
                cpuTimeNs: cpuNs,
                memoryBytes: info.ri_phys_footprint
            ))
        }

        return results
    }
}
