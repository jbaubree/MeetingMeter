// Sources/MeetingMeterCore/PreferencesStore.swift
import Foundation

public final class PreferencesStore {
    public static let storageKey = "com.jbaubree.MeetingMeter.preferences"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> Preferences {
        guard let data = defaults.data(forKey: Self.storageKey) else { return .defaults }
        return (try? JSONDecoder().decode(Preferences.self, from: data)) ?? .defaults
    }

    public func save(_ prefs: Preferences) {
        guard let data = try? JSONEncoder().encode(prefs) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
