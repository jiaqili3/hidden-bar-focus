# Hidden Bar Focus

Hidden Bar Focus is a personal macOS 27 menu bar app built on the MIT-licensed Hidden Bar 1.13.1 source. It uses Hidden Bar's macOS 27 visibility bridge and menu bar inventory.

| Position | Control |
| --- | --- |
| Left of the arrow | Click the arrow to show or hide the left section. It shows `<` while hidden and `>` while visible. |
| Between the arrow and the moon | Click the moon to show or hide the middle section. Do Not Disturb hides it when enabled and shows it when disabled. A manual click lasts until the next Do Not Disturb transition. |
| Right of the moon | Icons stay visible. |

The moon is filled when Do Not Disturb is on and outlined when it is off. Left-click it to change middle-section visibility. Right-click it and choose **Toggle Do Not Disturb** to change the Mac’s Focus setting.

## Build and set up

1. On macOS 27 with the Command Line Tools installed, run `FocusBar/build.sh /path/to/build-output` from the repository. Copy **Hidden Bar Focus.app** to **Applications**.
2. Quit the original Hidden Bar if it is running, then open **Hidden Bar Focus** from Applications. Right-click either control and choose **Open Accessibility Settings…**, then enable the app in **Privacy & Security → Accessibility**.
3. Hold **Command** while dragging a visible icon across a control. The app rereads the arrangement when the drag ends and on each manual hide. To move a hidden icon, right-click either control and choose **Show All to Arrange Icons** first. Put the arrow left of the moon.
4. Create two shortcuts with **Open URLs**, one for `hiddenbar-focus://dnd/on` and one for `hiddenbar-focus://dnd/off`. In each shortcut editor, select **Automation** and add **Do Not Disturb**. Set the event to **Is Turned On** or **Is Turned Off** to match the URL and enable the automation. Create a third shortcut named **Hidden Bar Focus – Toggle Do Not Disturb** with the **Set Focus** action configured to **Toggle Do Not Disturb**. The app stores the last event it receives.
5. In **System Settings → Menu Bar → Focus**, choose **Don't Show in Menu Bar** to remove the separate macOS Focus moon. Do Not Disturb remains available in Control Center.

If the arrow has no visible effect, right-click it after a hide attempt. If the menu reports that the left section is empty, choose **Show All to Arrange Icons**, Command-drag an app icon to the left of the arrow, then click the arrow to hide it.

Apple's hiding mechanism works per app, so multiple icons from one app share a section. macOS keeps its own protected controls and controls menu bar overflow. The app releases its visibility restriction when it quits, when a change fails, or when both sections are shown. The local build is ad hoc signed. Set `FOCUSBAR_SIGNING_IDENTITY` to use a local certificate.

## Test the state logic

```sh
test_binary="$(mktemp)"
swiftc FocusBar/Tests/main.swift FocusBar/SectionVisibility.swift \
  hidden/Common/AppDefaults.swift \
  hidden/Features/StatusBar/Layout/MenuBarLayout.swift -o "$test_binary"
"$test_binary"
unlink "$test_binary"
```
