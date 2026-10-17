// Tests/MeetingMeterCoreTests/PreferencesTests.swift
import XCTest
@testable import MeetingMeterCore

final class PreferencesTests: XCTestCase {
    private func makeStore() -> (PreferencesStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        return (PreferencesStore(defaults: defaults), defaults)
    }

    func test_load_returnsDefaultsWhenEmpty() {
        let (store, _) = makeStore()
        let prefs = store.load()
        XCTAssertEqual(prefs.dailyRate, 500)
        XCTAssertEqual(prefs.workDayHours, 8)
        XCTAssertEqual(prefs.currencySymbol, "€")
    }

    func test_save_thenLoad_roundTrips() {
        let (store, _) = makeStore()
        var prefs = Preferences.defaults
        prefs.dailyRate = 750
        prefs.workDayHours = 7.5
        prefs.currencySymbol = "$"
        store.save(prefs)

        XCTAssertEqual(store.load(), prefs)
    }

    func test_load_fallsBackToDefaultsOnCorruptData() {
        let (store, defaults) = makeStore()
        defaults.set(Data([0xFF, 0xFF]), forKey: PreferencesStore.storageKey)
        XCTAssertEqual(store.load(), .defaults)
    }

    func test_load_defaultsCurrencyToEuroWhenMissingFromStoredData() throws {
        let (store, defaults) = makeStore()
        let legacy: [String: Any] = ["dailyRate": 400.0, "workDayHours": 8.0]
        let data = try JSONSerialization.data(withJSONObject: legacy)
        defaults.set(data, forKey: PreferencesStore.storageKey)
        XCTAssertEqual(store.load().currencySymbol, "€")
    }
}
