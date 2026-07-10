import Foundation

enum TextNormalizer {
    static func normalize(_ text: String) -> String? {
        let withoutSoftHyphens = text.replacingOccurrences(of: "\u{00AD}", with: "")
        let rejoinedWords = withoutSoftHyphens.replacingOccurrences(
            of: #"(?<=\p{L})-\s*\n\s*(?=\p{Ll})"#,
            with: "",
            options: .regularExpression
        )
        let normalizedLines = rejoinedWords.replacingOccurrences(
            of: #"(?<!\n)\n(?!\n)"#,
            with: " ",
            options: .regularExpression
        )
        let spokenLinks = verbalizingLinks(in: normalizedLines)
        let result = spokenLinks.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    // Local TTS reads "example.com/path" as a garbled word; speak the
    // separators instead. Query strings, fragments, and user-info are
    // dropped because they commonly carry credentials or tracking values;
    // secrets embedded in the path itself are still spoken.
    static func verbalizingLinks(in text: String) -> String {
        guard
            let detector = try? NSDataDetector(
                types: NSTextCheckingResult.CheckingType.link.rawValue
            )
        else {
            return text
        }

        let nsText = text as NSString
        let matches = detector.matches(
            in: text,
            range: NSRange(location: 0, length: nsText.length)
        )

        var result = text
        for match in matches.reversed() {
            guard match.url?.scheme != "mailto" else { continue }
            guard let range = Range(match.range, in: result) else { continue }
            let spoken = spokenForm(of: String(result[range]))
            result.replaceSubrange(range, with: spoken)
        }
        return result
    }

    private static func spokenForm(of link: String) -> String {
        var remainder = link
        if let schemeEnd = remainder.range(of: "://") {
            remainder = String(remainder[schemeEnd.upperBound...])
        }
        remainder = String(remainder.prefix { $0 != "?" && $0 != "#" })
        let authorityEnd = remainder.firstIndex(of: "/") ?? remainder.endIndex
        if let userInfoEnd = remainder[..<authorityEnd].lastIndex(of: "@") {
            remainder = String(remainder[remainder.index(after: userInfoEnd)...])
        }
        return remainder
            .replacingOccurrences(of: "/", with: " slash ")
            .replacingOccurrences(of: ".", with: " dot ")
            .replacingOccurrences(of: ":", with: " colon ")
            .replacingOccurrences(
                of: #"\s{2,}"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespaces)
    }
}
