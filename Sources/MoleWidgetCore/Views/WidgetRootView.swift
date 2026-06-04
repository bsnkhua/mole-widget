import AppKit
import SwiftUI

/// Root widget view: a 2×2 grid of sections on a dark backdrop,
/// a clickable lock icon in the top-right corner, and an invisible
/// resize handle along the right edge (drag to adjust width).
public struct WidgetRootView: View {
    let store: MetricsStore

    @AppStorage(WidgetSettings.positionLockedKey) private var positionLocked = false
    @AppStorage(WidgetSettings.widgetWidthKey) private var widgetWidth = WidgetSettings.defaultWidth

    @State private var dragStartWidth: Double?

    /// Two columns + inter-column spacing (24) + horizontal padding (2×16).
    private var columnWidth: CGFloat {
        (WidgetSettings.clampWidth(widgetWidth) - 24 - 32) / 2
    }

    public init(store: MetricsStore) {
        self.store = store
    }

    public var body: some View {
        Grid(alignment: .topLeading, horizontalSpacing: 24, verticalSpacing: 16) {
            GridRow {
                CPUSectionView(snapshot: store.cpu)
                    .frame(width: columnWidth, alignment: .topLeading)
                MemorySectionView(snapshot: store.memory)
                    .frame(width: columnWidth, alignment: .topLeading)
            }
            GridRow {
                DiskSectionView(usage: store.diskUsage, io: store.diskIO)
                    .frame(width: columnWidth, alignment: .topLeading)
                PowerSectionView(snapshot: store.power)
                    .frame(width: columnWidth, alignment: .topLeading)
            }
            GridRow {
                NetworkSectionView(rates: store.netRates, info: store.networkInfo)
                    .frame(width: columnWidth, alignment: .topLeading)
                Color.clear
                    .frame(width: columnWidth)
            }
        }
        .font(Theme.font)
        .padding(16)
        .background(
            Theme.background.opacity(0.92),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(alignment: .trailing) {
            resizeHandle
        }
        .overlay(alignment: .topTrailing) {
            lockButton
        }
    }

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
        .padding(6)
        .help(positionLocked
            ? "Position and size are locked — click to unlock"
            : "Click to lock the widget position and size")
    }
}
