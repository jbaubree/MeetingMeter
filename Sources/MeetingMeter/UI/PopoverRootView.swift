// Sources/MeetingMeter/UI/PopoverRootView.swift
import SwiftUI
import MeetingMeterCore

struct PopoverRootView: View {
    @ObservedObject var session: MeetingSession
    @State private var tab: Tab = .meeting
    @State private var axGranted: Bool = AccessibilityPermission.isTrusted(prompt: false)
    @State private var screenRecGranted: Bool = ScreenRecordingPermission.isTrusted()

    @Binding var dailyRate: Double
    @Binding var workDayHours: Double
    @Binding var currencySymbol: String
    let history: [MeetingRecord]
    let onResetSettings: () -> Void
    let onClearHistory: () -> Void
    let onQuit: () -> Void

    enum Tab { case meeting, settings, history }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if !axGranted || !screenRecGranted {
                OnboardingView(
                    axGranted: $axGranted,
                    screenRecGranted: $screenRecGranted,
                    onRecheck: {
                        axGranted = AccessibilityPermission.isTrusted(prompt: true)
                        _ = ScreenRecordingPermission.requestAccess()
                        screenRecGranted = ScreenRecordingPermission.isTrusted()
                    }
                )
            } else {
                content
            }
            Divider()
            footer
        }
        .frame(width: 320, height: 420)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .meeting:
            MeetingDetailView(session: session, currencySymbol: currencySymbol, dailyRate: dailyRate)
        case .settings:
            SettingsView(
                dailyRate: $dailyRate,
                workDayHours: $workDayHours,
                currencySymbol: $currencySymbol,
                onReset: onResetSettings
            )
        case .history:
            HistoryView(records: history, currencySymbol: currencySymbol, onClear: onClearHistory)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("MeetingMeter").font(.system(size: 13, weight: .semibold))
            Spacer()
            tabButton(.meeting, systemImage: "timer")
            tabButton(.history, systemImage: "clock")
            tabButton(.settings, systemImage: "gearshape")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func tabButton(_ t: Tab, systemImage: String) -> some View {
        Button(action: { tab = t }) {
            Image(systemName: systemImage)
                .foregroundStyle(tab == t ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.borderless)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(action: onQuit) {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
