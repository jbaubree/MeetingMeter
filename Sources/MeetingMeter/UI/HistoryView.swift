// Sources/MeetingMeter/UI/HistoryView.swift
import SwiftUI
import MeetingMeterCore

struct HistoryView: View {
    let records: [MeetingRecord]
    let currencySymbol: String
    var onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if records.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                    Text("Pas encore de réunion archivée")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(records.reversed()) { record in
                        row(record)
                    }
                }
                .listStyle(.inset)
            }

            Divider()
            HStack {
                Spacer()
                Button("Effacer l'historique", role: .destructive) { onClear() }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                    .disabled(records.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    private func row(_ r: MeetingRecord) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(dateFormatter.string(from: r.startedAt))
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text(String(format: "%.2f %@", r.totalCost, currencySymbol))
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
            }
            Text("\(Int(r.durationSeconds / 60)) min · \(String(format: "%.1f", r.avgParticipants)) pers")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df
    }
}
