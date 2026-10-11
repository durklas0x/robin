# Pathlet

A shorter path through Finder. Working name; alternatives: FolderFlow, FinderKit.

Native macOS 14+ SwiftUI utility scaffolded from the local `macos-template` repository. No third-party runtime dependencies.

## Run

Open `Pathlet.xcodeproj`, select the Pathlet scheme, and Run. Or use the template's VS Code build/run tasks. Regenerate with `xcodegen generate` after changing `project.yml`.

On first folder action, grant Automation access to Finder. Terminal actions also require Automation access to Terminal. The host app deliberately runs outside App Sandbox so it can create files and send Apple Events; hardened runtime stays enabled. Configure signing before distribution.

## Implemented starter

- Menu bar actions: New File, Copy Current Folder Path, Open Terminal Here, Open in Editor.
- Main window with selectable/copyable path and manual Refresh.
- Command-Shift-C to copy the current Finder folder while the Pathlet window is focused.
- New File uses a save dialog and refuses to overwrite existing files.
- Editor action lets you select an application; choosing a default editor is a follow-up.
- Finder actions always resolve the front Finder window when invoked. No Finder window or a non-filesystem Finder view produces a visible error in the main window.

## Feature plan

1. **Right-click → New File:** add a signed Finder Sync extension target with a contextual menu for monitored directories. Route requests to the host app, which owns the save dialog and writes. Handle selected directories versus background clicks, external volumes, and iCloud conflicts. Do not assume Finder Sync supplies arbitrary Finder UI changes.
2. **Copyable location bar:** the helper's bar is implemented. Next add a compact floating panel, synchronize it with the active Finder window, and support typed paths. A custom editable bar inside Finder has no supported Finder Sync API.
3. **Back/forward mouse buttons and gestures:** add an isolated input service using a permission-gated event tap, enabled only while Finder is frontmost. Translate configured inputs to Finder's navigation shortcuts; pass through all unrelated events. Design trackpad gesture thresholds, direction, and conflict behavior before enabling interception.
4. **Global copy-path shortcut:** register a configurable system-wide hotkey. The starter's SwiftUI shortcut is local to the window. Show registration conflicts and unregister on shutdown.
5. **Quick terminal/editor actions:** implemented in the helper. Next persist a selected editor, offer terminal selection, and expose actions through the Finder extension.

## Structure

- `Sources/PathletApp.swift`: app scenes and menu bar commands.
- `Sources/ContentView.swift`: location bar and action panel.
- `Sources/FinderActions.swift`: Finder automation, clipboard, safe file creation, Terminal and editor launching.
- `project.yml`: source of truth for the generated Xcode project.

## Verification

Build with:

```sh
xcodebuild -project Pathlet.xcodeproj -scheme Pathlet -configuration Debug -derivedDataPath /tmp/PathletDerivedData CODE_SIGNING_ALLOWED=NO build
```

Manual runtime checks remain: Automation denial/grant, folder paths containing quotes/spaces, no Finder windows, virtual Finder locations, existing-file rejection, editor cancellation, and Terminal launch. The scaffold build alone does not verify macOS permissions or Finder behavior.

## Platform references

- [Apple Finder Sync guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Finder.html)
- [Apple Events entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.automation.apple-events)
