import Foundation

/// Accent words. The Highlight menu and the renderer share this tokenizer, so a word the menu shows
/// as highlighted is exactly the word the renderer colors. Words are whitespace-separated tokens with
/// leading and trailing punctuation trimmed, so "Wi-Fi", "24/7", and "All-in-one" stay whole.
enum Highlight {
    struct Word { var text: String; var highlighted: Bool }

    /// The core of each token (punctuation trimmed, *asterisks* kept) and its range in `text`.
    static func cores(in text: String) -> [(core: String, range: Range<String.Index>)] {
        var result: [(String, Range<String.Index>)] = []
        var index = text.startIndex
        while index < text.endIndex {
            while index < text.endIndex, text[index].isWhitespace { index = text.index(after: index) }
            let tokenStart = index
            while index < text.endIndex, !text[index].isWhitespace { index = text.index(after: index) }
            guard tokenStart < index else { continue }
            var start = tokenStart, end = index
            func keeps(_ c: Character) -> Bool { c.isLetter || c.isNumber || c == "*" }
            while start < end, !keeps(text[start]) { start = text.index(after: start) }
            while end > start, !keeps(text[text.index(before: end)]) { end = text.index(before: end) }
            if start < end { result.append((String(text[start..<end]), start..<end)) }
        }
        return result
    }

    private static func bare(_ core: String) -> String { core.replacingOccurrences(of: "*", with: "") }
    private static func isMarked(_ core: String) -> Bool { core.count > 1 && core.hasPrefix("*") && core.hasSuffix("*") }

    static func words(in headline: String) -> [Word] {
        cores(in: headline).compactMap { item in
            let text = bare(item.core)
            return text.isEmpty ? nil : Word(text: text, highlighted: isMarked(item.core))
        }
    }

    /// Wraps or unwraps typed *markup* on the word at `index` (counting words as `words(in:)` does).
    static func toggle(_ index: Int, in headline: String) -> String {
        let items = cores(in: headline).filter { !bare($0.core).isEmpty }
        guard items.indices.contains(index) else { return headline }
        let item = items[index]
        var output = headline
        output.replaceSubrange(item.range, with: isMarked(item.core) ? bare(item.core) : "*\(bare(item.core))*")
        return output
    }

    /// Ranges in already-unmarked `text` whose word matches a stored accent, ignoring case.
    static func accentRanges(in text: String, accents: [String]) -> [Range<String.Index>] {
        let wanted = Set(accents.map { $0.lowercased() })
        guard !wanted.isEmpty else { return [] }
        return cores(in: text).filter { wanted.contains(bare($0.core).lowercased()) }.map(\.range)
    }
}
