// Sources/MeetingMeterCore/MeetingRecord.swift
import Foundation

public struct MeetingRecord: Codable, Equatable, Identifiable {
    public let id: UUID
    public let startedAt: Date
    public let endedAt: Date
    public let durationSeconds: Double
    public let avgParticipants: Double
    public let totalCost: Double
    public let dailyRateAtTheTime: Double
    public let workDayHoursAtTheTime: Double

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        durationSeconds: Double,
        avgParticipants: Double,
        totalCost: Double,
        dailyRateAtTheTime: Double,
        workDayHoursAtTheTime: Double
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
        self.avgParticipants = avgParticipants
        self.totalCost = totalCost
        self.dailyRateAtTheTime = dailyRateAtTheTime
        self.workDayHoursAtTheTime = workDayHoursAtTheTime
    }
}
