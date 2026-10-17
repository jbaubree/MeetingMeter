import XCTest
@testable import MeetingMeterCore

final class MeetingHistoryStoreTests: XCTestCase {
    private func makeStore() -> MeetingHistoryStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeetingMeterTests-\(UUID().uuidString)", isDirectory: true)
        return MeetingHistoryStore(directoryURL: dir)
    }

    private func sampleRecord(cost: Double = 10) -> MeetingRecord {
        MeetingRecord(
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: Date(timeIntervalSince1970: 1_700_000_060),
            durationSeconds: 60,
            avgParticipants: 2,
            totalCost: cost,
            dailyRateAtTheTime: 500,
            workDayHoursAtTheTime: 8
        )
    }

    func test_loadAll_whenNoFile_returnsEmpty() {
        let store = makeStore()
        XCTAssertEqual(store.loadAll(), [])
    }

    func test_append_thenLoadAll_returnsOneRecord() {
        let store = makeStore()
        let r = sampleRecord()
        store.append(r)
        XCTAssertEqual(store.loadAll(), [r])
    }

    func test_append_preservesInsertionOrder() {
        let store = makeStore()
        let a = sampleRecord(cost: 10)
        let b = sampleRecord(cost: 20)
        store.append(a)
        store.append(b)
        XCTAssertEqual(store.loadAll().map(\.totalCost), [10, 20])
    }

    func test_clear_removesAll() {
        let store = makeStore()
        store.append(sampleRecord())
        store.clear()
        XCTAssertEqual(store.loadAll(), [])
    }

    func test_corruptFile_returnsEmptyWithoutCrashing() throws {
        let store = makeStore()
        store.append(sampleRecord())
        let url = store.fileURL
        try Data([0xFF, 0xFF]).write(to: url)
        XCTAssertEqual(store.loadAll(), [])
    }
}
