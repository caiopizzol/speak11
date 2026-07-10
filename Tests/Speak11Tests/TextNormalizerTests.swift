import Testing
@testable import Speak11

struct TextNormalizerTests {
    @Test
    func rejoinsPdfLineBreaksAndSoftHyphens() {
        let input = "A hyphen-\nated word and a soft\u{00AD}hyphen.\nNext line."

        #expect(
            TextNormalizer.normalize(input)
                == "A hyphenated word and a softhyphen. Next line."
        )
    }

    @Test
    func rejectsEmptyText() {
        #expect(TextNormalizer.normalize(" \n ") == nil)
    }
}
