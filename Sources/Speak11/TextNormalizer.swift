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
        let result = normalizedLines.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }
}
