# MeetingMeter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a menu-bar macOS app that detects Microsoft Teams meetings, OCRs the participant count from the Teams window, and displays a live cost counter ticking every second.

**Architecture:** Swift native, AppKit shell with SwiftUI popover. Core domain logic (session state, cost math, title/OCR parsers, persistence) lives in a testable framework target. The executable target holds the side-effect glue: AX API, ScreenCaptureKit, Vision OCR, Carbon-free timers, menu bar.

**Tech Stack:** Swift 5.9+, macOS 14+ (Sonoma), AppKit + SwiftUI, Accessibility API (window ops), ScreenCaptureKit (`SCScreenshotManager`), Vision (`VNRecognizeTextRequest`), UserNotifications, ServiceManagement, XcodeGen, XCTest.

**Spec:** `docs/superpowers/specs/2026-10-17-meeting-meter-design.md`

**Prerequisites:**
- Xcode 15+ installed
- `brew install xcodegen`
- Teams installed and able to join a test meeting (needed for manual smoke tests from Task 8 onward)

---

## File Structure

XcodeGen generates `.xcodeproj` from `project.yml`. Two targets + tests target:

- **MeetingMeterCore** (framework) — pure/testable domain
- **MeetingMeter** (`.app`) — AppKit/SwiftUI wiring and system services
- **MeetingMeterCoreTests** (unit tests)

```
MeetingMeter/
├── project.yml
├── Sources/
│   ├── MeetingMeterCore/
│   │   ├── RateCalculator.swift
│   │   ├── TeamsTitleMatcher.swift
│   │   ├── OCRParticipantParser.swift
│   │   ├── Preferences.swift
│   │   ├── PreferencesStore.swift
│   │   ├── MeetingRecord.swift
│   │   ├── MeetingHistoryStore.swift
│   │   └── MeetingSession.swift
│   └── MeetingMeter/
│       ├── MeetingMeterApp.swift
│       ├── AppDelegate.swift
│       ├── Services/
│       │   ├── TeamsWindowDetector.swift
│       │   ├── ScreenCaptureService.swift
│       │   ├── OCRService.swift
│       │   └── NotificationService.swift
│       ├── MenuBar/
│       │   └── MenuBarController.swift
│       └── UI/
│           ├── PopoverRootView.swift
│           ├── MeetingDetailView.swift
│           ├── SettingsView.swift
│           ├── HistoryView.swift
│           └── OnboardingView.swift
├── Tests/
│   └── MeetingMeterCoreTests/
│       ├── RateCalculatorTests.swift
│       ├── TeamsTitleMatcherTests.swift
│       ├── OCRParticipantParserTests.swift
│       ├── PreferencesTests.swift
│       ├── MeetingRecordTests.swift
│       ├── MeetingHistoryStoreTests.swift
│       └── MeetingSessionTests.swift
└── README.md
```

**Rationale for the split:** The system services (`TeamsWindowDetector`, `ScreenCaptureService`, `OCRService`, `NotificationService`) need the actual OS to run and cannot be meaningfully unit-tested. Everything that CAN be tested — regex parsers, session math, persistence — stays in the Core framework.

---

## Task 0: Project scaffolding with XcodeGen

**Files:**
- Create: `/Users/jbaubree/Projets/MeetingMeter/project.yml`
- Create: `/Users/jbaubree/Projets/MeetingMeter/Sources/MeetingMeter/MeetingMeterApp.swift`
- Create: `/Users/jbaubree/Projets/MeetingMeter/Sources/MeetingMeter/AppDelegate.swift`
- Create: `/Users/jbaubree/Projets/MeetingMeter/Sources/MeetingMeterCore/MeetingMeterCore.swift` (minimal placeholder)
- Create: `/Users/jbaubree/Projets/MeetingMeter/Tests/MeetingMeterCoreTests/MeetingMeterCoreTests.swift` (minimal placeholder)

- [ ] **Step 1: Verify XcodeGen installed**

Run: `which xcodegen && xcodegen --version`
Expected: path + version. If "not found" → run `brew install xcodegen`.

- [ ] **Step 2: Write `project.yml`**

```yaml
name: MeetingMeter
options:
  bundleIdPrefix: com.jbaubree
  deploymentTarget:
    macOS: "14.0"
  createIntermediateGroups: true
settings:
  base:
    SWIFT_VERSION: "5.9"
    MACOSX_DEPLOYMENT_TARGET: "14.0"
    ENABLE_HARDENED_RUNTIME: NO
    CODE_SIGN_STYLE: Manual
    CODE_SIGN_IDENTITY: "-"
    DEVELOPMENT_TEAM: ""
targets:
  MeetingMeterCore:
    type: framework
    platform: macOS
    sources:
      - Sources/MeetingMeterCore
    info:
      path: MeetingMeterCore-Info.plist
      properties:
        CFBundleShortVersionString: "0.1.0"
        CFBundleVersion: "1"
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.jbaubree.MeetingMeterCore
        SKIP_INSTALL: YES
        DEFINES_MODULE: YES
  MeetingMeter:
    type: application
    platform: macOS
    sources:
      - Sources/MeetingMeter
    info:
      path: Info.plist
      properties:
        LSUIElement: true
        NSHumanReadableCopyright: ""
        CFBundleShortVersionString: "0.1.0"
        CFBundleVersion: "1"
        NSCameraUsageDescription: ""
        NSMicrophoneUsageDescription: ""
    dependencies:
      - target: MeetingMeterCore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.jbaubree.MeetingMeter
  MeetingMeterCoreTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - Tests/MeetingMeterCoreTests
    dependencies:
      - target: MeetingMeterCore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.jbaubree.MeetingMeterCoreTests
        GENERATE_INFOPLIST_FILE: YES
schemes:
  MeetingMeter:
    build:
      targets:
        MeetingMeter: all
        MeetingMeterCore: all
    run:
      config: Debug
    test:
      config: Debug
      targets:
        - MeetingMeterCoreTests
```

- [ ] **Step 3: Write minimal `MeetingMeterApp.swift`**

```swift
import SwiftUI

@main
struct MeetingMeterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
```

- [ ] **Step 4: Write minimal `AppDelegate.swift`**

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
```

- [ ] **Step 5: Write placeholder `MeetingMeterCore.swift`**

```swift
// Framework target needs at least one Swift file to produce a binary.
// This file will be deleted in Task 1 once a real source replaces it.
public enum MeetingMeterCore {}
```

- [ ] **Step 6: Write placeholder `MeetingMeterCoreTests.swift`**

```swift
// Test target needs at least one XCTestCase to produce a binary.
// This file will be deleted in Task 1 once real tests replace it.
import XCTest

final class _PlaceholderTests: XCTestCase {}
```

- [ ] **Step 7: Generate the project**

Run: `cd /Users/jbaubree/Projets/MeetingMeter && xcodegen generate`
Expected: `✅ Created project at MeetingMeter.xcodeproj`.

- [ ] **Step 8: Build**

Run: `cd /Users/jbaubree/Projets/MeetingMeter && xcodebuild -scheme MeetingMeter -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 9: Test**

Run: `cd /Users/jbaubree/Projets/MeetingMeter && xcodebuild -scheme MeetingMeter -configuration Debug test 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **` (0 tests executed).

- [ ] **Step 10: Commit**

```bash
cd /Users/jbaubree/Projets/MeetingMeter
git add project.yml Sources Tests .gitignore
git -c user.name="Jean-Baptiste Aubrée" -c user.email="jb.aubree.dev@gmail.com" commit -m "chore: scaffold Xcode project via XcodeGen"
```

---

## Task 1: RateCalculator

**Files:**
- Create: `Sources/MeetingMeterCore/RateCalculator.swift`
- Test: `Tests/MeetingMeterCoreTests/RateCalculatorTests.swift`
- Delete: `Sources/MeetingMeterCore/MeetingMeterCore.swift` and `Tests/MeetingMeterCoreTests/MeetingMeterCoreTests.swift` (placeholders)

- [ ] **Step 1: Write the failing test**

```swift
// Tests/MeetingMeterCoreTests/RateCalculatorTests.swift
import XCTest
@testable import MeetingMeterCore

final class RateCalculatorTests: XCTestCase {
    func test_cost_basic500EuroPerDay8h() {
        // Per-person per-second = 500 / (8 * 3600) = 0.01736...
        // 7 people × 1 second = 0.1215 ...
        let c = RateCalculator.cost(participants: 7, intervalSeconds: 1, dailyRate: 500, workDayHours: 8)
        XCTAssertEqual(c, 7 * 500.0 / (8.0 * 3600.0), accuracy: 1e-9)
    }

    func test_cost_zeroParticipants_isZero() {
        XCTAssertEqual(
            RateCalculator.cost(participants: 0, intervalSeconds: 60, dailyRate: 500, workDayHours: 8),
            0.0
        )
    }

    func test_cost_zeroInterval_isZero() {
        XCTAssertEqual(
            RateCalculator.cost(participants: 10, intervalSeconds: 0, dailyRate: 500, workDayHours: 8),
            0.0
        )
    }

    func test_cost_zeroWorkDayHours_isZero_asGuard() {
        // We treat workDayHours==0 as "undefined rate" and return 0, not a crash.
        XCTAssertEqual(
            RateCalculator.cost(participants: 10, intervalSeconds: 60, dailyRate: 500, workDayHours: 0),
            0.0
        )
    }

    func test_cost_longerIntervalScalesLinearly() {
        let a = RateCalculator.cost(participants: 5, intervalSeconds: 1, dailyRate: 400, workDayHours: 8)
        let b = RateCalculator.cost(participants: 5, intervalSeconds: 60, dailyRate: 400, workDayHours: 8)
        XCTAssertEqual(b, 60 * a, accuracy: 1e-9)
    }
}
```

- [ ] **Step 2: Delete placeholder files**

Delete `Sources/MeetingMeterCore/MeetingMeterCore.swift` and `Tests/MeetingMeterCoreTests/MeetingMeterCoreTests.swift`.

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd /Users/jbaubree/Projets/MeetingMeter && xcodegen generate && xcodebuild -scheme MeetingMeter -configuration Debug test 2>&1 | tail -30`
Expected: compile error — `RateCalculator` not defined.

- [ ] **Step 4: Write implementation**

```swift
// Sources/MeetingMeterCore/RateCalculator.swift
import Foundation

public enum RateCalculator {
    /// Cost (in whatever currency `dailyRate` is in) for an interval of `intervalSeconds`
    /// with `participants` people, assuming an 8-hour (or any) work day at `dailyRate`.
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
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd /Users/jbaubree/Projets/MeetingMeter && xcodegen generate && xcodebuild -scheme MeetingMeter -configuration Debug test 2>&1 | tail -10`
Expected: `Test Suite 'RateCalculatorTests' passed`, 5 tests, 0 failures.

- [ ] **Step 6: Commit**

```bash
cd /Users/jbaubree/Projets/MeetingMeter
git add Sources/MeetingMeterCore Tests/MeetingMeterCoreTests
git -c user.name="Jean-Baptiste Aubrée" -c user.email="jb.aubree.dev@gmail.com" commit -m "feat(core): add RateCalculator with per-second cost formula"
```

---

## Task 2: TeamsTitleMatcher

**Files:**
- Create: `Sources/MeetingMeterCore/TeamsTitleMatcher.swift`
- Test: `Tests/MeetingMeterCoreTests/TeamsTitleMatcherTests.swift`

Regex-based detector that answers: "does this window title look like an active Teams meeting window?".

- [ ] **Step 1: Write the failing test**

```swift
// Tests/MeetingMeterCoreTests/TeamsTitleMatcherTests.swift
import XCTest
@testable import MeetingMeterCore

final class TeamsTitleMatcherTests: XCTestCase {
    func test_english_meetingWith_matches() {
        XCTAssertTrue(TeamsTitleMatcher.isMeetingWindowTitle("Meeting with Alice | Microsoft Teams"))
    }

    func test_english_callWith_matches() {
        XCTAssertTrue(TeamsTitleMatcher.isMeetingWindowTitle("Call with Alice"))
    }

    func test_french_reunionAvec_matches() {
        XCTAssertTrue(TeamsTitleMatcher.isMeetingWindowTitle("Réunion avec Alice | Microsoft Teams"))
    }

    func test_french_appelAvec_matches() {
        XCTAssertTrue(TeamsTitleMatcher.isMeetingWindowTitle("Appel avec Alice"))
    }

    func test_german_besprechung_matches() {
        XCTAssertTrue(TeamsTitleMatcher.isMeetingWindowTitle("Besprechung mit Alice"))
    }

    func test_spanish_reunion_matches() {
        XCTAssertTrue(TeamsTitleMatcher.isMeetingWindowTitle("Reunión con Alice"))
    }

    func test_matchIsCaseInsensitive() {
        XCTAssertTrue(TeamsTitleMatcher.isMeetingWindowTitle("MEETING WITH ALICE"))
    }

    func test_plainTeamsHomeTitle_doesNotMatch() {
        XCTAssertFalse(TeamsTitleMatcher.isMeetingWindowTitle("Microsoft Teams"))
    }

    func test_emptyTitle_doesNotMatch() {
        XCTAssertFalse(TeamsTitleMatcher.isMeetingWindowTitle(""))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/jbaubree/Projets/MeetingMeter && xcodegen generate && xcodebuild -scheme MeetingMeter -configuration Debug test 2>&1 | tail -20`
Expected: compile error — `TeamsTitleMatcher` not defined.

- [ ] **Step 3: Write implementation**

```swift
// Sources/MeetingMeterCore/TeamsTitleMatcher.swift
import Foundation

public enum TeamsTitleMatcher {
    /// Keywords in various UI languages Microsoft Teams has been seen to use for
    /// meeting/call windows. Match is case-insensitive, substring (anywhere in the title).
    public static let keywords: [String] = [
        "meeting",
        "call",
        "réunion",
        "appel",
        "besprechung",
        "anruf",
        "reunión",
        "llamada"
    ]

    public static func isMeetingWindowTitle(_ title: String) -> Bool {
        guard !title.isEmpty else { return false }
        let lower = title.lowercased()
        return keywords.contains(where: { lower.contains($0) })
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/jbaubree/Projets/MeetingMeter && xcodebuild -scheme MeetingMeter -configuration Debug test 2>&1 | tail -10`
Expected: all 9 `TeamsTitleMatcherTests` pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/jbaubree/Projets/MeetingMeter
git add Sources/MeetingMeterCore/TeamsTitleMatcher.swift Tests/MeetingMeterCoreTests/TeamsTitleMatcherTests.swift
git -c user.name="Jean-Baptiste Aubrée" -c user.email="jb.aubree.dev@gmail.com" commit -m "feat(core): add TeamsTitleMatcher for multi-language meeting title detection"
```

---

## Task 3: OCRParticipantParser

**Files:**
- Create: `Sources/MeetingMeterCore/OCRParticipantParser.swift`
- Test: `Tests/MeetingMeterCoreTests/OCRParticipantParserTests.swift`

Given a block of OCR-recognized text (multiple lines), find the participant count.

- [ ] **Step 1: Write the failing test**

```swift
// Tests/MeetingMeterCoreTests/OCRParticipantParserTests.swift
import XCTest
@testable import MeetingMeterCore

final class OCRParticipantParserTests: XCTestCase {
    func test_numberBeforeKeyword_english() {
        XCTAssertEqual(OCRParticipantParser.parseCount(from: "7 participants"), 7)
    }

    func test_numberAfterKeyword_english() {
        XCTAssertEqual(OCRParticipantParser.parseCount(from: "Participants 7"), 7)
    }

    func test_people_singular() {
        XCTAssertEqual(OCRParticipantParser.parseCount(from: "12 people"), 12)
    }

    func test_personnes_french() {
        XCTAssertEqual(OCRParticipantParser.parseCount(from: "4 personnes"), 4)
    }

    func test_teilnehmer_german() {
        XCTAssertEqual(OCRParticipantParser.parseCount(from: "Teilnehmer 15"), 15)
    }

    func test_personas_spanish() {
        XCTAssertEqual(OCRParticipantParser.parseCount(from: "6 Personas"), 6)
    }

    func test_multiline_findsAnywhere() {
        let text = """
        Microsoft Teams
        Reactions
        3 participants
        Chat
        """
        XCTAssertEqual(OCRParticipantParser.parseCount(from: text), 3)
    }

    func test_largeNumberParsed() {
        XCTAssertEqual(OCRParticipantParser.parseCount(from: "154 participants"), 154)
    }

    func test_noKeyword_returnsNil() {
        XCTAssertNil(OCRParticipantParser.parseCount(from: "Microsoft Teams"))
    }

    func test_keywordWithoutNumber_returnsNil() {
        XCTAssertNil(OCRParticipantParser.parseCount(from: "Participants"))
    }

    func test_zeroReturnsNil_notRealistic() {
        // A match of "0 participants" is parsed to 0; downstream code may ignore it.
        XCTAssertEqual(OCRParticipantParser.parseCount(from: "0 participants"), 0)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/jbaubree/Projets/MeetingMeter && xcodegen generate && xcodebuild -scheme MeetingMeter -configuration Debug test 2>&1 | tail -20`
Expected: compile error — `OCRParticipantParser` not defined.

- [ ] **Step 3: Write implementation**

```swift
// Sources/MeetingMeterCore/OCRParticipantParser.swift
import Foundation

public enum OCRParticipantParser {
    /// Keywords (case-insensitive) that identify a participant counter in OCR text.
    private static let keywords: [String] = [
        "participants",
        "participant",
        "people",
        "personnes",
        "teilnehmer",
        "personas"
    ]

    /// Scans each line of `text` for a `(number, keyword)` or `(keyword, number)` pair
    /// and returns the first number found. nil if no participant count can be extracted.
    public static func parseCount(from text: String) -> Int? {
        let joined = text.lowercased()
        for keyword in keywords {
            guard let keywordRange = joined.range(of: keyword) else { continue }
            // Try: digits immediately before the keyword.
            if let digits = extractDigitsBackward(in: joined, before: keywordRange.lowerBound) {
                return digits
            }
            // Try: digits immediately after the keyword.
            if let digits = extractDigitsForward(in: joined, after: keywordRange.upperBound) {
                return digits
            }
        }
        return nil
    }

    private static func extractDigitsBackward(in s: String, before idx: String.Index) -> Int? {
        var cursor = idx
        // Skip whitespace between keyword and digits.
        while cursor > s.startIndex {
            let prev = s.index(before: cursor)
            if s[prev].isWhitespace { cursor = prev } else { break }
        }
        // Walk back collecting digits.
        var digitEnd = cursor
        var digitStart = cursor
        while digitStart > s.startIndex {
            let prev = s.index(before: digitStart)
            if s[prev].isNumber { digitStart = prev } else { break }
        }
        guard digitStart < digitEnd else { return nil }
        return Int(s[digitStart..<digitEnd])
    }

    private static func extractDigitsForward(in s: String, after idx: String.Index) -> Int? {
        var cursor = idx
        // Skip whitespace between keyword and digits.
        while cursor < s.endIndex, s[cursor].isWhitespace { cursor = s.index(after: cursor) }
        var digitEnd = cursor
        while digitEnd < s.endIndex, s[digitEnd].isNumber { digitEnd = s.index(after: digitEnd) }
        guard cursor < digitEnd else { return nil }
        return Int(s[cursor..<digitEnd])
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/jbaubree/Projets/MeetingMeter && xcodebuild -scheme MeetingMeter -configuration Debug test 2>&1 | tail -10`
Expected: all 11 `OCRParticipantParserTests` pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/jbaubree/Projets/MeetingMeter
git add Sources/MeetingMeterCore/OCRParticipantParser.swift Tests/MeetingMeterCoreTests/OCRParticipantParserTests.swift
git -c user.name="Jean-Baptiste Aubrée" -c user.email="jb.aubree.dev@gmail.com" commit -m "feat(core): add OCRParticipantParser for extracting counts from OCR text"
```

---

## Task 4: Preferences + PreferencesStore

**Files:**
- Create: `Sources/MeetingMeterCore/Preferences.swift`
- Create: `Sources/MeetingMeterCore/PreferencesStore.swift`
- Test: `Tests/MeetingMeterCoreTests/PreferencesTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/MeetingMeterCoreTests/PreferencesTests.swift
import XCTest
@testable import MeetingMeterCore

final class PreferencesTests: XCTestCase {
    private func makeStore() -> (PreferencesStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        return (PreferencesStore(defaults: defaults), defaults)
    }

    func test_load_returnsDefaultsWhenEmpty() {
        let (store, _) = makeStore()
        let prefs = store.load()
        XCTAssertEqual(prefs.dailyRate, 500)
        XCTAssertEqual(prefs.workDayHours, 8)
        XCTAssertEqual(prefs.currencySymbol, "€")
    }

    func test_save_thenLoad_roundTrips() {
        let (store, _) = makeStore()
        var prefs = Preferences.defaults
        prefs.dailyRate = 750
        prefs.workDayHours = 7.5
        prefs.currencySymbol = "$"
        store.save(prefs)

        XCTAssertEqual(store.load(), prefs)
    }

    func test_load_fallsBackToDefaultsOnCorruptData() {
        let (store, defaults) = makeStore()
        defaults.set(Data([0xFF, 0xFF]), forKey: PreferencesStore.storageKey)
        XCTAssertEqual(store.load(), .defaults)
    }

    func test_load_defaultsCurrencyToEuroWhenMissingFromStoredData() throws {
        let (store, defaults) = makeStore()
        let legacy: [String: Any] = ["dailyRate": 400.0, "workDayHours": 8.0]
        let data = try JSONSerialization.data(withJSONObject: legacy)
        defaults.set(data, forKey: PreferencesStore.storageKey)
        XCTAssertEqual(store.load().currencySymbol, "€")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/jbaubree/Projets/MeetingMeter && xcodegen generate && xcodebuild -scheme MeetingMeter -configuration Debug test 2>&1 | tail -20`
Expected: compile errors — Preferences / PreferencesStore not defined.

- [ ] **Step 3: Write `Preferences.swift`**

```swift
// Sources/MeetingMeterCore/Preferences.swift
import Foundation

public struct Preferences: Codable, Equatable {
    public var dailyRate: Double
    public var workDayHours: Double
    public var currencySymbol: String

    public init(dailyRate: Double, workDayHours: Double, currencySymbol: String) {
        self.dailyRate = dailyRate
        self.workDayHours = workDayHours
        self.currencySymbol = currencySymbol
    }

    // Keep legacy stored prefs loadable when new fields are added.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.dailyRate = try c.decode(Double.self, forKey: .dailyRate)
        self.workDayHours = try c.decode(Double.self, forKey: .workDayHours)
        self.currencySymbol = try c.decodeIfPresent(String.self, forKey: .currencySymbol) ?? "€"
    }

    public static let defaults = Preferences(dailyRate: 500, workDayHours: 8, currencySymbol: "€")
}
```

- [ ] **Step 4: Write `PreferencesStore.swift`**

```swift
// Sources/MeetingMeterCore/PreferencesStore.swift
import Foundation

public final class PreferencesStore {
    public static let storageKey = "com.jbaubree.MeetingMeter.preferences"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> Preferences {
        guard let data = defaults.data(forKey: Self.storageKey) else { return .defaults }
        return (try? JSONDecoder().decode(Preferences.self, from: data)) ?? .defaults
    }

    public func save(_ prefs: Preferences) {
        guard let data = try? JSONEncoder().encode(prefs) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd /Users/jbaubree/Projets/MeetingMeter && xcodebuild -scheme MeetingMeter -configuration Debug test 2>&1 | tail -10`
Expected: all 4 `PreferencesTests` pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/jbaubree/Projets/MeetingMeter
git add Sources/MeetingMeterCore/Preferences.swift Sources/MeetingMeterCore/PreferencesStore.swift Tests/MeetingMeterCoreTests/PreferencesTests.swift
git -c user.name="Jean-Baptiste Aubrée" -c user.email="jb.aubree.dev@gmail.com" commit -m "feat(core): add Preferences model and UserDefaults-backed store"
```

---

## Task 5: MeetingRecord

**Files:**
- Create: `Sources/MeetingMeterCore/MeetingRecord.swift`
- Test: `Tests/MeetingMeterCoreTests/MeetingRecordTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/MeetingMeterCoreTests/MeetingRecordTests.swift
import XCTest
@testable import MeetingMeterCore

final class MeetingRecordTests: XCTestCase {
    func test_codable_roundTrip() throws {
        let r = MeetingRecord(
            id: UUID(),
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: Date(timeIntervalSince1970: 1_700_003_600),
            durationSeconds: 3600,
            avgParticipants: 7.5,
            totalCost: 325.0,
            dailyRateAtTheTime: 500,
            workDayHoursAtTheTime: 8
        )
        let data = try JSONEncoder().encode(r)
        let decoded = try JSONDecoder().decode(MeetingRecord.self, from: data)
        XCTAssertEqual(decoded, r)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/jbaubree/Projets/MeetingMeter && xcodegen generate && xcodebuild -scheme MeetingMeter -configuration Debug test 2>&1 | tail -20`
Expected: compile error — `MeetingRecord` not defined.

- [ ] **Step 3: Write implementation**

```swift
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/jbaubree/Projets/MeetingMeter && xcodebuild -scheme MeetingMeter -configuration Debug test 2>&1 | tail -10`
Expected: `test_codable_roundTrip` passes.

- [ ] **Step 5: Commit**

```bash
cd /Users/jbaubree/Projets/MeetingMeter
git add Sources/MeetingMeterCore/MeetingRecord.swift Tests/MeetingMeterCoreTests/MeetingRecordTests.swift
git -c user.name="Jean-Baptiste Aubrée" -c user.email="jb.aubree.dev@gmail.com" commit -m "feat(core): add MeetingRecord value type"
```

---

## Task 6: MeetingHistoryStore

**Files:**
- Create: `Sources/MeetingMeterCore/MeetingHistoryStore.swift`
- Test: `Tests/MeetingMeterCoreTests/MeetingHistoryStoreTests.swift`

JSON file persistence for the list of past meetings. Store takes a directory URL so tests can use a tmp dir.

- [ ] **Step 1: Write the failing test**

```swift
// Tests/MeetingMeterCoreTests/MeetingHistoryStoreTests.swift
import XCTest
@testable import MeetingMeterCore

final class MeetingHistoryStoreTests: XCTestCase {
    private func makeStore() -> MeetingHistoryStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeetingMeterTests-\(UUID().uuidString)", isDirectory: true)
        return MeetingHistoryStore(directoryURL: dir)
    }

    private func sampleRecord(cost: Double = 10) -> MeetingRecord {
        MeetingRecord(
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: Date(timeIntervalSince1970: 1_700_000_060),
            durationSeconds: 60,
            avgParticipants: 2,
            totalCost: cost,
            dailyRateAtTheTime: 500,
            workDayHoursAtTheTime: 8
        )
    }

    func test_loadAll_whenNoFile_returnsEmpty() {
        let store = makeStore()
        XCTAssertEqual(store.loadAll(), [])
    }

    func test_append_thenLoadAll_returnsOneRecord() {
        let store = makeStore()
        let r = sampleRecord()
        store.append(r)
        XCTAssertEqual(store.loadAll(), [r])
    }

    func test_append_preservesInsertionOrder() {
        let store = makeStore()
        let a = sampleRecord(cost: 10)
        let b = sampleRecord(cost: 20)
        store.append(a)
        store.append(b)
        XCTAssertEqual(store.loadAll().map(\.totalCost), [10, 20])
    }

    func test_clear_removesAll() {
        let store = makeStore()
        store.append(sampleRecord())
        store.clear()
        XCTAssertEqual(store.loadAll(), [])
    }

    func test_corruptFile_returnsEmptyWithoutCrashing() throws {
        let store = makeStore()
        // Prime the dir and then corrupt the JSON.
        store.append(sampleRecord())
        let url = store.fileURL
        try Data([0xFF, 0xFF]).write(to: url)
        XCTAssertEqual(store.loadAll(), [])
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/jbaubree/Projets/MeetingMeter && xcodegen generate && xcodebuild -scheme MeetingMeter -configuration Debug test 2>&1 | tail -20`
Expected: compile error — `MeetingHistoryStore` not defined.

- [ ] **Step 3: Write implementation**

```swift
// Sources/MeetingMeterCore/MeetingHistoryStore.swift
import Foundation

public final class MeetingHistoryStore {
    public let directoryURL: URL
    public let fileURL: URL

    public init(directoryURL: URL) {
        self.directoryURL = directoryURL
        self.fileURL = directoryURL.appendingPathComponent("history.json")
    }

    /// Convenience init that stores under `~/Library/Application Support/MeetingMeter/`.
    public convenience init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("MeetingMeter", isDirectory: true)
        self.init(directoryURL: base)
    }

    public func loadAll() -> [MeetingRecord] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([MeetingRecord].self, from: data)) ?? []
    }

    public func append(_ record: MeetingRecord) {
        var all = loadAll()
        all.append(record)
        save(all)
    }

    public func clear() {
        save([])
    }

    private func save(_ records: [MeetingRecord]) {
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
```

Note: `dateEncodingStrategy` and `dateDecodingStrategy` are both `.iso8601` so encoded dates can be re-read.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/jbaubree/Projets/MeetingMeter && xcodebuild -scheme MeetingMeter -configuration Debug test 2>&1 | tail -10`
Expected: all 5 `MeetingHistoryStoreTests` pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/jbaubree/Projets/MeetingMeter
git add Sources/MeetingMeterCore/MeetingHistoryStore.swift Tests/MeetingMeterCoreTests/MeetingHistoryStoreTests.swift
git -c user.name="Jean-Baptiste Aubrée" -c user.email="jb.aubree.dev@gmail.com" commit -m "feat(core): add MeetingHistoryStore with JSON file persistence"
```

---

## Task 7: MeetingSession

**Files:**
- Create: `Sources/MeetingMeterCore/MeetingSession.swift`
- Test: `Tests/MeetingMeterCoreTests/MeetingSessionTests.swift`

The live session: a state machine that accumulates cost per tick, keeps a weighted average of participants over the meeting duration, and emits a `MeetingRecord` on end.

- [ ] **Step 1: Write the failing test**

```swift
// Tests/MeetingMeterCoreTests/MeetingSessionTests.swift
import XCTest
@testable import MeetingMeterCore

final class MeetingSessionTests: XCTestCase {
    private func session() -> MeetingSession {
        MeetingSession(preferencesProvider: { Preferences(dailyRate: 500, workDayHours: 8, currencySymbol: "€") })
    }

    func test_initialState_isIdle() {
        let s = session()
        if case .idle = s.state { /* ok */ } else { XCTFail("Expected .idle, got \(s.state)") }
        XCTAssertEqual(s.cost, 0)
        XCTAssertEqual(s.elapsedSeconds, 0)
        XCTAssertNil(s.lastKnownCount)
    }

    func test_start_setsStateToInMeeting() {
        let s = session()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        s.start(at: now)
        if case .inMeeting(let startedAt) = s.state {
            XCTAssertEqual(startedAt, now)
        } else {
            XCTFail("Expected .inMeeting, got \(s.state)")
        }
    }

    func test_tick_withoutCount_doesNotIncreaseCost() {
        let s = session()
        s.start(at: Date())
        s.tick(interval: 1)
        s.tick(interval: 1)
        XCTAssertEqual(s.cost, 0)
        XCTAssertEqual(s.elapsedSeconds, 2, accuracy: 1e-9)
    }

    func test_tick_withCount_accumulatesCost() {
        let s = session()
        s.start(at: Date())
        s.updateParticipantCount(5)
        s.tick(interval: 1)
        // 5 × 500 / (8 × 3600) × 1 = 0.0868...
        XCTAssertEqual(s.cost, 5 * 500.0 / (8 * 3600.0), accuracy: 1e-9)
    }

    func test_tick_countChangesMidSession_appliesNewRateFromNextTick() {
        let s = session()
        s.start(at: Date())
        s.updateParticipantCount(5)
        s.tick(interval: 1) // 5 people × 1 sec
        s.updateParticipantCount(10)
        s.tick(interval: 1) // 10 people × 1 sec
        let perPersonSec = 500.0 / (8 * 3600.0)
        XCTAssertEqual(s.cost, 15 * perPersonSec, accuracy: 1e-9)
    }

    func test_end_producesRecordWithWeightedAverage() {
        let s = session()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        s.start(at: start)
        s.updateParticipantCount(5)
        s.tick(interval: 10) // 10s @ 5
        s.updateParticipantCount(15)
        s.tick(interval: 10) // 10s @ 15
        let end = start.addingTimeInterval(20)
        let record = s.end(at: end)
        XCTAssertNotNil(record)
        XCTAssertEqual(record?.durationSeconds, 20, accuracy: 1e-9)
        XCTAssertEqual(record?.avgParticipants, 10, accuracy: 1e-9) // (5×10 + 15×10) / 20
        XCTAssertEqual(record?.startedAt, start)
        XCTAssertEqual(record?.endedAt, end)
    }

    func test_end_whileIdle_returnsNil() {
        let s = session()
        XCTAssertNil(s.end(at: Date()))
    }

    func test_end_resetsStateToIdle() {
        let s = session()
        s.start(at: Date())
        s.updateParticipantCount(3)
        s.tick(interval: 5)
        _ = s.end(at: Date())
        if case .idle = s.state { /* ok */ } else { XCTFail("Expected .idle after end") }
        XCTAssertEqual(s.cost, 0)
        XCTAssertEqual(s.elapsedSeconds, 0)
    }

    func test_lastKnownCount_persistsAfterUpdate() {
        let s = session()
        s.start(at: Date())
        s.updateParticipantCount(7)
        XCTAssertEqual(s.lastKnownCount, 7)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/jbaubree/Projets/MeetingMeter && xcodegen generate && xcodebuild -scheme MeetingMeter -configuration Debug test 2>&1 | tail -30`
Expected: compile errors — `MeetingSession` not defined.

- [ ] **Step 3: Write implementation**

```swift
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

    // Weighted sum: ∑(count_i × Δt_i) accumulated across tick() calls.
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/jbaubree/Projets/MeetingMeter && xcodebuild -scheme MeetingMeter -configuration Debug test 2>&1 | tail -10`
Expected: all 9 `MeetingSessionTests` pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/jbaubree/Projets/MeetingMeter
git add Sources/MeetingMeterCore/MeetingSession.swift Tests/MeetingMeterCoreTests/MeetingSessionTests.swift
git -c user.name="Jean-Baptiste Aubrée" -c user.email="jb.aubree.dev@gmail.com" commit -m "feat(core): add MeetingSession with tick + weighted avg + record emission"
```

---

## Task 8: TeamsWindowDetector

**Files:**
- Create: `Sources/MeetingMeter/Services/TeamsWindowDetector.swift`

Finds Teams processes via `NSWorkspace`, enumerates their windows via AX, and reports whether any match a meeting title. Not unit-tested (requires AX + running Teams).

- [ ] **Step 1: Write implementation**

```swift
// Sources/MeetingMeter/Services/TeamsWindowDetector.swift
import AppKit
import ApplicationServices
import MeetingMeterCore

public final class TeamsWindowDetector {
    /// Callback with the currently detected meeting window, or nil if none.
    public var onUpdate: ((DetectedMeeting?) -> Void)?

    public struct DetectedMeeting: Equatable {
        public let pid: pid_t
        public let title: String
    }

    /// Candidate Teams bundle ids, tried in order. First match wins.
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
```

- [ ] **Step 2: Build**

Run: `cd /Users/jbaubree/Projets/MeetingMeter && xcodegen generate && xcodebuild -scheme MeetingMeter -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`.

Also tests regression: `xcodebuild -scheme MeetingMeter -configuration Debug test 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/jbaubree/Projets/MeetingMeter
git add Sources/MeetingMeter/Services/TeamsWindowDetector.swift
git -c user.name="Jean-Baptiste Aubrée" -c user.email="jb.aubree.dev@gmail.com" commit -m "feat: add TeamsWindowDetector (AX + NSWorkspace + poll)"
```

---

## Task 9: ScreenCaptureService

**Files:**
- Create: `Sources/MeetingMeter/Services/ScreenCaptureService.swift`

Captures the Teams window for a given pid using ScreenCaptureKit. async API, returns a `CGImage` cropped to the top 25%.

- [ ] **Step 1: Write implementation**

```swift
// Sources/MeetingMeter/Services/ScreenCaptureService.swift
import AppKit
import ScreenCaptureKit
import CoreGraphics

public final class ScreenCaptureService {
    public init() {}

    public enum CaptureError: Error {
        case noWindowFound
        case cropFailed
    }

    /// Captures the first on-screen window belonging to the given pid, then crops to the
    /// top 25% of height (where Teams' participant counter lives). Returns a CGImage.
    public func captureTopBand(for pid: pid_t) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let window = content.windows.first(where: { $0.owningApplication?.processID == pid && $0.isOnScreen && ($0.title ?? "").isEmpty == false })
        else { throw CaptureError.noWindowFound }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)

        let full = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return try cropTopBand(full)
    }

    private func cropTopBand(_ image: CGImage) throws -> CGImage {
        let bandHeight = max(1, image.height / 4)
        let rect = CGRect(x: 0, y: 0, width: image.width, height: bandHeight)
        guard let cropped = image.cropping(to: rect) else { throw CaptureError.cropFailed }
        return cropped
    }
}
```

- [ ] **Step 2: Build**

Run: `cd /Users/jbaubree/Projets/MeetingMeter && xcodegen generate && xcodebuild -scheme MeetingMeter -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/jbaubree/Projets/MeetingMeter
git add Sources/MeetingMeter/Services/ScreenCaptureService.swift
git -c user.name="Jean-Baptiste Aubrée" -c user.email="jb.aubree.dev@gmail.com" commit -m "feat: add ScreenCaptureService using SCScreenshotManager"
```

---

## Task 10: OCRService

**Files:**
- Create: `Sources/MeetingMeter/Services/OCRService.swift`

Runs Vision text recognition on a CGImage, joins the recognized lines, and asks `OCRParticipantParser` for a count.

- [ ] **Step 1: Write implementation**

```swift
// Sources/MeetingMeter/Services/OCRService.swift
import Vision
import CoreGraphics
import MeetingMeterCore

public final class OCRService {
    public init() {}

    public enum OCRError: Error {
        case recognitionFailed(Error)
    }

    /// Runs Vision text recognition on `image` and returns the extracted participant
    /// count (or nil if none could be parsed). Fast recognition level, no language correction.
    public func recognizeParticipantCount(from image: CGImage) async throws -> Int? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw OCRError.recognitionFailed(error)
        }
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        let joined = lines.joined(separator: "\n")
        return OCRParticipantParser.parseCount(from: joined)
    }
}
```

- [ ] **Step 2: Build**

Run: `cd /Users/jbaubree/Projets/MeetingMeter && xcodegen generate && xcodebuild -scheme MeetingMeter -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/jbaubree/Projets/MeetingMeter
git add Sources/MeetingMeter/Services/OCRService.swift
git -c user.name="Jean-Baptiste Aubrée" -c user.email="jb.aubree.dev@gmail.com" commit -m "feat: add OCRService via Vision + delegate to Core parser"
```

---

## Task 11: NotificationService

**Files:**
- Create: `Sources/MeetingMeter/Services/NotificationService.swift`

Posts a local notification when a meeting ends.

- [ ] **Step 1: Write implementation**

```swift
// Sources/MeetingMeter/Services/NotificationService.swift
import UserNotifications

public final class NotificationService {
    public init() {}

    public func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    public func postMeetingEnded(totalCost: Double, currency: String, durationSeconds: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Réunion terminée"
        let minutes = Int(durationSeconds / 60)
        let cost = String(format: "%.2f %@", totalCost, currency)
        content.body = "\(minutes) min — \(cost)"
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}
```

- [ ] **Step 2: Build**

Run: `cd /Users/jbaubree/Projets/MeetingMeter && xcodegen generate && xcodebuild -scheme MeetingMeter -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/jbaubree/Projets/MeetingMeter
git add Sources/MeetingMeter/Services/NotificationService.swift
git -c user.name="Jean-Baptiste Aubrée" -c user.email="jb.aubree.dev@gmail.com" commit -m "feat: add NotificationService for meeting-end notification"
```

---

## Task 12: OnboardingView

**Files:**
- Create: `Sources/MeetingMeter/UI/OnboardingView.swift`

Prompts for Accessibility first, then Screen Recording. Uses system-settings deep links.

- [ ] **Step 1: Write implementation**

```swift
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
    /// Returns true if screen recording is allowed. Uses CGPreflightScreenCaptureAccess,
    /// which is a non-prompting check on macOS 11+. Call requestAccess() to trigger the
    /// one-time system prompt.
    static func isTrusted() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    static func requestAccess() -> Bool {
        CGRequestScreenCaptureAccess()
    }
}
```

- [ ] **Step 2: Build + tests regression**

Run: `cd /Users/jbaubree/Projets/MeetingMeter && xcodegen generate && xcodebuild -scheme MeetingMeter -configuration Debug test 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`, `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/jbaubree/Projets/MeetingMeter
git add Sources/MeetingMeter/UI/OnboardingView.swift
git -c user.name="Jean-Baptiste Aubrée" -c user.email="jb.aubree.dev@gmail.com" commit -m "feat(ui): add dual-permission OnboardingView (Accessibility + Screen Recording)"
```

---

## Task 13: MeetingDetailView

**Files:**
- Create: `Sources/MeetingMeter/UI/MeetingDetailView.swift`

Shows the current meeting's live stats (cost, participants, elapsed). Receives a `MeetingSession` as `@ObservedObject` and a currency symbol.

- [ ] **Step 1: Write implementation**

```swift
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
```

- [ ] **Step 2: Build + tests regression**

Run: `cd /Users/jbaubree/Projets/MeetingMeter && xcodegen generate && xcodebuild -scheme MeetingMeter -configuration Debug test 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/jbaubree/Projets/MeetingMeter
git add Sources/MeetingMeter/UI/MeetingDetailView.swift
git -c user.name="Jean-Baptiste Aubrée" -c user.email="jb.aubree.dev@gmail.com" commit -m "feat(ui): add MeetingDetailView (idle + active states)"
```

---

## Task 14: HistoryView

**Files:**
- Create: `Sources/MeetingMeter/UI/HistoryView.swift`

Scrollable list of past meetings. "Clear history" button.

- [ ] **Step 1: Write implementation**

```swift
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
```

- [ ] **Step 2: Build + tests regression**

Run: `cd /Users/jbaubree/Projets/MeetingMeter && xcodegen generate && xcodebuild -scheme MeetingMeter -configuration Debug test 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/jbaubree/Projets/MeetingMeter
git add Sources/MeetingMeter/UI/HistoryView.swift
git -c user.name="Jean-Baptiste Aubrée" -c user.email="jb.aubree.dev@gmail.com" commit -m "feat(ui): add HistoryView with past meetings list"
```

---

## Task 15: SettingsView

**Files:**
- Create: `Sources/MeetingMeter/UI/SettingsView.swift`

- [ ] **Step 1: Write implementation**

```swift
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
                TextField("500", value: $dailyRate, format: .number)
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
```

- [ ] **Step 2: Build + tests regression**

Run: `cd /Users/jbaubree/Projets/MeetingMeter && xcodegen generate && xcodebuild -scheme MeetingMeter -configuration Debug test 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/jbaubree/Projets/MeetingMeter
git add Sources/MeetingMeter/UI/SettingsView.swift
git -c user.name="Jean-Baptiste Aubrée" -c user.email="jb.aubree.dev@gmail.com" commit -m "feat(ui): add SettingsView with rate / hours / currency"
```

---

## Task 16: PopoverRootView

**Files:**
- Create: `Sources/MeetingMeter/UI/PopoverRootView.swift`

Navigation hub : meeting detail / settings / history / onboarding (if perms missing).

- [ ] **Step 1: Write implementation**

```swift
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
```

- [ ] **Step 2: Build + tests regression**

Run: `cd /Users/jbaubree/Projets/MeetingMeter && xcodegen generate && xcodebuild -scheme MeetingMeter -configuration Debug test 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/jbaubree/Projets/MeetingMeter
git add Sources/MeetingMeter/UI/PopoverRootView.swift
git -c user.name="Jean-Baptiste Aubrée" -c user.email="jb.aubree.dev@gmail.com" commit -m "feat(ui): add PopoverRootView with tabs + permission gate"
```

---

## Task 17: MenuBarController

**Files:**
- Create: `Sources/MeetingMeter/MenuBar/MenuBarController.swift`

Owns the `NSStatusItem` and shows a text label that updates when the AppDelegate asks (via `updateLabel`).

- [ ] **Step 1: Write implementation**

```swift
// Sources/MeetingMeter/MenuBar/MenuBarController.swift
import AppKit
import SwiftUI

final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popover: NSPopover

    init(rootView: AnyView) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        super.init()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 420)
        popover.contentViewController = NSHostingController(rootView: rootView)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eurosign.circle",
                                   accessibilityDescription: "MeetingMeter")
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(togglePopover(_:))
        }
    }

    /// Sets the menu-bar label text displayed next to the icon. Pass "" to clear.
    func updateLabel(_ text: String) {
        guard let button = statusItem.button else { return }
        button.title = text.isEmpty ? "" : " " + text
    }

    /// Sets the leading icon. Pass nil to keep the default euro symbol.
    func updateIcon(systemName: String?) {
        guard let button = statusItem.button else { return }
        let name = systemName ?? "eurosign.circle"
        button.image = NSImage(systemSymbolName: name, accessibilityDescription: "MeetingMeter")
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
```

- [ ] **Step 2: Build + tests regression**

Run: `cd /Users/jbaubree/Projets/MeetingMeter && xcodegen generate && xcodebuild -scheme MeetingMeter -configuration Debug test 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/jbaubree/Projets/MeetingMeter
git add Sources/MeetingMeter/MenuBar/MenuBarController.swift
git -c user.name="Jean-Baptiste Aubrée" -c user.email="jb.aubree.dev@gmail.com" commit -m "feat(menubar): add MenuBarController with updatable label"
```

---

## Task 18: Wire everything in AppDelegate

**Files:**
- Modify: `Sources/MeetingMeter/AppDelegate.swift`

Instantiate all services, set up the 1 Hz timer, bridge `MeetingSession` to the menu bar text, start/end the session when the detector flips, run the OCR cycle, archive history on end.

- [ ] **Step 1: Replace `AppDelegate.swift`**

```swift
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
        updateMenuBarLabel()
        runOCRIfIdle()
    }

    private func runOCRIfIdle() {
        guard !ocrInFlight, let m = currentDetection else { return }
        ocrInFlight = true
        Task { [weak self] in
            defer { Task { @MainActor in self?.ocrInFlight = false } }
            do {
                let image = try await self?.capture.captureTopBand(for: m.pid)
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
```

- [ ] **Step 2: Build + tests regression**

Run: `cd /Users/jbaubree/Projets/MeetingMeter && xcodegen generate && xcodebuild -scheme MeetingMeter -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`.

Then: `xcodebuild -scheme MeetingMeter -configuration Debug test 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/jbaubree/Projets/MeetingMeter
git add Sources/MeetingMeter/AppDelegate.swift
git -c user.name="Jean-Baptiste Aubrée" -c user.email="jb.aubree.dev@gmail.com" commit -m "feat: wire detector, capture, OCR, session, menu bar in AppDelegate"
```

---

## Task 19: Run + README

**Files:**
- Create: `/Users/jbaubree/Projets/MeetingMeter/README.md`

- [ ] **Step 1: Build**

Run: `cd /Users/jbaubree/Projets/MeetingMeter && xcodegen generate && xcodebuild -scheme MeetingMeter -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 2: Launch and verify menu bar icon**

Run: `open ~/Library/Developer/Xcode/DerivedData/MeetingMeter-*/Build/Products/Debug/MeetingMeter.app && sleep 3 && pgrep -lf MeetingMeter | head -1`
Expected: a `MeetingMeter` process is running.

- [ ] **Step 3: Smoke test (manual, user action required)**

Prompt the user to:
1. Grant Accessibility + Screen Recording permissions when asked.
2. Open Teams, join a test meeting.
3. Observe the menu-bar label updating (`"— €"` first, then real cost).
4. Open the popover, cycle through Meeting / History / Settings tabs.
5. Leave the meeting; observe the end-of-meeting notification and the history entry.

If any step fails, surface the exact behavior and stop. The two most likely failure modes:
- Teams bundle id mismatch → nothing detected. Fix: update `candidateBundleIds` in `TeamsWindowDetector.swift`.
- OCR never reads a count → Teams UI language outside the keyword set. Fix: add a keyword in `OCRParticipantParser.swift`.

- [ ] **Step 4: Write `README.md`**

Create `/Users/jbaubree/Projets/MeetingMeter/README.md` with this content:

```markdown
# MeetingMeter

Compteur en direct du coût d'une réunion Microsoft Teams, affiché dans la barre de menus macOS. OCR du nombre de participants, 1 Hz, calcul `nb participants × taux_horaire × Δt` avec un taux configurable.

## Fonctionnalités

- Détection automatique d'une fenêtre Teams en meeting (multilingue : EN/FR/DE/ES)
- Capture + OCR de la fenêtre à 1 Hz pour extraire le compteur de participants
- Compteur de coût ticking (1 Hz) dans la barre de menus
- Taux journalier, heures de travail et devise configurables (défauts : 500 €, 8 h, €)
- Notification macOS à la fin de la réunion avec le total
- Historique des réunions passées persisté
- Zéro réseau, zéro télémétrie

## Prérequis

- macOS 14 (Sonoma) ou plus
- Xcode 15+ et `xcodegen` pour builder (`brew install xcodegen`)
- Permissions Accessibilité **et** Enregistrement d'écran (demandées au premier lancement)
- Microsoft Teams desktop installé

## Build & lancement

```bash
xcodegen generate
xcodebuild -scheme MeetingMeter -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/MeetingMeter-*/Build/Products/Debug/MeetingMeter.app
```

Signature ad-hoc : au premier lancement, clic droit → **Ouvrir** → **Ouvrir** dans la confirmation Gatekeeper.

Si une permission ne tient plus après un rebuild :

```bash
pkill -f MeetingMeter
tccutil reset Accessibility com.jbaubree.MeetingMeter
tccutil reset ScreenCapture com.jbaubree.MeetingMeter
open ~/Library/Developer/Xcode/DerivedData/MeetingMeter-*/Build/Products/Debug/MeetingMeter.app
```

## Utilisation

1. Lance Teams et rejoins une réunion.
2. L'icône dans la barre de menus affiche `— €` puis le coût réel dès que l'OCR a lu le nb de participants.
3. Clique l'icône pour voir le détail (participants, durée, taux), l'historique, ou changer les paramètres.
4. Quitte la réunion : une notification résume la durée et le coût total, et l'entrée est archivée.

## Limitations

- **Teams desktop uniquement.** Pas de support Teams dans un navigateur.
- **OCR dépendant de l'UI Teams.** Si Microsoft change le format du compteur de participants, l'app peut passer à côté. Les patterns reconnus : `N participants`, `N people`, `N personnes`, `N Teilnehmer`, `N personas` (et l'ordre inverse).
- **Fenêtre Teams minimisée.** ScreenCaptureKit ne capture pas une fenêtre minimisée → le compteur gèle sur la dernière valeur connue mais continue à compter.
- **Signature ad-hoc.** Pas de Developer ID. Les permissions sont à redonner après chaque rebuild.

## Non-objectifs

- Pas d'enregistrement audio/vidéo.
- Pas de capture mémoire ni d'injection dans le process Teams.
- Pas de taux par participant.

## Architecture

Deux targets :

- **MeetingMeterCore** (framework) — logique testable : `RateCalculator`, `MeetingSession`, `MeetingRecord`, `MeetingHistoryStore`, `Preferences`, `TeamsTitleMatcher`, `OCRParticipantParser`.
- **MeetingMeter** (app) — glue AppKit/SwiftUI :
  - `TeamsWindowDetector` : AX API + `NSWorkspace` + `AXObserver` + poll 5 s
  - `ScreenCaptureService` : `SCScreenshotManager` sur la fenêtre Teams, crop top 25 %
  - `OCRService` : `VNRecognizeTextRequest` fast + délégation au parser Core
  - `NotificationService` : `UNUserNotificationCenter`
  - UI SwiftUI dans un `NSPopover` attaché à un `NSStatusItem`

Tests XCTest sur la Core (RateCalculator, MeetingSession, parsers, persistence). Les services système ne sont pas testés automatiquement.
```

- [ ] **Step 5: Commit**

```bash
cd /Users/jbaubree/Projets/MeetingMeter
git add README.md
git -c user.name="Jean-Baptiste Aubrée" -c user.email="jb.aubree.dev@gmail.com" commit -m "docs: add README with build + smoke test"
```

---

## Self-review notes

**Spec coverage check:**
- F1 (detect Teams meeting) → Tasks 2, 8
- F2 (capture + OCR 1 Hz) → Tasks 3, 9, 10, 18
- F3 (ticking cost in menu bar) → Tasks 7, 17, 18
- F4 (configurable rate/hours/currency) → Tasks 4, 15
- F5 (end-of-meeting notification) → Tasks 11, 18
- F6 (persisted history) → Tasks 5, 6, 14, 18
- F7 (popover 3 tabs) → Tasks 13, 14, 15, 16
- F8 (dual onboarding) → Tasks 12, 16

All 13 components from spec section 3 → one task each (Task 0 handles scaffolding; Task 18 integrates all).

**Deviations from spec:**
- Spec section 12 said target macOS 14+ after my inline fix. Plan matches.
- Spec section 14 structure listed `MeetingMeterCore.swift` only implicitly as a placeholder. Plan creates and then deletes it in Task 1.

**Type consistency:**
- `MeetingSession.start(at:)` / `.end(at:)` / `.tick(interval:)` / `.updateParticipantCount(_:)` — consistent across Tasks 7, 18.
- `TeamsWindowDetector.DetectedMeeting` struct (pid + title) — Tasks 8, 18.
- `ScreenCaptureService.captureTopBand(for:)` returns `CGImage` — Tasks 9, 18.
- `OCRService.recognizeParticipantCount(from:)` takes `CGImage` returns `Int?` — Tasks 10, 18.
- `NotificationService.postMeetingEnded(totalCost:currency:durationSeconds:)` — Tasks 11, 18.
- `Preferences` fields `dailyRate`, `workDayHours`, `currencySymbol` — consistent across Tasks 4, 15, 16, 18.
- `MeetingRecord` all fields — consistent across Tasks 5, 6, 14, 18.
