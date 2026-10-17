// Sources/MeetingMeterCore/TeamsTitleMatcher.swift
import Foundation

public enum TeamsTitleMatcher {
    public static let keywords: [String] = [
        "meeting",
        "call",
        "réunion",
        "appel",
        "besprechung",
        "anruf",
        "reunión",
        "llamada"
    ]

    public static func isMeetingWindowTitle(_ title: String) -> Bool {
        guard !title.isEmpty else { return false }
        let lower = title.lowercased()
        return keywords.contains(where: { lower.contains($0) })
    }
}
