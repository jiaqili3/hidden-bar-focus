import AppKit
import Carbon

/// Starts the original app's settings, hotkeys and status-bar controller with the
/// two-button layout and the existing personal preferences domain.
@main
final class FocusBar: AppDelegate {
    static let focusKey = "lastDoNotDisturbState"
    static let followKey = "middleFollowsDoNotDisturb"
    static let middleKey = "middleSectionExpanded"
    private var monitors: [Any] = []
    private var dragOrigin: CGPoint?

    static func main() {
        let app = NSApplication.shared
        let delegate = FocusBar()
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(receiveURL(_:reply:)),
            forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    override func applicationDidFinishLaunching(_ notification: Notification) {
        var defaults = AppDelegate.defaultPreferenceValues
        defaults[UserDefaults.Key.alwaysHiddenSectionEnabled] = true
        defaults[UserDefaults.Key.areSeparatorsHidden] = true
        defaults[UserDefaults.Key.isShowPreference] = false
        defaults[UserDefaults.Key.isAutoHide] = false
        defaults[UserDefaults.Key.pinnedSectionsEnabled] = false
        defaults[UserDefaults.Key.showWholeBarWhenCaptureStarts] = false
        AppDefaults.store.register(defaults: defaults)
        MenuBarAppsPane.makeViewController = { MenuBarAppsSettingsViewController(context: .live) }
        detectLTRLang()
        _ = statusBarController
        setupHotKey()
        IconSettings.shared.onChange = { [weak self] in self?.statusBarController.focusIconPreferencesChanged() }
        observeRearrangement()
        openPreferencesIfNeeded()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Util.showPrefWindow()
        PreferencesWindowController.shared.select(.menuBarApps)
        return true
    }

    @objc private func receiveURL(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let text = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: text), let active = SectionVisibility.focusEvent(from: url) else { return }
        AppDefaults.store.set(active, forKey: Self.focusKey)
        if AppDefaults.store.bool(forKey: Self.followKey) {
            statusBarController.setFocusMiddle(expanded: !active)
        } else {
            statusBarController.refreshFocusButtons()
        }
    }

    private func observeRearrangement() {
        let handle: (NSEvent) -> Void = { [weak self] event in
            guard let self, let position = event.cgEvent?.location else { return }
            if event.type == .leftMouseDown {
                self.dragOrigin = nil
                guard event.modifierFlags.contains(.command) else { return }
                let inBar = MenuBarDisplay.current().contains { display in
                    var band = display.accessibilityFrame
                    band.size.height = max(NSStatusBar.system.thickness,
                        NSScreen.screens.first(where: { $0.frame == display.appKitFrame })?.safeAreaInsets.top ?? 0)
                    return band.contains(position)
                }
                if inBar { self.dragOrigin = position }
            } else if let origin = self.dragOrigin {
                self.dragOrigin = nil
                if hypot(position.x - origin.x, position.y - origin.y) >= 3 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self.statusBarController.focusArrangementChanged() }
                }
            }
        }
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseUp]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handle) { monitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { handle($0); return $0 }) { monitors.append(local) }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitors.forEach(NSEvent.removeMonitor)
    }
}
