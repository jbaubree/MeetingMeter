import Foundation

public enum RateCalculator {
    public static func cost(
        participants: Int,
        intervalSeconds: Double,
        dailyRate: Double,
        workDayHours: Double
    ) -> Double {
        guard workDayHours > 0 else { return 0 }
        let perPersonPerSecond = dailyRate / (workDayHours * 3600.0)
        return Double(participants) * perPersonPerSecond * intervalSeconds
    }
}
