import Testing
@testable import Speak11

struct HotKeyMonitorTests {
    @Test
    func findsFirstKeyCodeProducingTheSpeakCharacter() {
        let result = SpeakKeyCodeResolver.keyCode(for: "a") { keyCode in
            keyCode == 12 ? "a" : nil
        }

        #expect(result == 12)
    }

    @Test
    func findsSwappedKeyOnAzertyStyleLayouts() {
        let result = SpeakKeyCodeResolver.keyCode(for: "a") { keyCode in
            keyCode == 12 ? "a" : (keyCode == 0 ? "q" : nil)
        }

        #expect(result == 12)
    }

    @Test
    func returnsNilWhenLayoutDoesNotProduceTheCharacter() {
        let result = SpeakKeyCodeResolver.keyCode(for: "a") { _ in nil }

        #expect(result == nil)
    }
}
