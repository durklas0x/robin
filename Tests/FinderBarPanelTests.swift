import AppKit
import SwiftUI
import XCTest

@MainActor
final class FinderBarPanelTests: XCTestCase {
    func testInitialDisplayDoesNotSelectPathButExplicitEditingWorks() throws {
        let panel = FinderBarPanel(contentRect: .zero,
                                   styleMask: [.borderless, .nonactivatingPanel],
                                   backing: .buffered, defer: false)
        defer { panel.orderOut(nil) }
        panel.contentView = NSHostingView(rootView: TestPathBar())
        panel.setFrame(NSRect(x: 100, y: 100, width: 400, height: 40), display: true)
        panel.makeKeyAndOrderFront(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        XCTAssertFalse(panel.firstResponder is NSText, "Showing the bar must not start editing or select the path")
        let field = try XCTUnwrap(textField(in: try XCTUnwrap(panel.contentView)))
        XCTAssertTrue(panel.makeFirstResponder(field), "The path must remain editable")
        let editor = try XCTUnwrap(field.currentEditor())
        editor.selectedRange = NSRange(location: 0, length: field.stringValue.utf16.count)
        XCTAssertGreaterThan(editor.selectedRange.length, 0)

        panel.resignKey()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(editor.selectedRange.length, 0, "Leaving the bar clears selection")
        XCTAssertFalse(panel.firstResponder is NSText)
    }

    func testSelectingPathSurvivesAViewRefreshBeforeTyping() throws {
        let panel = FinderBarPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                                   backing: .buffered, defer: false)
        defer { panel.orderOut(nil) }
        let state = PathFieldTestState()
        panel.contentView = NSHostingView(rootView: RefreshingPathBar(state: state))
        panel.setFrame(NSRect(x: 100, y: 100, width: 400, height: 40), display: true)
        panel.makeKeyAndOrderFront(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        let field = try XCTUnwrap(textField(in: try XCTUnwrap(panel.contentView)))
        XCTAssertTrue(panel.makeFirstResponder(field))
        let editor = try XCTUnwrap(field.currentEditor())
        editor.selectedRange = NSRange(location: 0, length: field.stringValue.utf16.count)
        state.refresh += 1
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertTrue(state.editing, "Focus starts when selecting the path, before any text changes")
        XCTAssertNotNil(field.currentEditor(), "Polling must not end editing")
        XCTAssertEqual(editor.selectedRange.length, field.stringValue.utf16.count)
    }

    func testNativeEditorCompletesWholeFolderPaths() throws {
        let panel = FinderBarPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                                   backing: .buffered, defer: false)
        defer { panel.orderOut(nil) }
        panel.contentView = NSHostingView(rootView: TestPathBar())
        panel.setFrame(NSRect(x: 100, y: 100, width: 400, height: 40), display: true)
        panel.makeKeyAndOrderFront(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        let field = try XCTUnwrap(textField(in: try XCTUnwrap(panel.contentView)))
        XCTAssertTrue(panel.makeFirstResponder(field))
        let editor = try XCTUnwrap(field.currentEditor() as? FolderPathEditor)
        editor.string = "/private/tm"
        editor.setSelectedRange(NSRange(location: editor.string.utf16.count, length: 0))
        XCTAssertEqual(editor.rangeForUserCompletion, NSRange(location: 0, length: 11))
        var selected = 0
        let completions = editor.completions(forPartialWordRange: editor.rangeForUserCompletion,
                                            indexOfSelectedItem: &selected)
        XCTAssertEqual(completions, ["/private/tmp/"])
        XCTAssertEqual(selected, 0)
        editor.complete(nil)
        XCTAssertEqual(editor.string, "/private/tmp/", "Tab completion must insert a real folder path")
    }

    func testCompletionCanCommitAfterTemporaryKeyLoss() throws {
        let panel = FinderBarPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                                   backing: .buffered, defer: false)
        defer { panel.orderOut(nil) }
        let state = PathFieldTestState()
        panel.contentView = NSHostingView(rootView: RefreshingPathBar(state: state))
        panel.setFrame(NSRect(x: 100, y: 100, width: 400, height: 40), display: true)
        panel.makeKeyAndOrderFront(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        let field = try XCTUnwrap(textField(in: try XCTUnwrap(panel.contentView)))
        XCTAssertTrue(panel.makeFirstResponder(field))
        let editor = try XCTUnwrap(field.currentEditor() as? FolderPathEditor)
        editor.string = "/private/t"
        editor.setSelectedRange(NSRange(location: 10, length: 0))
        let coordinator = try XCTUnwrap(field.delegate as? FolderPathField.Coordinator)
        panel.beginCompletionTracking()
        panel.resignKey()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertNotNil(field.currentEditor(), "Clicking the completion list must not discard the editor")
        coordinator.applyCompletion("/private/tmp/", in: field, range: NSRange(location: 0, length: editor.string.utf16.count))
        panel.endCompletionTracking()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(editor.string, "/private/tmp/")
        XCTAssertEqual(state.text, "/private/tmp/")
        XCTAssertTrue(state.editing)
        panel.resignKey()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertNil(field.currentEditor(), "Actual focus loss still ends editing")
    }

    private func textField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField { return field }
        return view.subviews.lazy.compactMap { self.textField(in: $0) }.first
    }
}

private struct TestPathBar: View {
    @State private var path = ""
    @State private var editing = false

    var body: some View {
        FolderPathField(text: $path, editing: $editing, base: URL(fileURLWithPath: "/Users"),
                        onSubmit: { editing = false }, onCancel: { editing = false })
            .frame(width: 400, height: 40)
            .onAppear { path = "/Users/example/Documents" }
    }
}

@MainActor
private final class PathFieldTestState: ObservableObject {
    @Published var text = "/private/tmp"
    @Published var editing = false
    @Published var refresh = 0
}

private struct RefreshingPathBar: View {
    @ObservedObject var state: PathFieldTestState
    var body: some View {
        FolderPathField(text: $state.text, editing: $state.editing,
                        base: URL(fileURLWithPath: "/private/tmp"),
                        onSubmit: { state.editing = false }, onCancel: { state.editing = false })
            .frame(width: CGFloat(400 + state.refresh % 2), height: 40)
    }
}
