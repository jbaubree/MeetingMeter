// Tests/MeetingMeterCoreTests/TeamsTitleMatcherTests.swift
import XCTest
@testable import MeetingMeterCore

final class TeamsTitleMatcherTests: XCTestCase {
    func test_english_meetingWith_matches() {
        XCTAssertTrue(TeamsTitleMatcher.isMeetingWindowTitle("Meeting with Alice | Microsoft Teams"))
    }

    func test_english_callWith_matches() {
        XCTAssertTrue(TeamsTitleMatcher.isMeetingWindowTitle("Call with Alice"))
    }

    func test_french_reunionAvec_matches() {
        XCTAssertTrue(TeamsTitleMatcher.isMeetingWindowTitle("Réunion avec Alice | Microsoft Teams"))
    }

    func test_french_appelAvec_matches() {
        XCTAssertTrue(TeamsTitleMatcher.isMeetingWindowTitle("Appel avec Alice"))
    }

    func test_german_besprechung_matches() {
        XCTAssertTrue(TeamsTitleMatcher.isMeetingWindowTitle("Besprechung mit Alice"))
    }

    func test_spanish_reunion_matches() {
        XCTAssertTrue(TeamsTitleMatcher.isMeetingWindowTitle("Reunión con Alice"))
    }

    func test_matchIsCaseInsensitive() {
        XCTAssertTrue(TeamsTitleMatcher.isMeetingWindowTitle("MEETING WITH ALICE"))
    }

    func test_plainTeamsHomeTitle_doesNotMatch() {
        XCTAssertFalse(TeamsTitleMatcher.isMeetingWindowTitle("Microsoft Teams"))
    }

    func test_emptyTitle_doesNotMatch() {
        XCTAssertFalse(TeamsTitleMatcher.isMeetingWindowTitle(""))
    }
}
