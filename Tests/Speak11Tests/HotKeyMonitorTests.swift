import Testing
@testable import Speak11

struct HotKeyMonitorTests {
    @Test
    func findsFirstSlashKeyCode() {
        let result = SlashKeyCodeResolver.keyCodeForSlash { keyCode in
            keyCode == 12 ? "/" : nil
        }

        #expect(result == 12)
    }

    @Test
    func returnsNilWhenLayoutDoesNotProduceSlash() {
        let result = SlashKeyCodeResolver.keyCodeForSlash { _ in nil }

        #expect(result == nil)
    }
}
