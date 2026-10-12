import AppKit
import SwiftUI

@MainActor
final class FinderBarController {
    private let actions: FinderActions
    private var timer: Timer?
    private lazy var panel: NSPanel = {
        let panel = FinderBarPanel(contentRect: .zero,
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

private final class FinderBarPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private extension CGRect {
    var area: CGFloat { isNull ? 0 : width * height }
}

struct FinderBarView: View {
    @ObservedObject var actions: FinderActions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var copied = false
    @State private var copySequence = 0
    @State private var draftPath = ""
    @FocusState private var editingPath: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "folder").foregroundStyle(.secondary)
            TextField("Folder path", text: $draftPath)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($editingPath)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 5)
                .padding(.vertical, 4)
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.primary.opacity(editingPath ? 0.06 : 0))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(Color.accentColor.opacity(editingPath ? 0.6 : 0), lineWidth: 1)
                }
                .help("Edit path · Return to open · Escape to cancel")
                .accessibilityLabel("Folder path")
                .onSubmit {
                    if actions.navigate(to: draftPath) {
                        editingPath = false
                        draftPath = actions.path
                    }
                }
                .onExitCommand {
                    draftPath = actions.path
                    editingPath = false
                }
            Button {
                if actions.copyPath() {
                    copied = true
                    copySequence += 1
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .contentTransition(.opacity)
                    .foregroundStyle(copied ? Color.accentColor : Color.primary)
            }
            .help(copied ? "Path copied" : "Copy folder path")
            .accessibilityLabel(copied ? "Path copied" : "Copy folder path")
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: copied)
            Divider().frame(height: 16).padding(.horizontal, 2)
            Button { actions.newFile() } label: { Image(systemName: "doc.badge.plus") }
                .help("New file").accessibilityLabel("New file")
            Button { actions.openTerminal() } label: { Image(systemName: "terminal") }
                .help("Open Terminal here").accessibilityLabel("Open Terminal here")
            Button { actions.openEditor() } label: { Image(systemName: "curlybraces") }
                .help("Open in editor").accessibilityLabel("Open in editor")
        }
        .buttonStyle(PathActionButtonStyle())
        .padding(.horizontal, 8)
        .frame(height: 40)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator, lineWidth: 0.5))
        .task(id: copySequence) {
            guard copied else { return }
            do { try await Task.sleep(for: .seconds(1.4)) }
            catch { return } // A repeated copy starts a fresh confirmation interval.
            copied = false
        }
        .onAppear { draftPath = actions.path }
        .onChange(of: actions.path) { _, path in
            copied = false
            if !editingPath { draftPath = path }
        }
        .onChange(of: editingPath) { _, editing in
            if !editing { draftPath = actions.path }
        }
    }
}

private struct PathActionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && isEnabled
        let highlighted = hovering && isEnabled
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .frame(width: 28, height: 28)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(pressed ? 0.14 : highlighted ? 0.07 : 0))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.primary.opacity(highlighted ? 0.08 : 0), lineWidth: 0.5)
            }
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(pressed && !reduceMotion ? 0.92 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .onHover { hovering = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: pressed)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: highlighted)
    }
}
