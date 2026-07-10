import Testing
@testable import Speak11

struct TextChunkerTests {
    @Test
    func groupsShortSentencesWithinLimit() {
        let result = TextChunker.chunks(
            from: "First sentence. Second sentence. Third sentence.",
            maximumCharacters: 34
        )

        #expect(result == ["First sentence. Second sentence.", "Third sentence."])
    }

    @Test
    func splitsLongSentenceAtWordBoundaries() {
        let result = TextChunker.chunks(
            from: "one two three four five six",
            maximumCharacters: 13
        )

        #expect(result == ["one two three", "four five six"])
    }

    @Test
    func ignoresWhitespaceOnlyInput() {
        #expect(TextChunker.chunks(from: "   \n  ").isEmpty)
    }
}
