import Foundation

public enum OCRParticipantParser {
    /// Keywords (case-insensitive) that identify a participant counter in OCR text.
    /// Includes Teams' "People panel" header labels like "Dans l'appel (N)".
    private static let keywords: [String] = [
        "participants",
        "participant",
        "people",
        "personnes",
        "teilnehmer",
        "personas",
        "l'appel",         // Teams FR: "Dans l'appel (N)"
        "this call",       // Teams EN: "In this call (N)"
        "this meeting",    // Teams EN variant
        "in call",         // Teams EN compact
        "besprechung",     // Teams DE: "In dieser Besprechung (N)"
        "esta llamada",    // Teams ES: "En esta llamada (N)"
        "esta reunión"     // Teams ES variant
    ]

    public static func parseCount(from text: String) -> Int? {
        // Normalize: lowercase + replace parens and separators with spaces so digit extraction treats
        // "Dans l'appel (1)" the same as "Dans l'appel 1".
        var joined = text.lowercased()
        for ch in ["(", ")", "[", "]", "·", "•", ":", "-", "—", "–"] {
            joined = joined.replacingOccurrences(of: ch, with: " ")
        }
        for keyword in keywords {
            guard let keywordRange = joined.range(of: keyword) else { continue }
            if let digits = extractDigitsForward(in: joined, after: keywordRange.upperBound) {
                return digits
            }
            if let digits = extractDigitsBackward(in: joined, before: keywordRange.lowerBound) {
                return digits
            }
        }
        return nil
    }

    private static func extractDigitsBackward(in s: String, before idx: String.Index) -> Int? {
        var cursor = idx
        while cursor > s.startIndex {
            let prev = s.index(before: cursor)
            if s[prev].isWhitespace { cursor = prev } else { break }
        }
        let digitEnd = cursor
        var digitStart = cursor
        while digitStart > s.startIndex {
            let prev = s.index(before: digitStart)
            if s[prev].isNumber { digitStart = prev } else { break }
        }
        guard digitStart < digitEnd else { return nil }
        return Int(s[digitStart..<digitEnd])
    }

    private static func extractDigitsForward(in s: String, after idx: String.Index) -> Int? {
        var cursor = idx
        while cursor < s.endIndex, s[cursor].isWhitespace { cursor = s.index(after: cursor) }
        var digitEnd = cursor
        while digitEnd < s.endIndex, s[digitEnd].isNumber { digitEnd = s.index(after: digitEnd) }
        guard cursor < digitEnd else { return nil }
        return Int(s[cursor..<digitEnd])
    }
}
