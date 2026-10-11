import AppKit
import SwiftUI

@MainActor
final class FinderBarController {
    private let actions: FinderActions
    private var timer: Timer?
    private lazy var panel: NSPanel = {
        let panel = NSPanel(contentRect: .zero,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: FinderBarView(actions: actions))
        return panel
    }()

    init(actions: FinderActions) { self.actions = actions }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.update() }
        }
        update()
    }

    func update() {
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder",
              let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]],
              windows.contains(where: {
                  ($0[kCGWindowOwnerPID as String] as? Int) == Int(finder.processIdentifier) &&
                  ($0[kCGWindowLayer as String] as? Int) == 0
              }),
              let snapshot = snapshot(),
              windows.contains(where: { entry in
                  guard (entry[kCGWindowOwnerPID as String] as? Int) == Int(finder.processIdentifier),
                        (entry[kCGWindowLayer as String] as? Int) == 0,
                        let dictionary = entry[kCGWindowBounds as String] as? [String: Any],
                        let bounds = CGRect(dictionaryRepresentation: dictionary as CFDictionary) else { return false }
                  return abs(bounds.minX - snapshot.bounds.minX) < 3 &&
                         abs(bounds.minY - snapshot.bounds.minY) < 3 &&
                         abs(bounds.width - snapshot.bounds.width) < 3 &&
                         abs(bounds.height - snapshot.bounds.height) < 3
              }),
              let mainScreen = NSScreen.screens.first else {
            panel.orderOut(nil)
            return
        }
        // AppleScript/Quartz coordinates originate at the primary display's top-left.
        let frame = CGRect(x: snapshot.bounds.minX,
                           y: mainScreen.frame.maxY - snapshot.bounds.maxY,
                           width: snapshot.bounds.width, height: snapshot.bounds.height)
        guard let screen = NSScreen.screens.max(by: {
            $0.frame.intersection(frame).area < $1.frame.intersection(frame).area
        }), screen.frame.intersects(frame) else { panel.orderOut(nil); return }
        actions.path = snapshot.folder.path
        panel.setFrame(BarPlacement.frame(below: frame, visibleFrame: screen.visibleFrame), display: true)
        panel.orderFrontRegardless()
    }

    private func snapshot() -> (folder: URL, bounds: CGRect)? {
        let source = """
        tell application "Finder"
            if (count of Finder windows) is 0 then return {}
            set w to front Finder window
            return {POSIX path of (target of w as alias), bounds of w}
        end tell
        """
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let result = script.executeAndReturnError(&error)
        guard error == nil, result.numberOfItems == 2,
              let path = result.atIndex(1)?.stringValue,
              let bounds = result.atIndex(2), bounds.numberOfItems == 4 else { return nil }
        let x = CGFloat(bounds.atIndex(1)!.int32Value)
        let y = CGFloat(bounds.atIndex(2)!.int32Value)
        let right = CGFloat(bounds.atIndex(3)!.int32Value)
        let bottom = CGFloat(bounds.atIndex(4)!.int32Value)
        return (URL(fileURLWithPath: path, isDirectory: true),
                CGRect(x: x, y: y, width: right - x, height: bottom - y))
    }
}

private extension CGRect {
    var area: CGFloat { isNull ? 0 : width * height }
}

struct FinderBarView: View {
    @ObservedObject var actions: FinderActions
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder").foregroundStyle(.secondary)
            Text(actions.path).lineLimit(1).truncationMode(.middle)
                .textSelection(.enabled).font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(actions.path)
            Button { actions.copyPath() } label: { Image(systemName: "doc.on.doc") }
                .help("Copy folder path").accessibilityLabel("Copy folder path")
            Divider().frame(height: 16)
            Button { actions.newFile() } label: { Image(systemName: "doc.badge.plus") }
                .help("New file").accessibilityLabel("New file")
            Button { actions.openTerminal() } label: { Image(systemName: "terminal") }
                .help("Open Terminal here").accessibilityLabel("Open Terminal here")
            Button { actions.openEditor() } label: { Image(systemName: "curlybraces") }
                .help("Open in editor").accessibilityLabel("Open in editor")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator, lineWidth: 0.5))
    }
}
