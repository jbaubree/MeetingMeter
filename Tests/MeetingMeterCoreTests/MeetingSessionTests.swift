// Tests/MeetingMeterCoreTests/MeetingSessionTests.swift
import XCTest
@testable import MeetingMeterCore

final class MeetingSessionTests: XCTestCase {
    private func session() -> MeetingSession {
        MeetingSession(preferencesProvider: { Preferences(dailyRate: 500, workDayHours: 8, currencySymbol: "€") })
    }

    func test_initialState_isIdle() {
        let s = session()
        if case .idle = s.state { /* ok */ } else { XCTFail("Expected .idle, got \(s.state)") }
        XCTAssertEqual(s.cost, 0)
        XCTAssertEqual(s.elapsedSeconds, 0)
        XCTAssertNil(s.lastKnownCount)
    }

    func test_start_setsStateToInMeeting() {
        let s = session()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        s.start(at: now)
        if case .inMeeting(let startedAt) = s.state {
            XCTAssertEqual(startedAt, now)
        } else {
            XCTFail("Expected .inMeeting, got \(s.state)")
        }
    }

    func test_tick_withoutCount_doesNotIncreaseCost() {
        let s = session()
        s.start(at: Date())
        s.tick(interval: 1)
        s.tick(interval: 1)
        XCTAssertEqual(s.cost, 0)
        XCTAssertEqual(s.elapsedSeconds, 2, accuracy: 1e-9)
    }

    func test_tick_withCount_accumulatesCost() {
        let s = session()
        s.start(at: Date())
        s.updateParticipantCount(5)
        s.tick(interval: 1)
        XCTAssertEqual(s.cost, 5 * 500.0 / (8 * 3600.0), accuracy: 1e-9)
    }

    func test_tick_countChangesMidSession_appliesNewRateFromNextTick() {
        let s = session()
        s.start(at: Date())
        s.updateParticipantCount(5)
        s.tick(interval: 1)
        s.updateParticipantCount(10)
        s.tick(interval: 1)
        let perPersonSec = 500.0 / (8 * 3600.0)
        XCTAssertEqual(s.cost, 15 * perPersonSec, accuracy: 1e-9)
    }

    func test_end_producesRecordWithWeightedAverage() {
        let s = session()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        s.start(at: start)
        s.updateParticipantCount(5)
        s.tick(interval: 10)
        s.updateParticipantCount(15)
        s.tick(interval: 10)
        let end = start.addingTimeInterval(20)
        guard let record = s.end(at: end) else {
            XCTFail("Expected non-nil record")
            return
        }
        XCTAssertEqual(record.durationSeconds, 20, accuracy: 1e-9)
        XCTAssertEqual(record.avgParticipants, 10, accuracy: 1e-9)
        XCTAssertEqual(record.startedAt, start)
        XCTAssertEqual(record.endedAt, end)
    }

    func test_end_whileIdle_returnsNil() {
        let s = session()
        XCTAssertNil(s.end(at: Date()))
    }

    func test_end_resetsStateToIdle() {
        let s = session()
        s.start(at: Date())
        s.updateParticipantCount(3)
        s.tick(interval: 5)
        _ = s.end(at: Date())
        if case .idle = s.state { /* ok */ } else { XCTFail("Expected .idle after end") }
        XCTAssertEqual(s.cost, 0)
        XCTAssertEqual(s.elapsedSeconds, 0)
    }

    func test_lastKnownCount_persistsAfterUpdate() {
        let s = session()
        s.start(at: Date())
        s.updateParticipantCount(7)
        XCTAssertEqual(s.lastKnownCount, 7)
    }
}
