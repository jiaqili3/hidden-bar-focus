import Foundation

func require(_ condition: @autoclosure () -> Bool, _ detail: String) {
    guard condition() else { fatalError(detail) }
}

var state = SectionVisibility(doNotDisturb: nil, followsDoNotDisturb: true)
require(state.shownSections == [.visible, .hidden], "Only the middle and right start visible")
state.applyFocusEvent(true)
require(state.shownSections == [.visible], "Do Not Disturb hides the middle")
state.leftExpanded = true
require(state.shownSections == [.visible, .alwaysHidden], "Left opens independently of the middle")
state.applyFocusEvent(false)
require(state.showsAll, "Turning Do Not Disturb off opens the middle and preserves the left")
state.leftExpanded = false
state.toggleMiddle()
require(state.shownSections == [.visible], "The moon can hide the middle while Do Not Disturb is off")
state.applyFocusEvent(false)
require(state.shownSections == [.visible, .hidden], "An off event opens the middle even if its on event was missed")
state.applyFocusEvent(true)
state.toggleMiddle()
require(state.shownSections == [.visible, .hidden], "The moon can open the middle while Do Not Disturb is on")
require(state.doNotDisturb == true, "The moon still indicates Do Not Disturb during a manual override")
state.applyFocusEvent(false)
state.applyFocusEvent(true)
require(state.shownSections == [.visible], "The next Do Not Disturb transition overrides the manual choice")
state.revealForArrangement()
require(state.showsAll && state.doNotDisturb == true, "Arranging icons reveals both sections without changing Do Not Disturb")

let restarted = SectionVisibility(doNotDisturb: true, followsDoNotDisturb: true)
require(restarted.shownSections == [.visible], "Restart restores the last Do Not Disturb state")

var manual = SectionVisibility(doNotDisturb: true)
require(manual.middleExpanded && !manual.followsDoNotDisturb, "A new installation starts detached even when DND is on")
manual.toggleMiddle()
manual.applyFocusEvent(false)
require(!manual.middleExpanded && manual.doNotDisturb == false, "An off event updates the moon without expanding")
manual.toggleMiddle()
manual.applyFocusEvent(true)
require(manual.middleExpanded && manual.doNotDisturb == true, "An on event updates the moon without hiding")
let restoredManual = SectionVisibility(doNotDisturb: true, followsDoNotDisturb: false, savedMiddleExpanded: true)
require(restoredManual.middleExpanded && !restoredManual.followsDoNotDisturb, "Manual visibility survives restart")
manual.setFollowsDoNotDisturb(true)
require(!manual.middleExpanded, "Enabling follow immediately adopts the current Focus state")
manual.applyFocusEvent(false)
require(manual.middleExpanded, "Automatic expansion resumes")

let layout = MenuBarLayoutResolver.resolve(
    inventory: [
        MenuBarInventoryItem(bundleIdentifier: "local.test.left", frame: CGRect(x: 10, y: 0, width: 10, height: 20)),
        MenuBarInventoryItem(bundleIdentifier: "local.test.middle", frame: CGRect(x: 60, y: 0, width: 10, height: 20)),
        MenuBarInventoryItem(bundleIdentifier: "local.test.right", frame: CGRect(x: 110, y: 0, width: 10, height: 20)),
    ],
    separatorFrame: CGRect(x: 90, y: 0, width: 10, height: 20),
    alwaysHiddenSeparatorFrame: CGRect(x: 40, y: 0, width: 10, height: 20),
    isLTR: true, excludingBundle: nil)
var controls = SectionVisibility(doNotDisturb: false, followsDoNotDisturb: true)
controls.revealForArrangement()
controls.leftExpanded.toggle()
require(layout.bundles(in: controls.shownSections) == ["local.test.middle", "local.test.right"],
        "The > button hides the app left of it and leaves the middle and right visible")
controls.leftExpanded.toggle()
controls.applyFocusEvent(true)
require(layout.bundles(in: controls.shownSections) == ["local.test.left", "local.test.right"],
        "The on event hides only the app between the buttons")
controls.toggleMiddle()
require(layout.bundles(in: controls.shownSections).count == 3, "Clicking the moon can reveal the middle during Do Not Disturb")

for (text, expected) in [
    ("hiddenbar-focus://dnd/on", true),
    ("hiddenbar-focus://dnd/off", false),
    ("hiddenbar-focus://dnd/toggle", nil),
    ("https://dnd/on", nil),
    ("hiddenbar-focus://dnd/on?x=y", nil)
] as [(String, Bool?)] {
    require(SectionVisibility.focusEvent(from: URL(string: text)!) == expected, text)
}
print("Section visibility and Focus URL tests passed")
