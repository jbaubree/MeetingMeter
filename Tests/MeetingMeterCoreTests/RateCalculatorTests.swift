import XCTest
@testable import MeetingMeterCore

final class RateCalculatorTests: XCTestCase {
    func test_cost_basic500EuroPerDay8h() {
        let c = RateCalculator.cost(participants: 7, intervalSeconds: 1, dailyRate: 500, workDayHours: 8)
        XCTAssertEqual(c, 7 * 500.0 / (8.0 * 3600.0), accuracy: 1e-9)
    }

    func test_cost_zeroParticipants_isZero() {
        XCTAssertEqual(
            RateCalculator.cost(participants: 0, intervalSeconds: 60, dailyRate: 500, workDayHours: 8),
            0.0
        )
    }

    func test_cost_zeroInterval_isZero() {
        XCTAssertEqual(
            RateCalculator.cost(participants: 10, intervalSeconds: 0, dailyRate: 500, workDayHours: 8),
            0.0
        )
    }

    func test_cost_zeroWorkDayHours_isZero_asGuard() {
        XCTAssertEqual(
            RateCalculator.cost(participants: 10, intervalSeconds: 60, dailyRate: 500, workDayHours: 0),
            0.0
        )
    }

    func test_cost_longerIntervalScalesLinearly() {
        let a = RateCalculator.cost(participants: 5, intervalSeconds: 1, dailyRate: 400, workDayHours: 8)
        let b = RateCalculator.cost(participants: 5, intervalSeconds: 60, dailyRate: 400, workDayHours: 8)
        XCTAssertEqual(b, 60 * a, accuracy: 1e-9)
    }
}
