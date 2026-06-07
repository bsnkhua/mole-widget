import Foundation
import Observation

/// Central snapshot store. Polls collectors on timers at different frequencies
/// and publishes the results for SwiftUI.
@MainActor
@Observable
public final class MetricsStore {
    public private(set) var cpu: CPUSnapshot?
    public private(set) var memory: MemorySnapshot?
    public private(set) var diskUsage: DiskUsageSnapshot?
    public private(set) var diskIO: DiskIORates?
    public private(set) var power: PowerSnapshot?
    public private(set) var netRates: NetIORates?
    public private(set) var networkInfo: NetworkInfo?
    public private(set) var topProcesses: [ProcessUsage] = []
    public private(set) var systemInfo: SystemInfoSnapshot?
    public private(set) var healthScore: Int = 100
    public private(set) var cpuHistory = History()
    public private(set) var netInHistory = History()
    public private(set) var netOutHistory = History()
    /// Newer release tag (e.g. "v0.4.0") when GitHub has one; nil otherwise.
    public private(set) var availableUpdate: String?

    @ObservationIgnored private let cpuCollector = CPUCollector()
    @ObservationIgnored private let memoryCollector = MemoryCollector()
    @ObservationIgnored private let diskCollector = DiskCollector()
    @ObservationIgnored private let powerCollector = PowerCollector()
    @ObservationIgnored private let networkCollector = NetworkCollector()
    @ObservationIgnored private let processCollector = ProcessCollector()
    @ObservationIgnored private let systemInfoCollector = SystemInfoCollector()

    @ObservationIgnored private let updateChecker = UpdateChecker()

    @ObservationIgnored private var isSuspended = false
    @ObservationIgnored private var previousCPU: CPUSample?
    @ObservationIgnored private var previousIO: (counters: DiskIOCounters, at: Date)?
    @ObservationIgnored private var previousNetIO: (counters: NetIOCounters, at: Date)?
    @ObservationIgnored private var previousProcs: (samples: [ProcSample], at: Date)?
    @ObservationIgnored private var lastUpdateCheck: Date?
    @ObservationIgnored private var timers: [Timer] = []

    public init() {}

    deinit {
        timers.forEach { $0.invalidate() }
    }

    public func start() {
        stop() // a repeated start() must not leave stale timers in the RunLoop
        refreshFast()
        refreshDiskUsage()
        refreshPower()
        networkInfo = networkCollector.info()
        systemInfo = systemInfoCollector.sample()
        // Read the fast-timer interval from user defaults; floor at 1 s.
        let interval = max(
            1.0,
            UserDefaults.standard.object(forKey: WidgetSettings.refreshIntervalKey) as? Double
                ?? WidgetSettings.defaultRefreshInterval
        )
        timers = [
            Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refreshFast() }
            },
            Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refreshDiskUsage() }
            },
            Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refreshPower() }
            },
            Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.checkForUpdates() }
            },
        ]
        checkForUpdates()
    }

    /// Asks GitHub for the latest release tag at most once per 6 hours
    /// (start() may run repeatedly, e.g. on refresh-rate changes).
    private func checkForUpdates() {
        if let last = lastUpdateCheck, Date().timeIntervalSince(last) < 6 * 3600 { return }
        lastUpdateCheck = Date()
        Task { [weak self] in
            guard let self else { return }
            guard let tag = await self.updateChecker.latestReleaseTag() else { return }
            if VersionCompare.isNewer(tag, than: CoreInfo.version) {
                self.availableUpdate = tag
            }
        }
    }

    public func stop() {
        timers.forEach { $0.invalidate() }
        timers = []
    }

    /// Pause fast polling while the widget is fully occluded by other windows.
    public func suspend() {
        isSuspended = true
    }

    /// Resume fast polling when the widget becomes visible again.
    /// Immediately refreshes so data is current on first paint.
    public func resume() {
        guard isSuspended else { return }
        isSuspended = false
        refreshFast()
    }

    /// CPU + Memory + Disk I/O — every 2 seconds.
    public func refreshFast() {
        guard !isSuspended else { return }
        if let ticks = cpuCollector.sampleTicks() {
            if let prev = previousCPU {
                cpu = CPUUsage.snapshot(
                    previous: prev,
                    current: ticks,
                    loadAverage: cpuCollector.loadAverage()
                )
                if let snapshot = cpu {
                    cpuHistory.push(snapshot.totalUsage)
                }
            }
            previousCPU = ticks
        }
        if let mem = memoryCollector.sample() {
            memory = mem
        }
        if let counters = diskCollector.ioCounters() {
            let now = Date()
            if let prev = previousIO {
                diskIO = DiskIO.rates(
                    previous: prev.counters,
                    current: counters,
                    interval: now.timeIntervalSince(prev.at)
                )
            }
            previousIO = (counters, now)
        } else {
            previousIO = nil // IOKit failure → next sample pair starts fresh
        }
        if let counters = networkCollector.ioCounters() {
            let now = Date()
            if let prev = previousNetIO {
                let rates = NetIO.rates(
                    previous: prev.counters,
                    current: counters,
                    interval: now.timeIntervalSince(prev.at)
                )
                netRates = rates
                netInHistory.push(rates.download)
                netOutHistory.push(rates.upload)
            }
            previousNetIO = (counters, now)
        } else {
            previousNetIO = nil // getifaddrs failure → next sample pair starts fresh
        }
        let procSamples = processCollector.sample()
        if !procSamples.isEmpty {
            let now = Date()
            if let prev = previousProcs {
                topProcesses = ProcessMath.top(
                    previous: prev.samples,
                    current: procSamples,
                    interval: now.timeIntervalSince(prev.at)
                )
            }
            previousProcs = (procSamples, now)
        } else {
            previousProcs = nil // collection failure → next sample pair starts fresh
        }

        healthScore = HealthScore.compute(
            cpu: cpu?.totalUsage,
            memUsedFraction: memory?.usedFraction,
            diskUsedFraction: diskUsage?.usedFraction,
            batteryHealth: power?.healthFraction,
            batteryLevel: power?.levelFraction,
            isCharging: power?.isCharging ?? false
        )
    }

    /// Disk usage — every 60 seconds (changes slowly).
    public func refreshDiskUsage() {
        if let usage = diskCollector.usage() {
            diskUsage = usage
        }
    }

    /// Battery + network interface info + system info — every 30 seconds.
    public func refreshPower() {
        power = powerCollector.sample()
        networkInfo = networkCollector.info()
        systemInfo = systemInfoCollector.sample()
    }
}
