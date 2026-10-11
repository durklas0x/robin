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
- `Sources/FinderActions.swift`: clipboard, safe new-file dialog, Terminal and editor actions. Existing files are never overwritten; action failures display an alert.
- `FinderExtension/FinderSync.swift`: embedded Finder Sync contextual menu.
- `Shared/ActionRequest.swift`: validated and URL-encoded folder requests.
- `FinderExtension/MenuRequestStore.swift`: requests retained in the extension, keyed by menu item tags. Finder does not preserve object metadata on copied menu items. Actions launch the containing app directly.
- `Sources/ContentView.swift`: setup/about panel.
- `project.yml`: XcodeGen source of truth. Regenerate with `xcodegen generate`.

The host is outside App Sandbox to create files and send Apple Events. The extension is sandboxed. Configure development signing for local testing, and Developer ID signing/notarization before distribution. Ad-hoc signing was used for build verification.

## Remaining features

Mouse back/forward, trackpad navigation, a global copy-folder shortcut, and persisted editor/terminal selection are not implemented yet. The earlier main-window copy shortcut was removed along with that window.

## Verification

```sh
xcodebuild -project Pathlet.xcodeproj -scheme Pathlet -configuration Debug -derivedDataPath build CODE_SIGN_IDENTITY=- build
xcrun swiftc Shared/ActionRequest.swift Sources/BarPlacement.swift Tests/SmokeTests.swift -o /tmp/pathlet-smoke
/tmp/pathlet-smoke
```

Verified: host and embedded extension build, path encoding with spaces/quotes/Unicode, invalid action rejection, negative-origin display placement, bottom-edge fallback, and all four menu requests reconstructed from proxy items without representedObject metadata.

Run the menu handoff regression check with:

```sh
xcrun swiftc Shared/ActionRequest.swift FinderExtension/MenuRequestStore.swift Tests/MenuHandoffTests.swift -o /tmp/pathlet-menu-tests
/tmp/pathlet-menu-tests
```

Live bar placement and menus still need checking with Finder foreground, Automation granted, and extension enabled. Also test minimizing, Spaces/fullscreen, cloud locations, cancellation, existing-file rejection, and Automation denial.

## Platform references

- [Apple Finder Sync guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Finder.html)
- [Apple Events entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.automation.apple-events)
