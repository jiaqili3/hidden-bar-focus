# Hidden Bar Focus

Organize your macOS menu bar with two independent controls. Hide a group of icons with a click, hide specific apps from every section, or let the middle section follow Do Not Disturb.

## How the menu bar works

```text
Left section    [ < / > ]    Middle section    [ Moon ]    Right section
```

| Section | What to do |
| --- | --- |
| Left of the arrow | Click the arrow to show or hide this section. The default arrow reads `<` when hidden and `>` when shown. |
| Between the arrow and the moon | Click the moon to show or hide this section. The moon is filled when the section is hidden and outlined when it is shown. |
| Right of the moon | Enabled app icons stay visible when you close either section. |

Open both sections, then hold **⌘ Command** and drag your icons into place. To hide a specific app even when both sections are open, right-click either control and go to **Preferences → Icons → Menu bar icons**. Turn the app’s switch off.

## Build and install

Use **macOS 27** with Apple’s Command Line Tools for Xcode installed. Run `xcode-select --install` if you need the tools.

```sh
git clone https://github.com/jiaqili3/hidden-bar-focus.git
cd hidden-bar-focus
./FocusBar/build.sh ./build/focus
```

Copy **Hidden Bar Focus.app** from `build/focus` to **Applications**. Quit any running copy of the original Hidden Bar, open **Hidden Bar Focus** from Applications, and enable it in **System Settings → Privacy & Security → Accessibility**. To start it automatically, turn on **Preferences → General → Open Hidden Bar at login**.

Manual controls work without Shortcuts. To make the middle section follow your Mac’s Do Not Disturb state or control Do Not Disturb from the moon’s menu, see the [Shortcuts setup](FocusBar/README.md#do-not-disturb). The [full guide](FocusBar/README.md) also covers upgrades and troubleshooting.

## Project and license

Hidden Bar Focus is a fork of [Console Labs’ Hidden Bar 1.13.1](https://github.com/consolelabs/hidden/tree/v1.13.1). It uses the original preferences window and macOS 27 visibility engine. The inherited [manual](docs/MANUAL.md), [architecture notes](docs/ARCHITECTURE.md), and [maintainer runbook](docs/RUNBOOK.md) describe the upstream app.

Licensed under the [MIT License](LICENSE). Copyright © 2019 Dwarves Foundation and © 2026 Console Labs.
