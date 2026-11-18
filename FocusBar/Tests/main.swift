import Foundation

func require(_ condition: @autoclosure () -> Bool, _ detail: String) {
    guard condition() else { fatalError(detail) }
}

var state = SectionVisibility(doNotDisturb: nil)
require(state.shownSections == [.visible, .hidden], "Only the middle and right start visible")
state.setDoNotDisturb(true)
require(state.shownSections == [.visible], "Do Not Disturb hides the middle")
state.leftExpanded = true
require(state.shownSections == [.visible, .alwaysHidden], "Left opens independently of the middle")
state.setDoNotDisturb(false)
require(state.showsAll, "Turning Do Not Disturb off opens the middle and preserves the left")
state.leftExpanded = false
state.toggleMiddle()
require(state.shownSections == [.visible], "The moon can hide the middle while Do Not Disturb is off")
state.setDoNotDisturb(false)
require(state.shownSections == [.visible], "Duplicate events preserve a manual choice")
state.setDoNotDisturb(true)
state.toggleMiddle()
require(state.shownSections == [.visible, .hidden], "The moon can open the middle while Do Not Disturb is on")
require(state.doNotDisturb == true, "The moon still indicates Do Not Disturb during a manual override")
state.setDoNotDisturb(false)
state.setDoNotDisturb(true)
require(state.shownSections == [.visible], "The next Do Not Disturb transition overrides the manual choice")
state.revealForArrangement()
require(state.showsAll && state.doNotDisturb == true, "Arranging icons reveals both sections without changing Do Not Disturb")

let restarted = SectionVisibility(doNotDisturb: true)
require(restarted.shownSections == [.visible], "Restart restores the last Do Not Disturb state")
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
