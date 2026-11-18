import AppKit
import Carbon

// The standalone target shares Hidden Bar's positioning and native visibility code.
enum NativeVisibilityEngine {
    static func isInApplicationsFolder(
        _ url: URL,
        applicationFolders: [URL] = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask)
    ) -> Bool {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        return applicationFolders.contains {
            path.hasPrefix($0.resolvingSymlinksInPath().standardizedFileURL.path + "/")
        }
    }
}

@main
final class FocusBar: NSObject, NSApplicationDelegate {
    private static let focusKey = "lastDoNotDisturbState"
    private let inventory = AccessibilityMenuBarInventory()
    private let visibility = NativeVisibilityBridge()
    private let systemItems = Array(0..<64)
    private let moon = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let arrow = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var sections = SectionVisibility(doNotDisturb: UserDefaults.standard.object(forKey: focusKey) as? Bool)
    private var layout: MenuBarLayout?
    private var lastCompleteLayout: MenuBarLayout?
    private var assertion: NativeVisibilityAssertion?
    private var revision = 0
    private var failure: String?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var permissionObserver: NSObjectProtocol?
    private var dragMonitors: [Any] = []
    private var dragOrigin: CGPoint?
    private var restrictedBundles = Set<String>()
    private var needsMeasurement = false
    private var focusCommand: Process?
    private var focusCommandError: String?
    private static let toggleShortcut = "Hidden Bar Focus – Toggle Do Not Disturb"

    static func main() {
        let app = NSApplication.shared
        let delegate = FocusBar()
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self, andSelector: #selector(receiveURL(_:reply:)),
            forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configure(moon, name: "focusbar_moon", action: #selector(toggleMiddle(_:)))
        configure(arrow, name: "focusbar_left", action: #selector(toggleLeft(_:)))
        arrow.button?.font = .monospacedSystemFont(ofSize: 15, weight: .medium)
        renderLeftControl(hidden: false)
        renderControls()
        observeRearrangement()

        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didWakeNotification] {
            workspaceObservers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self, self.assertion != nil else { return }
                self.applyVisibility()
            })
        }
        permissionObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.accessibility.api"), object: nil, queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self?.applyVisibility() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.applyVisibility() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        revision += 1
        assertion?.invalidate()
        dragMonitors.forEach(NSEvent.removeMonitor)
        workspaceObservers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        if let permissionObserver { DistributedNotificationCenter.default().removeObserver(permissionObserver) }
    }

    private func observeRearrangement() {
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseUp]
        let handle: (NSEvent) -> Void = { [weak self] event in
            guard let self, let position = event.cgEvent?.location else { return }
            if event.type == .leftMouseDown {
                self.dragOrigin = nil
                guard event.modifierFlags.contains(.command) else { return }
                let inMenuBar = MenuBarDisplay.current().contains { display in
                    var bar = display.accessibilityFrame
                    bar.size.height = max(NSStatusBar.system.thickness,
                        NSScreen.screens.first(where: { $0.frame == display.appKitFrame })?.safeAreaInsets.top ?? 0)
                    return bar.contains(position)
                }
                if inMenuBar { self.dragOrigin = position }
            } else if let origin = self.dragOrigin {
                self.dragOrigin = nil
                guard hypot(position.x - origin.x, position.y - origin.y) >= 3 else { return }
                self.needsMeasurement = true
                self.applyVisibility(deferManualHide: true)
            }
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handle) {
            dragMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { event in
            handle(event)
            return event
        }) { dragMonitors.append(local) }
    }

    private func configure(_ item: NSStatusItem, name: String, action: Selector) {
        item.autosaveName = name
        item.isVisible = true
        item.button?.target = self
        item.button?.action = action
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        if let button = item.button {
            button.setAccessibilityCustomActions([NSAccessibilityCustomAction(name: "Show Menu") { [weak self, weak button] in
                guard let self, let button else { return false }
                DispatchQueue.main.async { self.showMenu(from: button) }
                return true
            }])
        }
    }

    @objc private func receiveURL(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let text = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: text), let active = SectionVisibility.focusEvent(from: url) else { return }
        sections.applyFocusEvent(active)
        UserDefaults.standard.set(active, forKey: Self.focusKey)
        applyVisibility()
    }

    @objc private func toggleLeft(_ button: NSStatusBarButton) {
        if isContextClick { return showMenu(from: button) }
        // A failed restriction leaves the icons visible, so retry hiding them.
        sections.leftExpanded = failure == nil ? !sections.leftExpanded : false
        applyVisibility(deferManualHide: !sections.leftExpanded)
        if !sections.leftExpanded && !inventory.isAuthorized {
            openAccessibility()
        }
    }

    @objc private func toggleMiddle(_ button: NSStatusBarButton) {
        if isContextClick { return showMenu(from: button) }
        sections.toggleMiddle()
        applyVisibility(deferManualHide: !sections.middleExpanded)
    }

    private func renderControls() {
        let middleAction = sections.middleExpanded ? "Hide middle section" : "Show middle section"
        let focus: String
        switch sections.doNotDisturb {
        case .some(true): focus = "Do Not Disturb on"
        case .some(false): focus = "Do Not Disturb off"
        case .none: focus = "Do Not Disturb not synced"
        }
        let moonLabel = "\(focus) · \(middleAction)"
        moon.button?.image = NSImage(systemSymbolName: sections.doNotDisturb == true ? "moon.fill" : "moon",
                                     accessibilityDescription: moonLabel)
        moon.button?.setAccessibilityLabel(moonLabel)
        moon.button?.toolTip = moonLabel
    }

    private var isContextClick: Bool {
        guard let event = NSApp.currentEvent else { return false }
        return event.type == .rightMouseUp || (event.type == .leftMouseUp && event.modifierFlags.contains(.control))
    }

    private func renderLeftControl(hidden: Bool) {
        let action = hidden ? "Show left section" : "Hide left section"
        arrow.button?.title = hidden ? "<" : ">"
        arrow.button?.setAccessibilityLabel(action)
        arrow.button?.toolTip = action
    }

    private func showMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()
        if button === moon.button {
            if let focusCommandError {
                menu.addItem(withTitle: focusCommandError, action: nil, keyEquivalent: "")
            }
            let toggle = menu.addItem(withTitle: "Toggle Do Not Disturb", action: #selector(toggleDoNotDisturb), keyEquivalent: "")
            toggle.target = self
            toggle.state = sections.doNotDisturb == true ? .on : .off
            menu.addItem(.separator())
        }
        if let notice = failure ?? arrangementNotice(for: button) {
            menu.addItem(withTitle: notice, action: nil, keyEquivalent: "").isEnabled = false
            menu.addItem(.separator())
        }
        let arrange = menu.addItem(withTitle: "Show All to Arrange Icons", action: #selector(arrangeIcons), keyEquivalent: "")
        arrange.target = self
        if !inventory.isAuthorized {
            let permission = menu.addItem(withTitle: "Open Accessibility Settings…",
                                          action: #selector(openAccessibility), keyEquivalent: "")
            permission.target = self
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Hidden Bar Focus", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.popUp(positioning: nil, at: .zero, in: button)
    }

    @objc private func toggleDoNotDisturb() {
        guard focusCommand == nil else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", Self.toggleShortcut]
        process.standardInput = FileHandle.nullDevice
        focusCommandError = nil
        focusCommand = process
        process.terminationHandler = { [weak self] task in
            DispatchQueue.main.async {
                self?.focusCommand = nil
                if task.terminationStatus != 0 { self?.focusCommandError = "Check the Toggle Do Not Disturb shortcut in Shortcuts." }
            }
        }
        do { try process.run() } catch {
            focusCommand = nil
            focusCommandError = "Could not start Shortcuts."
        }
    }

    private func arrangementNotice(for button: NSStatusBarButton) -> String? {
        guard let measured = layout ?? lastCompleteLayout else { return nil }
        if button === arrow.button && measured.bundles(in: [.alwaysHidden]).isEmpty {
            return "No app icons to the left of the arrow"
        }
        if button === moon.button && measured.bundles(in: [.hidden]).isEmpty {
            return "No app icons between the arrow and the moon"
        }
        return nil
    }

    @objc private func arrangeIcons() {
        sections.revealForArrangement()
        applyVisibility()
    }

    @objc private func openAccessibility() {
        inventory.requestAuthorization()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func applyVisibility(deferManualHide: Bool = false) {
        revision += 1
        let request = revision
        renderControls()
        failure = nil

        if sections.showsAll {
            assertion?.invalidate()
            assertion = nil
            restrictedBundles.removeAll()
            layout = nil
            renderLeftControl(hidden: false)
            return
        }

        guard NativeVisibilityEngine.isInApplicationsFolder(Bundle.main.bundleURL) else {
            return showUnrestricted("Move Hidden Bar Focus to Applications.")
        }
        guard inventory.isAuthorized else {
            return showUnrestricted("Allow Accessibility to hide icons.")
        }
        guard visibility.isAvailable else {
            return showUnrestricted("This macOS build cannot hide these icons.")
        }
        guard let ownBundle = Bundle.main.bundleIdentifier else { return }

        if deferManualHide {
            // A quick second click can cancel the hide before macOS starts applying it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.restrictVisibility(ownBundle: ownBundle, request: request, remeasure: true)
            }
        } else {
            restrictVisibility(ownBundle: ownBundle, request: request)
        }
    }

    private func restrictVisibility(ownBundle: String, request: Int, remeasure: Bool = false) {
        guard revision == request else { return }
        // A show request can reuse the measured arrangement while a hide is still applying.
        if let layout, !needsMeasurement, !remeasure {
            activate(layout: layout, ownBundle: ownBundle, request: request)
            return
        }

        inventory.snapshot { [weak self] items in
            guard let self, self.revision == request else { return }
            guard let left = self.arrow.button?.window?.frame,
                  let right = self.moon.button?.window?.frame,
                  left.width > 0, right.width > 0, left.midX < right.midX,
                  abs(left.midY - right.midY) < 4 else {
                return self.showUnrestricted("Command-drag the arrow to the left of the moon.")
            }
            // Hidden items report stale frames. Keep their section until they are visible again.
            let observable = items.filter { !self.restrictedBundles.contains($0.bundleIdentifier ?? "") }
            var measured = MenuBarLayoutResolver.resolve(
                inventory: observable, separatorFrame: right, alwaysHiddenSeparatorFrame: left,
                displays: MenuBarDisplay.current(), isLTR: true, excludingBundle: ownBundle)
            if let current = self.layout {
                measured = measured.fillingIn(from: current)
            } else if measured.isIncomplete {
                guard let previous = self.lastCompleteLayout else {
                    return self.showUnrestricted("Free menu bar space before organizing icons.")
                }
                measured = measured.fillingIn(from: previous)
            } else {
                self.lastCompleteLayout = measured
            }
            self.needsMeasurement = false
            self.layout = measured
            self.activate(layout: measured, ownBundle: ownBundle, request: request)
        }
    }

    private func activate(layout: MenuBarLayout, ownBundle: String, request: Int) {
        let shown = sections.shownSections
        if !layout.unnameableVisibleItems.isEmpty || !layout.unkeepableVisibleApps.isEmpty {
            return showUnrestricted("macOS cannot keep one of the right-section icons visible.")
        }
        let known = layout.bundles(in: shown)
        // Apps that start after the last unrestricted read stay visible until arranged.
        let unclassified = NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
            .filter { layout.sections[$0] == nil }
        let allowed = Set(known + unclassified + [ownBundle]).sorted()
        var finished = false
        visibility.activate(allowedSystemItems: systemItems, allowedBundleIdentifiers: allowed) { [weak self] result in
            guard let self, self.revision == request else {
                if case .success(let obsolete) = result { obsolete.invalidate() }
                return
            }
            finished = true
            switch result {
            case .success(let newAssertion):
                let previous = self.assertion
                self.assertion = newAssertion
                self.restrictedBundles = Set(layout.sections.keys).subtracting(allowed)
                previous?.invalidate()
                self.renderLeftControl(hidden: !shown.contains(.alwaysHidden))
                NSLog("Hidden Bar Focus: applied sections left=%d middle=%d hiddenApps=%d", self.sections.leftExpanded, self.sections.middleExpanded, self.restrictedBundles.count)
            case .failure(let error):
                NSLog("Hidden Bar Focus: %@", error.localizedDescription)
                self.showUnrestricted("macOS declined the visibility change.")
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self, self.revision == request, !finished else { return }
            self.showUnrestricted("macOS did not respond to the visibility change.")
        }
    }

    private func showUnrestricted(_ reason: String) {
        NSLog("Hidden Bar Focus: %@", reason)
        revision += 1
        assertion?.invalidate()
        assertion = nil
        restrictedBundles.removeAll()
        layout = nil
        failure = reason
        renderLeftControl(hidden: false)
    }
}
