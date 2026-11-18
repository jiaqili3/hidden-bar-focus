# Hidden Bar Focus

Hidden Bar Focus is a personal macOS 27 menu bar app built on the MIT-licensed Hidden Bar 1.13.1 source. It uses the original Settings window, native visibility engine, and menu bar inventory. Open **Preferences → Icons → Menu bar icons** to switch individual apps on or off. An off switch hides that app’s icons even when both sections are expanded. The list discovers menu bar apps automatically and groups helpers under their owning app.

| Position | Control |
| --- | --- |
| Left of the arrow | Click the arrow to show or hide the left section. It shows `<` while hidden and `>` while visible. |
| Between the arrow and the moon | Click the moon to show or hide the middle section. Enable **Follow Do Not Disturb** to hide these icons when Focus turns on and show them when it turns off. |
| Right of the moon | Enabled app icons stay visible. |

The moon is filled when the middle section is hidden and outlined when it is visible. Left-click it to change middle-section visibility. Right-click it and choose **Turn Do Not Disturb On** or **Turn Do Not Disturb Off** to change the Mac’s Focus setting. **Follow Do Not Disturb** is off by default. The app remembers your choice and manual visibility across restarts. Enabling Follow immediately matches the current Do Not Disturb state.

## Build and set up

1. On macOS 27 with the Command Line Tools installed, run `FocusBar/build.sh /path/to/build-output` from the repository. The script fetches the pinned HotKey dependency. Copy **Hidden Bar Focus.app** to **Applications**.
2. Quit the original Hidden Bar if it is running, then open **Hidden Bar Focus** from Applications. Open **Preferences → General** to check Accessibility access. Enable the app in **System Settings → Privacy & Security → Accessibility**.
3. Hold **Command** while dragging a visible icon across a control. The app rereads the arrangement when the drag ends and on each manual hide. To move a hidden icon, open both sections with the arrow and moon first. Put the arrow left of the moon.
4. Create two shortcuts with **Open URLs**, one for `hiddenbar-focus://dnd/on` and one for `hiddenbar-focus://dnd/off`. In each shortcut editor, select **Automation** and add **Do Not Disturb**. Set the event to **Is Turned On** or **Is Turned Off** to match the URL and enable the automation. Create **Hidden Bar Focus – Turn Do Not Disturb On** and **Hidden Bar Focus – Turn Do Not Disturb Off**, each with a **Set Focus** action that explicitly sets Do Not Disturb to the named state. The app stores the last event it receives.
5. In **System Settings → Menu Bar → Focus**, choose **Don't Show in Menu Bar** to remove the separate macOS Focus moon. Do Not Disturb remains available in Control Center.

Apple's hiding mechanism works per app, so multiple icons from one app share a section. macOS keeps its own protected controls and controls menu bar overflow. The app releases its visibility restriction when it quits, when a change fails, or when both sections are shown with all app switches on and presentation mode off. The local build is ad hoc signed. Set `FOCUSBAR_SIGNING_IDENTITY` to use a local certificate.

## Test the state logic

```sh
test_binary="$(mktemp)"
swiftc FocusBar/Tests/main.swift FocusBar/SectionVisibility.swift \
  hidden/Common/AppDefaults.swift \
  hidden/Features/StatusBar/Layout/MenuBarLayout.swift -o "$test_binary"
"$test_binary"
unlink "$test_binary"
```
