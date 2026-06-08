import AppKit
import MoleWidgetCore
import ServiceManagement
import Sparkle
import SwiftUI

@main
struct MoleWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(WidgetSettings.positionLockedKey) private var positionLocked = false

    // Settings: opacity
    // NOTE: write only via the Picker binding — the tags are exact Double
    // literals; arithmetic writes would break Picker selection matching.
    @AppStorage(WidgetSettings.backgroundOpacityKey)
    private var backgroundOpacity = WidgetSettings.defaultOpacity

    // Settings: refresh rate
    @AppStorage(WidgetSettings.refreshIntervalKey)
    private var refreshInterval = WidgetSettings.defaultRefreshInterval

    // Settings: section visibility
    @AppStorage(WidgetSettings.showHeaderKey)    private var showHeader    = true
    @AppStorage(WidgetSettings.showCPUKey)       private var showCPU       = true
    @AppStorage(WidgetSettings.showMemoryKey)    private var showMemory    = true
    @AppStorage(WidgetSettings.showDiskKey)      private var showDisk      = true
    @AppStorage(WidgetSettings.showPowerKey)     private var showPower     = true
    @AppStorage(WidgetSettings.showNetworkKey)   private var showNetwork   = true
    @AppStorage(WidgetSettings.showProcessesKey) private var showProcesses = true

    /// Monochrome template glyph echoing the app icon: four bars of varying
    /// length. Template images get tinted by macOS for light/dark menu bars.
    private static let menuBarIcon: NSImage = {
        let size = NSSize(width: 18, height: 16)
        let image = NSImage(size: size, flipped: false) { _ in
            NSColor.black.setFill()
            let barHeight: CGFloat = 2.6
            let gap: CGFloat = 1.1
            // Bar lengths mirror the app icon proportions (560/360/470/220)
            let widths: [CGFloat] = [14, 9, 11.8, 5.5]
            var y: CGFloat = size.height - barHeight - 0.6
            for width in widths {
                let bar = NSRect(x: 2, y: y, width: width, height: barHeight)
                NSBezierPath(roundedRect: bar, xRadius: barHeight / 2, yRadius: barHeight / 2).fill()
                y -= barHeight + gap
            }
            return true
        }
        image.isTemplate = true
        return image
    }()

    var body: some Scene {
        MenuBarExtra {
            Button("Mole Widget v\(CoreInfo.version) — GitHub") {
                NSWorkspace.shared.open(UpdateChecker.repoPageURL)
            }
            Button("Report an Issue") {
                NSWorkspace.shared.open(UpdateChecker.issuesPageURL)
            }
            Button("Check for Updates…") {
                appDelegate.updaterController.updater.checkForUpdates()
            }
            .disabled(!appDelegate.updaterController.updater.canCheckForUpdates)
            Divider()
            Toggle("Lock position", isOn: $positionLocked)
            LaunchAtLoginToggle()
            Menu("Settings") {
                if #unavailable(macOS 26) {
                    Picker("Opacity", selection: $backgroundOpacity) {
                        Text("100%").tag(1.0)
                        Text("92%").tag(0.92)
                        Text("85%").tag(0.85)
                        Text("70%").tag(0.7)
                    }
                }
                Picker("Refresh rate", selection: $refreshInterval) {
                    Text("1 s").tag(1.0)
                    Text("2 s").tag(2.0)
                    Text("5 s").tag(5.0)
                }
                Menu("Sections") {
                    Toggle("Header",    isOn: $showHeader)
                    Toggle("CPU",       isOn: $showCPU)
                    Toggle("Memory",    isOn: $showMemory)
                    Toggle("Disk",      isOn: $showDisk)
                    Toggle("Power",     isOn: $showPower)
                    Toggle("Network",   isOn: $showNetwork)
                    Toggle("Processes", isOn: $showProcesses)
                }
            }
            Divider()
            Button("Quit Mole Widget") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            Image(nsImage: Self.menuBarIcon)
        }
    }
}

/// "Launch at login" menu item backed by SMAppService (macOS 13+).
/// Registration only works when running as a proper .app bundle;
/// from a bare dev binary register() throws and the toggle reverts.
private struct LaunchAtLoginToggle: View {
    @State private var enabled = SMAppService.mainApp.status == .enabled

    var body: some View {
        Toggle("Launch at login", isOn: Binding(
            get: { enabled },
            set: { newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                    enabled = newValue
                } catch {
                    // Keep the toggle in sync with reality on failure
                    enabled = SMAppService.mainApp.status == .enabled
                }
            }
        ))
    }
}

/// Returns whether the widget can be dragged at this moment.
private var isDraggingAllowed: Bool {
    !UserDefaults.standard.bool(forKey: WidgetSettings.positionLockedKey)
}

/// NSHostingView for the widget:
/// - mouseDownCanMoveWindow == false disables AppKit's built-in auto-drag
///   (it would ignore the lock — inner SwiftUI views report "can move");
///   dragging goes ONLY through DesktopWindow.mouseDown;
/// - acceptsFirstMouse == true so the lock button responds on the very first
///   click even though the window never becomes key.
final class WidgetHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Borderless desktop-level window: never steals focus,
/// draggable from anywhere (unless position is locked).
final class DesktopWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {
        // Drag only on left button and only when position is not locked;
        // everything else uses the standard handler (right-click etc. are not swallowed)
        if event.type == .leftMouseDown, isDraggingAllowed {
            performDrag(with: event)
        } else {
            super.mouseDown(with: event)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: DesktopWindow?
    let store = MetricsStore()

    /// Sparkle updater. `startingUpdater: true` kicks off the background check
    /// on launch (gated by SUEnableAutomaticChecks in Info.plist); the menu's
    /// "Check for Updates…" item drives it manually.
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    /// Tracks the last refresh interval seen in UserDefaults so we can detect changes.
    private var lastRefreshInterval: Double = UserDefaults.standard.object(
        forKey: WidgetSettings.refreshIntervalKey
    ) as? Double ?? WidgetSettings.defaultRefreshInterval

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // no Dock icon

        // After `brew upgrade` the registered login item points at the old
        // versioned Cellar path; re-registering from the current bundle
        // refreshes it. Throws for non-bundled dev builds — ignored.
        if SMAppService.mainApp.status == .enabled {
            try? SMAppService.mainApp.register()
        }

        store.start()

        let window = DesktopWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 300),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        // One level ABOVE the Finder desktop icon window, but still below normal windows.
        // Below the icons (like Übersicht), mouse events never reach the widget: Finder's
        // transparent full-screen desktop window intercepts all clicks, making the
        // widget impossible to drag.
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        // Visible on all Spaces, stationary in Mission Control, excluded from cmd-tab
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        let hostingView = WidgetHostingView(rootView: WidgetRootView(store: store))
        window.contentView = hostingView
        // Fit the window exactly to its content: extra transparent area
        // would capture clicks outside the visible widget
        let fitting = hostingView.fittingSize
        if fitting.width > 0, fitting.height > 0 {
            window.setContentSize(fitting)
        }

        // Idiomatic order: set default position first (center),
        // then autosave — it will overwrite with the saved frame if one exists
        window.center()
        window.setFrameAutosaveName("MoleWidgetWindow")

        window.orderFrontRegardless()
        self.window = window

        // Pause fast polling when the widget is fully hidden behind other windows.
        NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let w = self.window else { return }
                if w.occlusionState.contains(.visible) {
                    self.store.resume()
                } else {
                    self.store.suspend()
                }
            }
        }

        // Reconcile the stored width with the actual frame once at startup:
        // without this, a missing autosave entry (fresh install, cleared
        // defaults) would leave the window at fittingSize and ignore
        // widgetWidthKey until the user touches a setting.
        syncWindowSize()

        // UserDefaults changes drive two things:
        // 1. Width/height sync so the window envelope tracks SwiftUI content size.
        // 2. Refresh-rate restart when the user selects a new interval.
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.syncWindowSize()
                self?.restartStoreIfIntervalChanged()
            }
        }
    }

    /// Synchronises the window frame to the SwiftUI content size.
    /// Width follows the drag-resize handle; height follows section visibility changes.
    /// Uses DispatchQueue.main.async so SwiftUI has already re-laid-out before we read
    /// fittingSize.
    private func syncWindowSize() {
        guard let window else { return }

        // Width: driven by the drag-resize handle stored in UserDefaults.
        let stored = UserDefaults.standard.object(forKey: WidgetSettings.widgetWidthKey) as? Double
            ?? WidgetSettings.defaultWidth
        let targetWidth = WidgetSettings.clampWidth(stored)
        let widthChanged = abs(window.frame.width - targetWidth) > 0.5

        // Height: derived from SwiftUI fitting size after layout.
        // We schedule async so the layout pass has completed before we measure.
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            guard let contentView = window.contentView else { return }

            let fittingHeight = contentView.fittingSize.height
            let heightChanged = fittingHeight > 0 && abs(window.frame.height - fittingHeight) > 0.5

            if widthChanged || heightChanged {
                let newWidth  = widthChanged  ? targetWidth   : window.frame.width
                let newHeight = heightChanged ? fittingHeight : window.frame.height
                // Borderless window: frame size == content size; origin stays put.
                window.setContentSize(NSSize(width: newWidth, height: newHeight))
            }
        }
    }

    /// Re-creates the fast timer when the user picks a different refresh interval.
    /// MetricsStore.start() is idempotent (calls stop() first), so calling it again
    /// is safe and picks up the new interval from UserDefaults.
    private func restartStoreIfIntervalChanged() {
        let current = UserDefaults.standard.object(forKey: WidgetSettings.refreshIntervalKey) as? Double
            ?? WidgetSettings.defaultRefreshInterval
        guard current != lastRefreshInterval else { return }
        lastRefreshInterval = current
        store.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stop()
    }
}
