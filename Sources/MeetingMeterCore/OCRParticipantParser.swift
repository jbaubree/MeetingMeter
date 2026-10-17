import Foundation

public enum OCRParticipantParser {
    private static let keywords: [String] = [
        "participants",
        "participant",
        "people",
        "personnes",
        "teilnehmer",
        "personas"
    ]

    public static func parseCount(from text: String) -> Int? {
        let joined = text.lowercased()
        for keyword in keywords {
            guard let keywordRange = joined.range(of: keyword) else { continue }
            if let digits = extractDigitsBackward(in: joined, before: keywordRange.lowerBound) {
                return digits
            }
            if let digits = extractDigitsForward(in: joined, after: keywordRange.upperBound) {
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
