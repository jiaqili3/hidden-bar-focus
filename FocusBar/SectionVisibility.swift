import Foundation

struct SectionVisibility {
    var leftExpanded = false
    private(set) var middleExpanded: Bool
    private(set) var doNotDisturb: Bool?

    init(doNotDisturb: Bool?) {
        self.doNotDisturb = doNotDisturb
        self.middleExpanded = doNotDisturb != true
    }

    mutating func toggleMiddle() {
        middleExpanded.toggle()
    }

    mutating func setDoNotDisturb(_ active: Bool) {
        guard doNotDisturb != active else { return }
        doNotDisturb = active
        middleExpanded = !active
    }

    mutating func revealForArrangement() {
        leftExpanded = true
        middleExpanded = true
    }

    var showsAll: Bool { leftExpanded && middleExpanded }

    var shownSections: Set<MenuBarSection> {
        var shown: Set<MenuBarSection> = [.visible]
        if middleExpanded { shown.insert(.hidden) }
        if leftExpanded { shown.insert(.alwaysHidden) }
        return shown
    }

    static func focusEvent(from url: URL) -> Bool? {
        guard url.scheme == "hiddenbar-focus", url.host == "dnd",
              url.query == nil, url.fragment == nil, url.user == nil,
              url.password == nil, url.port == nil else { return nil }
        switch url.path {
        case "/on": return true
        case "/off": return false
        default: return nil
        }
    }
}
