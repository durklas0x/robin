# Robin

**Finder’s little sidekick.** An editable path bar that follows Finder, plus New File, Copy Folder Path, and quick Terminal/editor actions.

Requires macOS 14+; supports Apple Silicon and Intel.

## Install

```sh
brew install --cask durklas0x/tap/robin
open /Applications/Robin.app
```

Or download the ZIP from [Releases](https://github.com/durklas0x/robin/releases/latest), unzip it, and move `Robin.app` to Applications.

## First launch

Robin is currently ad-hoc signed, **not notarized**. If macOS blocks it, try opening it once, then use **System Settings → Privacy & Security → Open Anyway** ([Apple’s instructions](https://support.apple.com/102445)).

If macOS reports it as damaged or the approval option is unavailable, and you trust this release, remove quarantine from **Robin only**:

```sh
xattr -dr com.apple.quarantine /Applications/Robin.app
open /Applications/Robin.app
```

From Robin’s menu bar icon, open **Finder Extension Settings** and enable **Robin** (macOS may label the sheet File Providers). Allow Finder/Terminal Automation when prompted.

Click the path to edit it; **Return** opens the folder, **Escape** cancels. Right-click a folder or Finder’s background for the extra actions.

## Build / release

Install Xcode 26.2+ and XcodeGen, then:

```sh
xcodegen generate
xcodebuild -project Robin.xcodeproj -scheme Robin -destination 'platform=macOS' -derivedDataPath build CODE_SIGN_IDENTITY=- test
```

Open `Robin.xcodeproj` to run, or use the included VS Code tasks with `xcode-build-server`. Tests belong to the Robin scheme; restart the Swift language server if indexing is stale.

Run the **Release** GitHub Action with a version such as `1.0.1`, or push a `v1.0.1` tag. It tests, builds both architectures, verifies signatures, and publishes a ZIP with its SHA-256 checksum. Update the tap’s cask version and checksum for subsequent releases.
