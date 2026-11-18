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
        arrow.button?.title = ">"
        arrow.button?.font = .monospacedSystemFont(ofSize: 15, weight: .medium)
        renderControls()

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
        workspaceObservers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        if let permissionObserver { DistributedNotificationCenter.default().removeObserver(permissionObserver) }
    }

    private func configure(_ item: NSStatusItem, name: String, action: Selector) {
        item.autosaveName = name
        item.isVisible = true
        item.button?.target = self
        item.button?.action = action
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func receiveURL(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let text = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: text), let active = SectionVisibility.focusEvent(from: url) else { return }
        sections.applyFocusEvent(active)
        UserDefaults.standard.set(active, forKey: Self.focusKey)
        applyVisibility()
    }

    @objc private func toggleLeft(_ button: NSStatusBarButton) {
        guard NSApp.currentEvent?.type != .rightMouseUp else { return showMenu(from: button) }
        sections.leftExpanded.toggle()
        applyVisibility(deferManualHide: !sections.leftExpanded)
        if !sections.leftExpanded && !inventory.isAuthorized {
            openAccessibility()
        }
    }

    @objc private func toggleMiddle(_ button: NSStatusBarButton) {
        guard NSApp.currentEvent?.type != .rightMouseUp else { return showMenu(from: button) }
        sections.toggleMiddle()
        applyVisibility(deferManualHide: !sections.middleExpanded)
    }

    private func renderControls() {
        let leftAction = sections.leftExpanded ? "Hide left section" : "Show left section"
        let middleAction = sections.middleExpanded ? "Hide middle section" : "Show middle section"
        let focus: String
        switch sections.doNotDisturb {
        case .some(true): focus = "Do Not Disturb on"
        case .some(false): focus = "Do Not Disturb off"
        case .none: focus = "Do Not Disturb not synced"
        }
        let moonLabel = "\(focus) · \(middleAction)"
        arrow.button?.setAccessibilityLabel(leftAction)
        arrow.button?.toolTip = leftAction
        moon.button?.image = NSImage(systemSymbolName: sections.doNotDisturb == true ? "moon.fill" : "moon",
                                     accessibilityDescription: moonLabel)
        moon.button?.setAccessibilityLabel(moonLabel)
        moon.button?.toolTip = moonLabel
    }

    private func showMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()
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

    private func arrangementNotice(for button: NSStatusBarButton) -> String? {
        guard let measured = layout ?? lastCompleteLayout else { return nil }
        if button === arrow.button && measured.bundles(in: [.alwaysHidden]).isEmpty {
            return "No app icons to the left of >"
        }
        if button === moon.button && measured.bundles(in: [.hidden]).isEmpty {
            return "No app icons between > and the moon"
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
            layout = nil
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
                self?.restrictVisibility(ownBundle: ownBundle, request: request)
            }
        } else {
            restrictVisibility(ownBundle: ownBundle, request: request)
        }
    }

    private func restrictVisibility(ownBundle: String, request: Int) {
        guard revision == request else { return }
        // A show request can reuse the measured arrangement while a hide is still applying.
        if let layout {
            activate(layout: layout, ownBundle: ownBundle, request: request)
            return
        }

        inventory.snapshot { [weak self] items in
            guard let self, self.revision == request else { return }
            guard let left = self.arrow.button?.window?.frame,
                  let right = self.moon.button?.window?.frame,
                  left.width > 0, right.width > 0, left.midX < right.midX,
                  abs(left.midY - right.midY) < 4 else {
                return self.showUnrestricted("Command-drag > to the left of the moon.")
            }
            var measured = MenuBarLayoutResolver.resolve(
                inventory: items, separatorFrame: right, alwaysHiddenSeparatorFrame: left,
                displays: MenuBarDisplay.current(), isLTR: true, excludingBundle: ownBundle)
            if measured.isIncomplete {
                guard let previous = self.lastCompleteLayout else {
                    return self.showUnrestricted("Free menu bar space before organizing icons.")
                }
                measured = measured.fillingIn(from: previous)
            } else {
                self.lastCompleteLayout = measured
            }
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
                previous?.invalidate()
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
        revision += 1
        assertion?.invalidate()
        assertion = nil
        layout = nil
        failure = reason
    }
}
