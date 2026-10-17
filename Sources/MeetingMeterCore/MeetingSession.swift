// Sources/MeetingMeterCore/MeetingSession.swift
import Foundation
import Combine

public final class MeetingSession: ObservableObject {
    public enum State: Equatable {
        case idle
        case inMeeting(startedAt: Date)
    }

    @Published public private(set) var state: State = .idle
    @Published public private(set) var cost: Double = 0
    @Published public private(set) var elapsedSeconds: Double = 0
    @Published public private(set) var lastKnownCount: Int?

    private let preferencesProvider: () -> Preferences
    private var participantSecondsAccumulator: Double = 0

    public init(preferencesProvider: @escaping () -> Preferences) {
        self.preferencesProvider = preferencesProvider
    }

    public func start(at date: Date) {
        state = .inMeeting(startedAt: date)
        cost = 0
        elapsedSeconds = 0
        lastKnownCount = nil
        participantSecondsAccumulator = 0
    }

    public func updateParticipantCount(_ n: Int) {
        lastKnownCount = n
    }

    public func tick(interval: Double) {
        guard case .inMeeting = state else { return }
        elapsedSeconds += interval
        if let n = lastKnownCount {
            let prefs = preferencesProvider()
            cost += RateCalculator.cost(
                participants: n,
                intervalSeconds: interval,
                dailyRate: prefs.dailyRate,
                workDayHours: prefs.workDayHours
            )
            participantSecondsAccumulator += Double(n) * interval
        }
    }

    @discardableResult
    public func end(at date: Date) -> MeetingRecord? {
        guard case .inMeeting(let startedAt) = state else { return nil }
        let prefs = preferencesProvider()
        let avg = elapsedSeconds > 0 ? participantSecondsAccumulator / elapsedSeconds : 0
        let record = MeetingRecord(
            startedAt: startedAt,
            endedAt: date,
            durationSeconds: elapsedSeconds,
            avgParticipants: avg,
            totalCost: cost,
            dailyRateAtTheTime: prefs.dailyRate,
            workDayHoursAtTheTime: prefs.workDayHours
        )
        reset()
        return record
    }

    private func reset() {
        state = .idle
        cost = 0
        elapsedSeconds = 0
        lastKnownCount = nil
        participantSecondsAccumulator = 0
    }
}
