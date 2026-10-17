// Tests/MeetingMeterCoreTests/MeetingRecordTests.swift
import XCTest
@testable import MeetingMeterCore

final class MeetingRecordTests: XCTestCase {
    func test_codable_roundTrip() throws {
        let r = MeetingRecord(
            id: UUID(),
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: Date(timeIntervalSince1970: 1_700_003_600),
            durationSeconds: 3600,
            avgParticipants: 7.5,
            totalCost: 325.0,
            dailyRateAtTheTime: 500,
            workDayHoursAtTheTime: 8
        )
        let data = try JSONEncoder().encode(r)
        let decoded = try JSONDecoder().decode(MeetingRecord.self, from: data)
        XCTAssertEqual(decoded, r)
    }
}
