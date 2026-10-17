import XCTest
@testable import MeetingMeterCore

final class OCRParticipantParserTests: XCTestCase {
    func test_numberBeforeKeyword_english() {
        XCTAssertEqual(OCRParticipantParser.parseCount(from: "7 participants"), 7)
    }

    func test_numberAfterKeyword_english() {
        XCTAssertEqual(OCRParticipantParser.parseCount(from: "Participants 7"), 7)
    }

    func test_people_singular() {
        XCTAssertEqual(OCRParticipantParser.parseCount(from: "12 people"), 12)
    }

    func test_personnes_french() {
        XCTAssertEqual(OCRParticipantParser.parseCount(from: "4 personnes"), 4)
    }

    func test_teilnehmer_german() {
        XCTAssertEqual(OCRParticipantParser.parseCount(from: "Teilnehmer 15"), 15)
    }

    func test_personas_spanish() {
        XCTAssertEqual(OCRParticipantParser.parseCount(from: "6 Personas"), 6)
    }

    func test_multiline_findsAnywhere() {
        let text = """
        Microsoft Teams
        Reactions
        3 participants
        Chat
        """
        XCTAssertEqual(OCRParticipantParser.parseCount(from: text), 3)
    }

    func test_largeNumberParsed() {
        XCTAssertEqual(OCRParticipantParser.parseCount(from: "154 participants"), 154)
    }

    func test_noKeyword_returnsNil() {
        XCTAssertNil(OCRParticipantParser.parseCount(from: "Microsoft Teams"))
    }

    func test_keywordWithoutNumber_returnsNil() {
        XCTAssertNil(OCRParticipantParser.parseCount(from: "Participants"))
    }

    func test_zeroReturnsNil_notRealistic() {
        XCTAssertEqual(OCRParticipantParser.parseCount(from: "0 participants"), 0)
    }
}
