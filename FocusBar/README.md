# Hidden Bar Focus

Hidden Bar Focus is a personal macOS 27 menu bar app built on the MIT-licensed Hidden Bar 1.13.1 source. It uses Hidden Bar's macOS 27 visibility bridge and menu bar inventory.

| Position | Control |
| --- | --- |
| Left of `>` | Click `>` to show or hide the left section. It starts hidden. |
| Between `>` and the moon | Click the moon to show or hide the middle section. Do Not Disturb hides it when enabled and shows it when disabled. A manual click lasts until the next Do Not Disturb transition. |
| Right of the moon | Icons stay visible. |

The moon is filled when Do Not Disturb is on and outlined when it is off. Clicking it changes only icon visibility.

## Build and set up

1. On macOS 27 with the Command Line Tools installed, run `FocusBar/build.sh /path/to/build-output` from the repository. Copy **Hidden Bar Focus.app** to **Applications**.
2. Quit the original Hidden Bar if it is running, then open **Hidden Bar Focus** from Applications. Right-click either control and choose **Open Accessibility Settings…**, then enable the app in **Privacy & Security → Accessibility**.
3. Right-click either control and choose **Show All to Arrange Icons**. Hold **Command** while dragging the controls and app icons into place. Put `>` left of the moon. The next hide action measures the arrangement. Reveal both sections again before rearranging a hidden icon.
4. In **Shortcuts → Automation**, add two **Do Not Disturb** triggers set to **Run Immediately**. For **When Turning On**, add **Open URLs** with `hiddenbar-focus://dnd/on`. For **When Turning Off**, use `hiddenbar-focus://dnd/off`. Toggle Do Not Disturb once to initialize the moon. The app stores the last event it receives.
5. In **System Settings → Menu Bar → Focus**, choose **Don't Show in Menu Bar** to remove the separate macOS Focus moon. Do Not Disturb remains available in Control Center.

If `>` has no visible effect, right-click it after a hide attempt. If the menu reports that the left section is empty, choose **Show All to Arrange Icons**, Command-drag an app icon to the left of `>`, then click `>` to hide it.

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
