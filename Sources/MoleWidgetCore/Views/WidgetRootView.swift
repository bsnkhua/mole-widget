import AppKit
import SwiftUI

// MARK: - Section identity

/// Ordered list of section slots. The order is fixed; visibility flags select which
/// slots appear in the grid. Using an enum makes ForEach ids stable and unique.
enum WidgetSection: Int, CaseIterable, Identifiable {
    case cpu, memory, disk, power, network, processes
    var id: Int { rawValue }
}

// MARK: - WidgetRootView

/// Root widget view: a dynamic grid of sections on a dark backdrop,
/// a clickable lock icon in the top-right corner, and an invisible
/// resize handle along the right edge (drag to adjust width).
public struct WidgetRootView: View {
    let store: MetricsStore

    @AppStorage(WidgetSettings.positionLockedKey) private var positionLocked = false
    @AppStorage(WidgetSettings.widgetWidthKey) private var widgetWidth = WidgetSettings.defaultWidth

    // Appearance
    @AppStorage(WidgetSettings.backgroundOpacityKey)
    private var backgroundOpacity = WidgetSettings.defaultOpacity

    // Section visibility
    @AppStorage(WidgetSettings.showHeaderKey)    private var showHeader    = true
    @AppStorage(WidgetSettings.showCPUKey)       private var showCPU       = true
    @AppStorage(WidgetSettings.showMemoryKey)    private var showMemory    = true
    @AppStorage(WidgetSettings.showDiskKey)      private var showDisk      = true
    @AppStorage(WidgetSettings.showPowerKey)     private var showPower     = true
    @AppStorage(WidgetSettings.showNetworkKey)   private var showNetwork   = true
    @AppStorage(WidgetSettings.showProcessesKey) private var showProcesses = true

    @State private var dragStartWidth: Double?

    /// Two columns + inter-column spacing (24) + horizontal padding (2×16).
    private var columnWidth: CGFloat {
        (WidgetSettings.clampWidth(widgetWidth) - 24 - 32) / 2
    }

    /// Ordered list of enabled section slots.
    private var enabledSections: [WidgetSection] {
        WidgetSection.allCases.filter { section in
            switch section {
            case .cpu:       return showCPU
            case .memory:    return showMemory
            case .disk:      return showDisk
            case .power:     return showPower
            case .network:   return showNetwork
            case .processes: return showProcesses
            }
        }
    }

    public init(store: MetricsStore) {
        self.store = store
    }

    public var body: some View {
        let allHidden = !showHeader && enabledSections.isEmpty

        VStack(alignment: .leading, spacing: 12) {
            if allHidden {
                Text("All sections hidden")
                    .foregroundStyle(Theme.dim)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                if showHeader {
                    HeaderView(info: store.systemInfo, score: store.healthScore)
                }

                if !enabledSections.isEmpty {
                    Grid(alignment: .topLeading, horizontalSpacing: 24, verticalSpacing: 16) {
                        // Chunk the enabled sections into pairs; the odd tail sits alone.
                        // Row identity = leading section, so rows keep stable identity
                        // when other sections are toggled on/off.
                        let pairs = enabledSections.chunks(of: 2)
                        ForEach(pairs, id: \.[0].id) { pair in
                            GridRow {
                                // Leading cell (always present)
                                sectionView(for: pair[0])
                                    .frame(width: columnWidth, alignment: .topLeading)
                                // Trailing cell (present only in full pairs)
                                if pair.count > 1 {
                                    sectionView(for: pair[1])
                                        .frame(width: columnWidth, alignment: .topLeading)
                                } else {
                                    // Empty spacer to keep the grid geometry consistent
                                    Color.clear
                                        .frame(width: columnWidth)
                                }
                            }
                        }
                    }
                }
            }
        }
        .font(Theme.font)
        .padding(16)
        .background(
            Theme.background.opacity(WidgetSettings.clampOpacity(backgroundOpacity)),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(alignment: .trailing) {
            resizeHandle
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 2) {
                if let version = store.availableUpdate {
                    updateButton(version: version)
                }
                lockButton
            }
            .padding(6)
        }
    }

    // MARK: - Update button

    @State private var upgradeCommandCopied = false

    /// Full upgrade one-liner: refresh taps, upgrade, then restart the widget
    /// so the new version actually runs (brew leaves the old process alive).
    static let upgradeCommand =
        #"brew update && brew upgrade mole-widget && (pkill -f "Mole Widget.app"; sleep 1; mole-widget)"#

    /// Appears next to the lock only when GitHub has a newer release.
    /// Click copies the full upgrade command to the clipboard.
    private func updateButton(version: String) -> some View {
        Button {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(Self.upgradeCommand, forType: .string)
            upgradeCommandCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                upgradeCommandCopied = false
            }
        } label: {
            Image(systemName: upgradeCommandCopied ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(upgradeCommandCopied ? Theme.accent : Theme.warning)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(upgradeCommandCopied
            ? "Copied! Paste it into Terminal — it upgrades and restarts the widget"
            : "\(version) is available — click to copy the upgrade command")
    }

    // MARK: - Section factory

    @ViewBuilder
    private func sectionView(for section: WidgetSection) -> some View {
        switch section {
        case .cpu:
            CPUSectionView(snapshot: store.cpu, history: store.cpuHistory.values)
        case .memory:
            MemorySectionView(snapshot: store.memory)
        case .disk:
            DiskSectionView(usage: store.diskUsage, io: store.diskIO)
        case .power:
            PowerSectionView(snapshot: store.power)
        case .network:
            NetworkSectionView(
                rates: store.netRates,
                info: store.networkInfo,
                downloadHistory: store.netInHistory.values,
                uploadHistory: store.netOutHistory.values
            )
        case .processes:
            ProcessesSectionView(processes: store.topProcesses)
        }
    }

    // MARK: - Resize handle

    /// Invisible strip along the right edge; drag it to resize the widget.
    /// Disabled while the position is locked.
    private var resizeHandle: some View {
        Color.clear
            .frame(width: 10)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onHover { inside in
                guard !positionLocked else { return }
                if inside {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        guard !positionLocked else { return }
                        let start = dragStartWidth ?? widgetWidth
                        dragStartWidth = start
                        widgetWidth = WidgetSettings.clampWidth(start + value.translation.width)
                    }
                    .onEnded { _ in dragStartWidth = nil }
            )
    }

    // MARK: - Lock button

    private var lockButton: some View {
        Button {
            positionLocked.toggle()
        } label: {
            Image(systemName: positionLocked ? "lock.fill" : "lock.open")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(positionLocked ? Theme.warning : Theme.dim)
                .frame(width: 20, height: 20) // hit area slightly larger than the icon
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(positionLocked
            ? "Position and size are locked — click to unlock"
            : "Click to lock the widget position and size")
    }
}

// MARK: - Array chunking helper

private extension Array {
    /// Splits the array into sub-arrays of at most `size` elements.
    func chunks(of size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
