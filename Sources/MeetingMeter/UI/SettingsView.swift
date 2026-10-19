// Sources/MeetingMeter/UI/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @Binding var dailyRate: Double
    @Binding var workDayHours: Double
    @Binding var currencySymbol: String
    var onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paramètres").font(.headline)

            HStack {
                Text("Taux journalier")
                Spacer()
                TextField("650", value: $dailyRate, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                Text(currencySymbol)
            }

            HStack {
                Text("Heures de travail / jour")
                Spacer()
                TextField("8", value: $workDayHours, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
                Text("h")
            }

            HStack {
                Text("Devise")
                Spacer()
                TextField("€", text: $currencySymbol)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
            }

            Divider()

            Button("Réinitialiser", role: .destructive) { onReset() }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)

            Spacer()
        }
        .padding(16)
    }
}
