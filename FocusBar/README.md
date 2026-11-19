# Hidden Bar Focus guide

## Install or upgrade

1. Follow the [build instructions](../README.md#build-and-install) on macOS 27. The script fetches a pinned HotKey revision and creates an app for the architecture of the Mac doing the build.
2. For an upgrade, quit the running Hidden Bar Focus from either control’s menu. Copy the new **Hidden Bar Focus.app** into **Applications**, replacing the older copy. Open it from Applications.
3. Grant access in **System Settings → Privacy & Security → Accessibility**. **Preferences → General** shows whether Hidden Bar Focus can read your menu bar.
4. For automatic startup, turn on **Open Hidden Bar at login** in **Preferences → General**.

The build script signs the app ad hoc by default. To use a local signing identity, set `FOCUSBAR_SIGNING_IDENTITY` when running `FocusBar/build.sh`. An updated ad hoc build can need a fresh Accessibility grant. If macOS lists the app as enabled but the General tab still reports missing access, remove the old entry, add the copy from Applications, and reopen the app.

## Arrange and hide icons

- Place the arrow to the left of the moon. Open both sections, then hold **⌘ Command** and drag a visible icon across either control. The app rereads the arrangement after you drop the icon.
- Click the arrow to toggle the left section. Click the moon to toggle the middle section. The moon’s fill reflects whether the middle section is hidden.
- Turn off an app in **Preferences → Icons → Menu bar icons** to hide its icons in every section. Turn the switch back on to return the icons to their section. The list discovers apps automatically and groups helpers under their owning app when it can identify the owner.
- Enable **Pinned sections** in **Preferences → Advanced** to assign sections in **Icons**. The default arrangement follows where you drag icons.

macOS manages visibility by app, so multiple icons from the same app share a section.

## Do Not Disturb

**Follow Do Not Disturb** is off by default. With it off, the moon controls the middle section manually. With it on, an incoming Do Not Disturb event hides the middle when Focus turns on and reveals it when Focus turns off. You can still click the moon at any time. The next Do Not Disturb event applies the automatic rule again. The app remembers your Follow setting and manual visibility across restarts.

### Make the middle section follow Do Not Disturb

1. In **Shortcuts** on your Mac, create the two shortcuts below. Give each shortcut one **Open URLs** action with the matching URL.

   | Shortcut name | URL | Do Not Disturb trigger |
   | --- | --- | --- |
   | `Hidden Bar Focus – DND On` | `hiddenbar-focus://dnd/on` | **Is Turned On** |
   | `Hidden Bar Focus – DND Off` | `hiddenbar-focus://dnd/off` | **Is Turned Off** |

2. In each shortcut’s editor, open **Automation**, choose **Do Not Disturb**, and enable the matching trigger. Run the shortcut that matches the Mac’s current state once to sync the initial state.
3. Right-click the moon and check **Follow Do Not Disturb**.
4. Test both directions from **Control Center → Focus → Do Not Disturb**. The middle section should hide when Do Not Disturb turns on and reappear when it turns off. The left section stays under the arrow’s control.

See [Apple’s guide to automations in Shortcuts on Mac](https://support.apple.com/guide/shortcuts-mac/add-automations-apdfbdbd7123/mac) for help finding the editor controls.

### Control Do Not Disturb from the moon’s menu

Create two more shortcuts with the **exact names** below. Each uses one **Set Focus** action for **Do Not Disturb**.

| Shortcut name | Set Focus action |
| --- | --- |
| `Hidden Bar Focus – Turn Do Not Disturb On` | Turn Do Not Disturb **On** until turned off. |
| `Hidden Bar Focus – Turn Do Not Disturb Off` | Turn Do Not Disturb **Off**. |

Right-click the moon and choose **Turn Do Not Disturb On** or **Turn Do Not Disturb Off**. The menu shows the action that reverses the last known state. It offers both actions before the first sync. The event shortcuts above report the new state back to Hidden Bar Focus.

To keep just the app’s moon in the menu bar, hide the system Focus indicator in **System Settings → Menu Bar → Focus**. You can still change Do Not Disturb from Control Center. [Apple’s Menu Bar settings guide](https://support.apple.com/guide/mac-help/mchlad96d366/mac)

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| Clicking a control has no visible effect | Check **Accessibility** in **Preferences → General**. Then open both sections and check that the section you want to hide contains an enabled app icon. |
| The arrow is missing | Enable **Always-hidden section** in **Preferences → General**. |
| An app is missing from the Icons list | Start the app and enable its own menu bar icon first. Leave **Icons** open for a few seconds while the list refreshes. macOS controls some system items separately under **System Settings → Menu Bar**. |
| The middle section fails to follow Focus | Check **Follow Do Not Disturb** and both automations. Run the shortcut for the current state to verify that it opens the correct URL, then test by changing Do Not Disturb from Control Center. |
| The moon’s menu cannot turn Do Not Disturb on or off | Run the named **Set Focus** shortcut directly in Shortcuts. Check its exact name and any permission prompts. |
| An enabled icon still disappears | macOS can move icons into overflow on crowded menu bars and can hide some apps launched from outside an Applications folder while Hidden Bar Focus is managing visibility. |

## Test from source

Run this from the repository root on macOS to test section visibility, Do Not Disturb transitions, and the URL parser.

```sh
(
  set -e
  test_binary="$(mktemp)"
  trap 'rm -f "$test_binary"' EXIT
  swiftc FocusBar/Tests/main.swift FocusBar/SectionVisibility.swift \
    hidden/Common/AppDefaults.swift \
    hidden/Features/StatusBar/Layout/MenuBarLayout.swift -o "$test_binary"
  "$test_binary"
)
```
