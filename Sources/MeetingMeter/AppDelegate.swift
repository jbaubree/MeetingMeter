// Sources/MeetingMeter/AppDelegate.swift
import AppKit
import SwiftUI
import MeetingMeterCore

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {

    private let preferencesStore = PreferencesStore()
    private let historyStore = MeetingHistoryStore()
    private let detector = TeamsWindowDetector()
    private let capture = ScreenCaptureService()
    private let ocr = OCRService()
    private let notifications = NotificationService()

    private var prefs: Preferences
    private lazy var session = MeetingSession(preferencesProvider: { [weak self] in
        self?.prefs ?? .defaults
    })

    private var currentDetection: TeamsWindowDetector.DetectedMeeting?
    private var history: [MeetingRecord] = []
    private var menuBar: MenuBarController?
    private var tickTimer: Timer?
    private var ocrInFlight = false

    override init() {
        self.prefs = PreferencesStore().load()
        super.init()
        self.history = historyStore.loadAll()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        _ = AccessibilityPermission.isTrusted(prompt: true)
        _ = ScreenRecordingPermission.requestAccess()
        notifications.requestAuthorizationIfNeeded()

        detector.onUpdate = { [weak self] found in self?.handleDetection(found) }
        detector.scanNow()

        let root = PopoverRootView(
            session: session,
            dailyRate: Binding(
                get: { self.prefs.dailyRate },
                set: { newValue in
                    self.prefs.dailyRate = newValue
                    self.preferencesStore.save(self.prefs)
                    self.updateMenuBarLabel()
                }
            ),
            workDayHours: Binding(
                get: { self.prefs.workDayHours },
                set: { newValue in
                    self.prefs.workDayHours = newValue
                    self.preferencesStore.save(self.prefs)
                }
            ),
            currencySymbol: Binding(
                get: { self.prefs.currencySymbol },
                set: { newValue in
                    self.prefs.currencySymbol = newValue
                    self.preferencesStore.save(self.prefs)
                    self.updateMenuBarLabel()
                }
            ),
            history: history,
            onResetSettings: { [weak self] in self?.resetSettings() },
            onClearHistory: { [weak self] in self?.clearHistory() },
            onQuit: { NSApp.terminate(nil) }
        )
        menuBar = MenuBarController(rootView: AnyView(root))
        updateMenuBarLabel()

        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.onTick()
        }
    }

    // MARK: - Detection

    private func handleDetection(_ found: TeamsWindowDetector.DetectedMeeting?) {
        switch (currentDetection, found) {
        case (nil, .some(let m)):
            currentDetection = m
            session.start(at: Date())
        case (.some, nil):
            if let record = session.end(at: Date()) {
                history.append(record)
                historyStore.append(record)
                notifications.postMeetingEnded(
                    totalCost: record.totalCost,
                    currency: prefs.currencySymbol,
                    durationSeconds: record.durationSeconds
                )
            }
            currentDetection = nil
        default:
            break
        }
        updateMenuBarLabel()
    }

    // MARK: - Tick (every second)

    private func onTick() {
        guard case .inMeeting = session.state else { return }
        session.tick(interval: 1)
        // Fallback: Teams doesn't display a participant counter when alone in the meeting.
        // After 10s without an OCR hit, assume 1 participant (yourself) so the counter starts ticking.
        if session.lastKnownCount == nil && session.elapsedSeconds >= 10 {
            session.updateParticipantCount(1)
        }
        updateMenuBarLabel()
        runOCRIfIdle()
    }

    private func runOCRIfIdle() {
        guard !ocrInFlight, let m = currentDetection else { return }
        ocrInFlight = true
        Task { [weak self] in
            defer { Task { @MainActor in self?.ocrInFlight = false } }
            do {
                let image = try await self?.capture.captureWindow(for: m.pid)
                guard let image else { return }
                let count = try await self?.ocr.recognizeParticipantCount(from: image)
                if let count, count > 0 {
                    await MainActor.run { self?.session.updateParticipantCount(count) }
                }
            } catch {
                // Ignore; keep lastKnownCount.
            }
        }
    }

    // MARK: - Menu bar label

    private func updateMenuBarLabel() {
        guard case .inMeeting = session.state else {
            menuBar?.updateLabel("")
            return
        }
        if session.lastKnownCount == nil {
            menuBar?.updateLabel("— " + prefs.currencySymbol)
        } else {
            menuBar?.updateLabel(String(format: "%.2f %@", session.cost, prefs.currencySymbol))
        }
    }

    // MARK: - Preferences

    private func resetSettings() {
        prefs = .defaults
        preferencesStore.save(prefs)
        updateMenuBarLabel()
    }

    private func clearHistory() {
        history.removeAll()
        historyStore.clear()
    }
}
