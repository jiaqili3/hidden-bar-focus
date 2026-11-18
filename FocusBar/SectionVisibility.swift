import Foundation

struct SectionVisibility {
    var leftExpanded = false
    private(set) var middleExpanded: Bool
    private(set) var doNotDisturb: Bool?
    private(set) var followsDoNotDisturb: Bool

    init(doNotDisturb: Bool?, followsDoNotDisturb: Bool = false, savedMiddleExpanded: Bool? = nil) {
        self.doNotDisturb = doNotDisturb
        self.followsDoNotDisturb = followsDoNotDisturb
        self.middleExpanded = followsDoNotDisturb ? doNotDisturb != true : savedMiddleExpanded ?? true
    }

    mutating func toggleMiddle(afterFailedHide: Bool = false) {
        middleExpanded = afterFailedHide ? false : !middleExpanded
    }

    mutating func applyFocusEvent(_ active: Bool) {
        doNotDisturb = active
        if followsDoNotDisturb { middleExpanded = !active }
    }

    mutating func setFollowsDoNotDisturb(_ enabled: Bool) {
        followsDoNotDisturb = enabled
        if enabled, let doNotDisturb { middleExpanded = !doNotDisturb }
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
