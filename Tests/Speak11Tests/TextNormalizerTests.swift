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

    @Test
    func verbalizesBareDomainWithPath() {
        #expect(
            TextNormalizer.verbalizingLinks(in: "Visit example.com/path today.")
                == "Visit example dot com slash path today."
        )
    }

    @Test
    func dropsSchemeQueryAndFragment() {
        #expect(
            TextNormalizer.verbalizingLinks(
                in: "See https://example.com/path?q=secret#frag now"
            ) == "See example dot com slash path now"
        )
    }

    @Test
    func preservesTrailingSentencePunctuation() {
        #expect(
            TextNormalizer.verbalizingLinks(in: "Then go.nature.com/4rzrnyx, then stop.")
                == "Then go dot nature dot com slash 4rzrnyx, then stop."
        )
    }

    @Test
    func verbalizesUppercaseDomains() {
        #expect(
            TextNormalizer.verbalizingLinks(in: "Go to EXAMPLE.COM/Path.")
                == "Go to EXAMPLE dot COM slash Path."
        )
    }

    @Test
    func verbalizesPorts() {
        #expect(
            TextNormalizer.verbalizingLinks(in: "Use example.com:8443/secure path")
                == "Use example dot com colon 8443 slash secure path"
        )
    }

    @Test
    func verbalizesExplicitIpUrls() {
        #expect(
            TextNormalizer.verbalizingLinks(in: "Open http://192.168.1.1:8080/admin")
                == "Open 192 dot 168 dot 1 dot 1 colon 8080 slash admin"
        )
    }

    @Test
    func verbalizesUnicodeDomains() {
        #expect(
            TextNormalizer.verbalizingLinks(in: "Site über.example.de/straße works")
                == "Site über dot example dot de slash straße works"
        )
    }

    @Test
    func leavesEmailAddressesUnchanged() {
        #expect(
            TextNormalizer.verbalizingLinks(in: "Mail me at user@example.com please")
                == "Mail me at user@example.com please"
        )
    }

    @Test
    func leavesOrdinaryProseUnchanged() {
        let prose = "e.g. the U.S. version 3.14 is fine. Bare localhost too."

        #expect(TextNormalizer.verbalizingLinks(in: prose) == prose)
    }

    @Test
    func verbalizesUrlsEmbeddedInProse() {
        #expect(
            TextNormalizer.verbalizingLinks(
                in: "Both docs.swift.org/tour and forums.swift.org/latest help."
            ) == "Both docs dot swift dot org slash tour and forums dot swift dot org slash latest help."
        )
    }

    @Test
    func normalizationIsIdempotent() {
        let input = "Visit example.com/path and https://a.io/b?t=1 now."
        let once = TextNormalizer.normalize(input)
        let twice = once.flatMap { TextNormalizer.normalize($0) }

        #expect(once != nil)
        #expect(once == twice)
    }
}
