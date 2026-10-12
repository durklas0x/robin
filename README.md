# Pathlet

A shorter path through Finder. Native macOS 14+ SwiftUI utility built from the local `macos-template`.

## Run and enable

1. Open `Pathlet.xcodeproj` and Run the Pathlet scheme, or use the VS Code Run Pathlet task.
2. Grant Pathlet Automation access to Finder when prompted. The floating bar appears while Finder is frontmost and a filesystem window is visible. Terminal actions request Terminal Automation separately.
3. From the menu bar, choose **Finder Extension Settings…**. Turn on **Pathlet** in the extension sheet and click **Done**. On the tested macOS version, this sheet is labeled **File Providers**. This uses macOS’s Finder Sync management API instead of a generic System Settings link.
4. Right-click a folder or the background of a Finder window for New File, Copy Folder Path, Open Terminal Here, or Open in Editor. The extension forwards the clicked folder to the host app instead of resolving another window.

Building the extension does not enable it. Finder Sync menus can conflict with other extensions monitoring the same folders, especially cloud providers. Current monitoring covers the filesystem root and descendants. Test iCloud and external volumes on the target OS.

## Floating location bar

The compact bar tracks the front Finder window's path and bounds every 400 ms while Finder is active. It is centered 6 points below the window. When there is insufficient room below, it moves inside the window's bottom edge, clamped to the display's visible area. It hides when Finder loses focus, no Finder window is visible, or the location is not a filesystem folder. Paths are selectable, with Copy, New File, Terminal, and Editor buttons.

This is a separate nonactivating panel. Position tracking uses Finder Automation and visible Quartz window bounds. Accessibility access is not needed for this implementation. Fullscreen/Spaces behavior and live multi-display movement need manual verification.

## Structure

- `Sources/FinderBarController.swift`: floating panel and Finder tracking.
- `Sources/BarPlacement.swift`: display-aware geometry.
- `Sources/FinderActions.swift`: clipboard, folder-anchored filename prompt, Terminal and editor actions. Existing files are never overwritten; action failures display an alert.
- `FinderExtension/FinderSync.swift`: embedded Finder Sync contextual menu.
- `Shared/ActionRequest.swift`: validated and URL-encoded folder requests.
- `FinderExtension/MenuRequestStore.swift`: requests retained in the extension, keyed by menu item tags. Finder does not preserve object metadata on copied menu items. Actions launch the containing app directly.
- `Sources/ContentView.swift`: setup/about panel.
- `project.yml`: XcodeGen source of truth. Regenerate with `xcodegen generate`.

The host is outside App Sandbox to create files and send Apple Events. The extension is sandboxed. Configure development signing for local testing, and Developer ID signing/notarization before distribution. Ad-hoc signing was used for build verification.

## Remaining features

Mouse back/forward, trackpad navigation, a global copy-folder shortcut, and persisted editor/terminal selection are not implemented yet. The earlier main-window copy shortcut was removed along with that window.

## Verification

The tests are an XCTest target (`PathletTests`) in the Pathlet scheme, so Xcode and SourceKit can index them. In VS Code, run **Test Pathlet**, or use:

```sh
xcodebuild -project Pathlet.xcodeproj -scheme Pathlet -destination 'platform=macOS' -derivedDataPath build CODE_SIGN_IDENTITY=- test
```

After regenerating the project, refresh the build-server configuration:

```sh
xcode-build-server config -scheme Pathlet -project Pathlet.xcodeproj --build_root build
```

If VS Code still shows stale diagnostics, run **Swift: Restart Language Server**. `buildServer.json` and generated build artifacts are local, ignored files.

Tests cover path encoding, invalid action rejection, display placement, safe filenames, and menu requests surviving Finder's proxy copies. Live verified: copy-path clipboard contents, editor chooser, and New File dialogs. Terminal launched but its working directory was not inspected because the computer-use tool blocks Terminal access.

## Platform references

- [Apple Finder Sync guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Finder.html)
- [Apple Events entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.automation.apple-events)
