import Foundation

/// Pure math: download/upload rates computed from cumulative counter deltas.
public enum NetIO {
    public static func rates(
        previous: NetIOCounters,
        current: NetIOCounters,
        interval: TimeInterval
    ) -> NetIORates {
        guard interval > 0 else { return NetIORates(download: 0, upload: 0) }
        // Counter reset (interface reconnect, reboot) causes current < previous —
        // treat such a delta as zero, otherwise the unsigned subtraction yields ~18 EB/s.
        let deltaIn = current.bytesIn >= previous.bytesIn
            ? current.bytesIn - previous.bytesIn : 0
        let deltaOut = current.bytesOut >= previous.bytesOut
            ? current.bytesOut - previous.bytesOut : 0
        return NetIORates(
            download: Double(deltaIn) / interval,
            upload: Double(deltaOut) / interval
        )
    }
}
