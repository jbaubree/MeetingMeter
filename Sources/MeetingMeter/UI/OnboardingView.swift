// Sources/MeetingMeter/UI/OnboardingView.swift
import SwiftUI
import AppKit
import ApplicationServices
import CoreGraphics

struct OnboardingView: View {
    @Binding var axGranted: Bool
    @Binding var screenRecGranted: Bool
    var onRecheck: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Autorisations requises").font(.headline)
            permissionRow(
                granted: axGranted,
                label: "Accessibilité",
                description: "Pour lister les fenêtres Teams.",
                settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            )
            permissionRow(
                granted: screenRecGranted,
                label: "Enregistrement d'écran",
                description: "Pour capturer la fenêtre Teams et compter les participants.",
                settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
            )
            HStack {
                Spacer()
                Button("Revérifier") { onRecheck() }
            }
        }
        .padding(16)
        .frame(width: 300)
    }

    @ViewBuilder
    private func permissionRow(granted: Bool, label: String, description: String, settingsURL: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(granted ? .green : .orange)
                Text(label).font(.system(size: 13, weight: .semibold))
                Spacer()
                if !granted {
                    Button("Ouvrir") {
                        if let url = URL(string: settingsURL) { NSWorkspace.shared.open(url) }
                    }
                    .buttonStyle(.borderless)
                }
            }
            Text(description).font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }
}

enum AccessibilityPermission {
    static func isTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }
}

enum ScreenRecordingPermission {
    static func isTrusted() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    static func requestAccess() -> Bool {
        CGRequestScreenCaptureAccess()
    }
}
