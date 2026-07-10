import AppKit
import Foundation
import Testing
@testable import Speak11

@MainActor
struct PasteboardSnapshotTests {
    @Test
    func restoresMultipleItemsAndCustomTypes() throws {
        let pasteboard = testPasteboard()
        let customType = NSPasteboard.PasteboardType("com.speak11.test")
        let first = NSPasteboardItem()
        first.setString("original", forType: .string)
        first.setData(Data([1, 2, 3]), forType: customType)
        let second = NSPasteboardItem()
        second.setString("second", forType: .string)
        pasteboard.writeObjects([first, second])
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString("replacement", forType: .string)
        snapshot.restore(to: pasteboard)

        let restored = try #require(pasteboard.pasteboardItems)
        #expect(restored.count == 2)
        #expect(restored[0].string(forType: .string) == "original")
        #expect(restored[0].data(forType: customType) == Data([1, 2, 3]))
        #expect(restored[1].string(forType: .string) == "second")
    }

    @Test
    func restoresAnEmptyPasteboard() {
        let pasteboard = testPasteboard()
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)

        pasteboard.setString("replacement", forType: .string)
        snapshot.restore(to: pasteboard)

        #expect(pasteboard.pasteboardItems?.isEmpty != false)
    }

    @Test
    func detectsConcealedClipboardMarkers() {
        let pasteboard = testPasteboard()
        let item = NSPasteboardItem()
        item.setData(Data(), forType: .init("org.nspasteboard.ConcealedType"))
        pasteboard.writeObjects([item])

        #expect(PasteboardSnapshot(pasteboard: pasteboard).containsSensitiveData)
    }

    private func testPasteboard() -> NSPasteboard {
        let name = NSPasteboard.Name("com.speak11.tests.\(UUID().uuidString)")
        return NSPasteboard(name: name)
    }
}
