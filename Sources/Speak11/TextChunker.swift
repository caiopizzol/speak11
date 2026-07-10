import Foundation
import NaturalLanguage

enum TextChunker {
    static func chunks(from text: String, maximumCharacters: Int = 320) -> [String] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
            return true
        }

        if sentences.isEmpty {
            sentences = [text]
        }

        var result: [String] = []
        var pending = ""
        for sentence in sentences.flatMap({ splitLongText($0, limit: maximumCharacters) }) {
            let combined = pending.isEmpty ? sentence : "\(pending) \(sentence)"
            if combined.count <= maximumCharacters {
                pending = combined
            } else {
                if !pending.isEmpty { result.append(pending) }
                pending = sentence
            }
        }
        if !pending.isEmpty { result.append(pending) }
        return result
    }

    private static func splitLongText(_ text: String, limit: Int) -> [String] {
        guard text.count > limit else { return [text] }

        var chunks: [String] = []
        var current = ""
        for word in text.split(whereSeparator: { $0.isWhitespace }).map(String.init) {
            let candidate = current.isEmpty ? word : "\(current) \(word)"
            if candidate.count <= limit || current.isEmpty {
                current = candidate
            } else {
                chunks.append(current)
                current = word
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }
}
