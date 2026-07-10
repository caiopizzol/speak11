import AppKit
import Foundation
import Testing
@testable import Speak11

@MainActor
struct SelectionReaderTests {
    @Test
    func readsPlainTextFromTheClipboard() {
        let pasteboard = testPasteboard()
        pasteboard.setString("copied from tmux", forType: .string)

        #expect(SelectionReader.clipboardText(from: pasteboard) == "copied from tmux")
    }

    @Test
    func refusesConcealedClipboardContents() {
        let pasteboard = testPasteboard()
        let item = NSPasteboardItem()
        item.setString("hunter2", forType: .string)
        item.setData(Data(), forType: .init("org.nspasteboard.ConcealedType"))
        pasteboard.writeObjects([item])

        #expect(SelectionReader.clipboardText(from: pasteboard) == nil)
    }

    @Test
    func refusesEmptyAndWhitespaceClipboards() {
        let empty = testPasteboard()
        #expect(SelectionReader.clipboardText(from: empty) == nil)

        let blank = testPasteboard()
        blank.setString("  \n ", forType: .string)
        #expect(SelectionReader.clipboardText(from: blank) == nil)
    }

    @Test
    func refusesNonTextClipboards() {
        let pasteboard = testPasteboard()
        let item = NSPasteboardItem()
        item.setData(Data([0xFF, 0xD8]), forType: .init("public.jpeg"))
        pasteboard.writeObjects([item])

        #expect(SelectionReader.clipboardText(from: pasteboard) == nil)
    }

    private func testPasteboard() -> NSPasteboard {
        let name = NSPasteboard.Name("com.speak11.tests.\(UUID().uuidString)")
        return NSPasteboard(name: name)
    }
}
