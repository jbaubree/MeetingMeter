// Sources/MeetingMeter/Services/TeamsWindowDetector.swift
import AppKit
import ApplicationServices
import MeetingMeterCore

public final class TeamsWindowDetector {
    public var onUpdate: ((DetectedMeeting?) -> Void)?

    public struct DetectedMeeting: Equatable {
        public let pid: pid_t
        public let title: String
    }

    private let candidateBundleIds = ["com.microsoft.teams2", "com.microsoft.teams"]

    private var observers: [pid_t: AXObserver] = [:]
    private var pollTimer: Timer?

    public init() {
        subscribeWorkspace()
        startPolling()
    }

    deinit {
        pollTimer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        for (_, obs) in observers {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(),
                                  AXObserverGetRunLoopSource(obs),
                                  .defaultMode)
        }
    }

    public func scanNow() {
        let found = findMeetingWindow()
        onUpdate?(found)
        syncObservers()
    }

    private func findMeetingWindow() -> DetectedMeeting? {
        for app in teamsApps() {
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            var value: AnyObject?
            guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
                  let axWindows = value as? [AXUIElement]
            else { continue }
            for axWindow in axWindows {
                var titleRef: AnyObject?
                guard AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef) == .success,
                      let title = titleRef as? String
                else { continue }
                if TeamsTitleMatcher.isMeetingWindowTitle(title) {
                    return DetectedMeeting(pid: app.processIdentifier, title: title)
                }
            }
        }
        return nil
    }

    private func teamsApps() -> [NSRunningApplication] {
        let running = NSWorkspace.shared.runningApplications
        for id in candidateBundleIds {
            let matched = running.filter { $0.bundleIdentifier == id }
            if !matched.isEmpty { return matched }
        }
        return []
    }

    private func subscribeWorkspace() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification,
                       object: nil, queue: .main) { [weak self] _ in self?.scanNow() }
        nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification,
                       object: nil, queue: .main) { [weak self] _ in self?.scanNow() }
    }

    private func syncObservers() {
        let currentPids = Set(teamsApps().map(\.processIdentifier))
        for (pid, obs) in observers where !currentPids.contains(pid) {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(),
                                  AXObserverGetRunLoopSource(obs),
                                  .defaultMode)
            observers.removeValue(forKey: pid)
        }
        for pid in currentPids where observers[pid] == nil {
            installObserver(pid: pid)
        }
    }

    private func installObserver(pid: pid_t) {
        var observer: AXObserver?
        let s = AXObserverCreate(pid, { _, _, _, refcon in
            guard let refcon else { return }
            let detector = Unmanaged<TeamsWindowDetector>.fromOpaque(refcon).takeUnretainedValue()
            DispatchQueue.main.async { detector.scanNow() }
        }, &observer)
        guard s == .success, let observer else { return }
        let axApp = AXUIElementCreateApplication(pid)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        for notif in [kAXWindowCreatedNotification, kAXUIElementDestroyedNotification, kAXTitleChangedNotification] {
            AXObserverAddNotification(observer, axApp, notif as CFString, selfPtr)
        }
        CFRunLoopAddSource(CFRunLoopGetCurrent(),
                          AXObserverGetRunLoopSource(observer),
                          .defaultMode)
        observers[pid] = observer
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.scanNow()
        }
    }
}
