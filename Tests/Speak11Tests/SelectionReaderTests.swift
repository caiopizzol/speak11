import AppKit
import Foundation
import Testing
@testable import Speak11

@MainActor
struct SelectionReaderTests {
    @Test
    func speaksSnapshotPlainTextWhenEnabled() {
        let pasteboard = testPasteboard()
        pasteboard.setString("copied from tmux", forType: .string)
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)

        #expect(
            SelectionReader.clipboardFallback(isEnabled: true, snapshot: snapshot)
                == "copied from tmux"
        )
    }

    @Test
    func staysSilentWhenDisabled() {
        let pasteboard = testPasteboard()
        pasteboard.setString("copied from tmux", forType: .string)
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)

        #expect(
            SelectionReader.clipboardFallback(isEnabled: false, snapshot: snapshot) == nil
        )
    }

    @Test
    func speaksTheSnapshotNotTheLiveClipboard() {
        let pasteboard = testPasteboard()
        pasteboard.setString("what the user selected", forType: .string)
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString("written by a clipboard manager mid-wait", forType: .string)

        #expect(
            SelectionReader.clipboardFallback(isEnabled: true, snapshot: snapshot)
                == "what the user selected"
        )
    }

    @Test
    func refusesConcealedClipboardContents() {
        let pasteboard = testPasteboard()
        let item = NSPasteboardItem()
        item.setString("hunter2", forType: .string)
        item.setData(Data(), forType: .init("org.nspasteboard.ConcealedType"))
        pasteboard.writeObjects([item])
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)

        #expect(SelectionReader.clipboardFallback(isEnabled: true, snapshot: snapshot) == nil)
    }

    @Test
    func refusesEmptyAndWhitespaceClipboards() {
        let empty = PasteboardSnapshot(pasteboard: testPasteboard())
        #expect(SelectionReader.clipboardFallback(isEnabled: true, snapshot: empty) == nil)

        let blankBoard = testPasteboard()
        blankBoard.setString("  \n ", forType: .string)
        let blank = PasteboardSnapshot(pasteboard: blankBoard)
        #expect(SelectionReader.clipboardFallback(isEnabled: true, snapshot: blank) == nil)
    }

    @Test
    func refusesNonTextClipboards() {
        let pasteboard = testPasteboard()
        let item = NSPasteboardItem()
        item.setData(Data([0xFF, 0xD8]), forType: .init("public.jpeg"))
        pasteboard.writeObjects([item])
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)

        #expect(SelectionReader.clipboardFallback(isEnabled: true, snapshot: snapshot) == nil)
    }

    @Test
    func skipsNonTextItemsToFindPlainText() {
        let pasteboard = testPasteboard()
        let image = NSPasteboardItem()
        image.setData(Data([0xFF, 0xD8]), forType: .init("public.jpeg"))
        let text = NSPasteboardItem()
        text.setString("the actual text", forType: .string)
        pasteboard.writeObjects([image, text])
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)

        #expect(
            SelectionReader.clipboardFallback(isEnabled: true, snapshot: snapshot)
                == "the actual text"
        )
    }

    private func testPasteboard() -> NSPasteboard {
        let name = NSPasteboard.Name("com.speak11.tests.\(UUID().uuidString)")
        return NSPasteboard(name: name)
    }
}
