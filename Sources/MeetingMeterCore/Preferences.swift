// Sources/MeetingMeterCore/Preferences.swift
import Foundation

public struct Preferences: Codable, Equatable {
    public var dailyRate: Double
    public var workDayHours: Double
    public var currencySymbol: String

    public init(dailyRate: Double, workDayHours: Double, currencySymbol: String) {
        self.dailyRate = dailyRate
        self.workDayHours = workDayHours
        self.currencySymbol = currencySymbol
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.dailyRate = try c.decode(Double.self, forKey: .dailyRate)
        self.workDayHours = try c.decode(Double.self, forKey: .workDayHours)
        self.currencySymbol = try c.decodeIfPresent(String.self, forKey: .currencySymbol) ?? "€"
    }

    public static let defaults = Preferences(dailyRate: 650, workDayHours: 8, currencySymbol: "€")
}
