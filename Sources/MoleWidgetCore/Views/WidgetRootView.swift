import AppKit
import SwiftUI

// MARK: - Section identity

/// Ordered list of section slots. The order is fixed; visibility flags select which
/// slots appear in the grid. Using an enum makes ForEach ids stable and unique.
enum WidgetSection: Int, CaseIterable, Identifiable {
    case cpu, memory, disk, power, network, processes
    var id: Int { rawValue }
}

// MARK: - Size presets

/// One-tap presets that set the visible section mix.
/// nil activePreset means the user has a custom selection that matches none of the three.
private enum SizePreset: CaseIterable {
    case small, medium, large

    var sections: Set<WidgetSection> {
        switch self {
        case .small:  return [.cpu, .memory]
        case .medium: return [.cpu, .memory, .disk, .power]
        case .large:  return Set(WidgetSection.allCases)
        }
    }

    var label: String {
        switch self { case .small: "S"; case .medium: "M"; case .large: "L" }
    }

    var helpText: String {
        switch self {
        case .small:  return "Small — CPU & Memory"
        case .medium: return "Medium — CPU, Memory, Disk & Power"
        case .large:  return "Large — all sections"
        }
    }
}

// MARK: - WidgetRootView

/// Root widget view: an always-visible title bar (app glyph + name on the
/// left, update/lock controls on the right), a dynamic grid of sections on
/// a dark backdrop, and an invisible resize handle along the right edge
/// (drag to adjust width).
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

    /// nil when the current section mix doesn't match any preset.
    private var activePreset: SizePreset? {
        let current = Set(WidgetSection.allCases.filter { section in
            switch section {
            case .cpu:       return showCPU
            case .memory:    return showMemory
            case .disk:      return showDisk
            case .power:     return showPower
            case .network:   return showNetwork
            case .processes: return showProcesses
            }
        })
        return SizePreset.allCases.first { $0.sections == current }
    }

    private func applyPreset(_ preset: SizePreset) {
        showCPU       = preset.sections.contains(.cpu)
        showMemory    = preset.sections.contains(.memory)
        showDisk      = preset.sections.contains(.disk)
        showPower     = preset.sections.contains(.power)
        showNetwork   = preset.sections.contains(.network)
        showProcesses = preset.sections.contains(.processes)
    }

    public init(store: MetricsStore) {
        self.store = store
    }

    public var body: some View {
        let allHidden = !showHeader && enabledSections.isEmpty

        VStack(alignment: .leading, spacing: 12) {
            titleBar
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
        .modifier(WidgetBackground(opacity: backgroundOpacity))
        .overlay(alignment: .trailing) {
            resizeHandle
        }
    }

    // MARK: - Title bar

    /// Always-visible first row: app glyph + name on the left,
    /// size and lock controls on the right, Ko-fi badge centered behind them.
    /// Permanent home of the lock — visible even when all sections are hidden.
    private var titleBar: some View {
        ZStack {
            KofiButton()
            HStack(spacing: 6) {
                TitleGlyphView()
                Text("Mole Widget")
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.header)
                Spacer()
                HStack(spacing: 2) {
                    sizeButtons
                    lockButton
                }
            }
        }
    }

    // MARK: - Section factory

    @ViewBuilder
    private func sectionView(for section: WidgetSection) -> some View {
        switch section {
        case .cpu:
            CPUSectionView(snapshot: store.cpu, history: store.cpuHistory.values).equatable()
        case .memory:
            MemorySectionView(snapshot: store.memory).equatable()
        case .disk:
            DiskSectionView(usage: store.diskUsage, io: store.diskIO).equatable()
        case .power:
            PowerSectionView(snapshot: store.power).equatable()
        case .network:
            NetworkSectionView(
                rates: store.netRates,
                info: store.networkInfo,
                downloadHistory: store.netInHistory.values,
                uploadHistory: store.netOutHistory.values
            ).equatable()
        case .processes:
            ProcessesSectionView(processes: store.topProcesses).equatable()
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

    // MARK: - Size preset buttons

    private var sizeButtons: some View {
        HStack(spacing: 0) {
            ForEach(SizePreset.allCases, id: \.label) { preset in
                Button { applyPreset(preset) } label: {
                    Text(preset.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(activePreset == preset ? Theme.header : Theme.dim)
                        .frame(width: 16, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(preset.helpText)
            }
        }
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

// MARK: - Ko-fi

/// Small "Ko-fi | Support" capsule that opens the donation page.
/// Centered behind the title row, mirroring the sibling vuvuzela widget.
private struct KofiButton: View {
    @State private var hovering = false

    private let kofiRed = Color(red: 1.0, green: 0.369, blue: 0.357)   // #FF5E5B
    private let kofiBg  = Color(red: 0.10, green: 0.10, blue: 0.10)    // near-black

    var body: some View {
        Button {
            NSWorkspace.shared.open(URL(string: "https://ko-fi.com/bsnkhua")!)
        } label: {
            HStack(spacing: 0) {
                HStack(spacing: 4) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 9, weight: .medium))
                    Text("Ko-fi")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(kofiBg)

                Text("Support")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(kofiRed)
            }
            .clipShape(Capsule())
            .opacity(hovering ? 0.80 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Support on Ko-fi ☕")
    }
}

// MARK: - Background

/// NSVisualEffectView wrapper — gives the same frosted-glass material native desktop
/// widgets use (.hudWindow + behindWindow blending). Stays active regardless of
/// window focus since the widget never becomes key.
private struct FrostView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .sidebar
        v.blendingMode = .behindWindow
        v.state = .active
        v.appearance = NSAppearance(named: .darkAqua)
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// On macOS 26+ uses NSVisualEffectView (.hudWindow) to match native Tahoe widget
/// appearance; falls back to the opaque dark panel on earlier systems.
private struct WidgetBackground: ViewModifier {
    let opacity: Double

    func body(content: Content) -> some View {
        #if swift(>=6.3)
        if #available(macOS 26, *) {
            content
                .background(Color.black.opacity(0.30), in: RoundedRectangle(cornerRadius: 12))
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        } else {
            content
                .background(
                    Theme.background.opacity(WidgetSettings.clampOpacity(opacity)),
                    in: RoundedRectangle(cornerRadius: 12)
                )
        }
        #else
        content
            .background(
                Theme.background.opacity(WidgetSettings.clampOpacity(opacity)),
                in: RoundedRectangle(cornerRadius: 12)
            )
        #endif
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
