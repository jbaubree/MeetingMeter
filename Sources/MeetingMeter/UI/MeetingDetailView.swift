// Sources/MeetingMeter/UI/MeetingDetailView.swift
import SwiftUI
import MeetingMeterCore

struct MeetingDetailView: View {
    @ObservedObject var session: MeetingSession
    let currencySymbol: String
    let dailyRate: Double

    var body: some View {
        if case .idle = session.state {
            idleContent
        } else {
            activeContent
        }
    }

    private var idleContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Aucune réunion détectée")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text("Lance une réunion Teams pour que le compteur démarre.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }

    private var activeContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(formattedCost)
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .monospacedDigit()
            HStack(spacing: 16) {
                stat(label: "Participants", value: session.lastKnownCount.map(String.init) ?? "—")
                stat(label: "Durée", value: formattedDuration)
            }
            Text("Taux : \(String(format: "%.0f", dailyRate)) \(currencySymbol) / jour")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var formattedCost: String {
        String(format: "%.2f %@", session.cost, currencySymbol)
    }

    private var formattedDuration: String {
        let total = Int(session.elapsedSeconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%dh%02dm%02ds", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    private func stat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 14, weight: .medium)).monospacedDigit()
        }
    }
}
