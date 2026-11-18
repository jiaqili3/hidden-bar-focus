import AppKit
import SwiftUI

final class IconSettings: ObservableObject {
    static let shared = IconSettings()
    static let defaultsKey = "disabledMenuBarApps"
    @Published private(set) var disabled: Set<String>
    @Published private(set) var apps: [AppRow] = []
    @Published var notice: String?
    var onChange: (() -> Void)?

    struct AppRow: Identifiable {
        let id: String
        let name: String
        let icon: NSImage
    }

    private let identities = MenuBarAppIdentityCache()
    private var owners: [String: String] = [:]
    private var known = Set<String>()
    private let inventory = AccessibilityMenuBarInventory()
    private var refreshing = false

    init() {
        disabled = Set(UserDefaults.standard.stringArray(forKey: Self.defaultsKey) ?? [])
        known = disabled
    }

    // Status items can belong to a nested launcher. Give the containing app
    // one switch and apply it to each of its running bundle identifiers.
    func owner(of bundle: String) -> String {
        if let cached = owners[bundle] { return cached }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first
        guard let url = running?.bundleURL ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) else {
            return bundle
        }
        let outer = MenuBarAppIdentity.outermostApp(url)
        let id = outer == url ? bundle : Bundle(url: outer)?.bundleIdentifier ?? bundle
        owners[bundle] = id
        return id
    }

    func excludedBundles(in candidates: Set<String>) -> Set<String> {
        guard !disabled.isEmpty else { return [] }
        return Set(candidates.filter { disabled.contains($0) || disabled.contains(owner(of: $0)) })
    }

    func observe(_ items: [MenuBarInventoryItem]) {
        for item in items where !item.isUnconfirmedOwner {
            guard let bundle = item.bundleIdentifier,
                  !MenuBarLayoutResolver.systemItemOwners.contains(bundle),
                  bundle != Bundle.main.bundleIdentifier else { continue }
            known.insert(owner(of: bundle))
        }
        updateRows()
    }

    private func updateRows() {
        let ids = known.union(disabled)
        guard Set(apps.map(\.id)) != ids else { return }
        apps = ids.map { id in
            let resolved = identities.identity(for: id)
            let name = id == "us.zoom.xos" ? "Zoom" : resolved.name
            return AppRow(id: id, name: name, icon: identities.icon(for: id))
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func setEnabled(_ enabled: Bool, for id: String) {
        if enabled { disabled.remove(id) } else { disabled.insert(id) }
        UserDefaults.standard.set(disabled.sorted(), forKey: Self.defaultsKey)
        onChange?()
    }

    func refresh() {
        updateRows()
        guard !refreshing else { return }
        guard inventory.isAuthorized else {
            notice = "Allow Accessibility access in General to discover the other menu bar apps."
            return
        }
        notice = nil
        refreshing = true
        inventory.snapshot { [weak self] items in
            self?.refreshing = false
            self?.observe(items)
        }
    }

    func settingsView() -> NSView {
        let view = NSHostingView(rootView: IconSettingsView(settings: self))
        view.heightAnchor.constraint(equalToConstant: 280).isActive = true
        return view
    }

}

private struct IconSettingsView: View {
    @ObservedObject var settings: IconSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Menu bar icons").font(.title2.bold())
            Text("Turn off an app to hide its icons in every section.")
                .foregroundStyle(.secondary)
            if let notice = settings.notice { Text(notice).foregroundStyle(.secondary) }
            List(settings.apps) { app in
                Toggle(isOn: Binding(get: { !settings.disabled.contains(app.id) },
                                     set: { settings.setEnabled($0, for: app.id) })) {
                    HStack(spacing: 10) {
                        Image(nsImage: app.icon).resizable().frame(width: 22, height: 22).accessibilityHidden(true)
                        Text(app.name)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .toggleStyle(.switch)
                .accessibilityLabel(app.name)
                .padding(.vertical, 3)
            }
            .listStyle(.inset)
        }
        .onAppear { settings.refresh() }
        .onReceive(Timer.publish(every: 3, on: .main, in: .common).autoconnect()) { _ in
            if PreferencesWindowController.isVisible { settings.refresh() }
        }
    }
}
