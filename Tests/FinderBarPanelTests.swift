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
        XCTAssertEqual(editor.selectedRange.length, 0, "Leaving the bar clears selection")
        XCTAssertFalse(panel.firstResponder is NSText)
    }

    private func textField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField { return field }
        return view.subviews.lazy.compactMap { self.textField(in: $0) }.first
    }
}

private struct TestPathBar: View {
    @State private var path = ""
    @FocusState private var editing: Bool

    var body: some View {
        TextField("Folder path", text: $path)
            .textFieldStyle(.plain)
            .focused($editing)
            .frame(width: 400, height: 40)
            .onAppear { path = "/Users/example/Documents" }
    }
}
