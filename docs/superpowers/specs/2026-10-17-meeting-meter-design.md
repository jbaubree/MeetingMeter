# MeetingMeter — Design Spec

**Date :** 2026-10-17
**Status :** Draft (en cours de validation utilisateur)

## 1. Objectif

Une app macOS dans la barre de menus qui, pendant une réunion Microsoft Teams, lit automatiquement le nombre de participants et affiche en continu le coût agrégé de la réunion. Pensée pour responsabiliser sur le temps collectif passé en meeting : "cette réunion vient de brûler 300 €".

**Non-objectifs :**
- Pas d'enregistrement audio/vidéo
- Pas de capture mémoire ou injection dans Teams
- Pas de support Teams dans un navigateur web (v1 = app desktop uniquement)
- Pas de taux par participant (tarif unique configurable)
- Pas de télémétrie, pas de réseau sortant

## 2. Fonctionnalités

| ID | Feature |
|---|---|
| F1 | Détection automatique d'une fenêtre Teams en meeting |
| F2 | Capture + OCR de la fenêtre Teams à 1 Hz pour extraire le nombre de participants |
| F3 | Compteur de coût ticking (1 Hz) dans la barre de menus pendant la réunion |
| F4 | Taux journalier et heures de travail configurables (défauts : 500 €, 8 h) |
| F5 | Notification macOS à la fin de la réunion avec coût total |
| F6 | Historique des réunions passées persisté (date, durée, participants moyen, coût) |
| F7 | Popover avec : meeting courant, settings, historique |
| F8 | Onboarding des deux permissions (Accessibility + Screen Recording) |

## 3. Architecture

### Composants

| Composant | Responsabilité | Target | Dépendances |
|---|---|---|---|
| `TeamsWindowDetector` | Localiser la fenêtre Teams en meeting via AX + NSWorkspace | App | AX API |
| `ScreenCaptureService` | Capturer l'image de la fenêtre Teams à 1 Hz | App | ScreenCaptureKit |
| `OCRService` | Extraire le nb de participants d'une image | App | Vision |
| `RateCalculator` | Calcul pur : `(count, Δt, dailyRate, workHours) → cost` | Core | — |
| `MeetingSession` | État de la réunion courante, tick 1 Hz | Core | — |
| `MeetingRecord` | Value type pour une réunion archivée | Core | — |
| `MeetingHistoryStore` | Persistance JSON de l'historique | Core | — |
| `Preferences` | Codable : taux + heures de travail, UserDefaults | Core | — |
| `PreferencesStore` | Wrapper UserDefaults | Core | — |
| `MenuBarController` | `NSStatusItem` avec label ticking | App | AppKit |
| `PopoverRootView` + sous-vues | SwiftUI : meeting courant, settings, history, onboarding | App | SwiftUI |
| `NotificationService` | Notif macOS fin de meeting | App | UserNotifications |

### Data flow

```
TeamsWindowDetector ──▶ meetingWindow(found)
            │                     │
            │                     ▼
            │        ScreenCaptureService
            │                     │  (image, 1Hz)
            │                     ▼
            │                OCRService
            │                     │  (count, 1Hz)
            │                     ▼
            └────────────▶  MeetingSession
                                  │   (tick 1s)
                 ┌────────────────┼────────────────┐
                 ▼                ▼                ▼
         MenuBar label     PopoverRootView   on-end: history + notif
```

`MeetingSession` est la source de vérité unique de l'état "live". Les autres composants ne communiquent pas entre eux directement.

## 4. Détection d'un meeting Teams

**Identification du process Teams :**
- Filtrer `NSWorkspace.shared.runningApplications` par `bundleIdentifier`.
- Candidats connus : `com.microsoft.teams2` (Teams moderne), `com.microsoft.teams` (ancien).
- **Point à vérifier au runtime** (comme Dofus) : le bundle id exact du Teams installé. L'app essaie les deux et prend le premier qui match.

**Identification d'une fenêtre en meeting :**
Via AX API, pour chaque fenêtre du process Teams, vérifier le titre contre un pattern :
- EN : `Meeting with …`, `Meeting in …`, `Call with …`
- FR : `Réunion avec …`, `Réunion dans …`, `Appel avec …`
- DE : `Besprechung …`
- ES : `Reunión …`

Pattern unifié (regex, case-insensitive) : `/(meeting|réunion|besprechung|reunión|call|appel)/i`

Si **aucun titre ne matche** mais que Teams a plusieurs fenêtres dont une avec un titre ne contenant pas "Microsoft Teams" en préfixe, on la considère comme candidate meeting (heuristique de secours).

**Synchronisation :**
- `NSWorkspace` notifications pour launch/terminate.
- `AXObserver` par process pour `kAXTitleChangedNotification`, `kAXWindowCreatedNotification`, `kAXUIElementDestroyedNotification`.
- Poll de secours toutes les 5 s (plus long que DofusSwitch car moins critique).

## 5. Capture + OCR

**Capture :**
- `ScreenCaptureKit` (macOS 12.3+, cible 13+ OK).
- `SCContentFilter(desktopIndependentWindow: scWindow)` pour capturer uniquement la fenêtre Teams, pas le fond d'écran.
- `SCStreamConfiguration` : `pixelFormat = kCVPixelFormatType_32BGRA`, `queueDepth = 3`.
- Fréquence : 1 Hz pilotée côté MeetingSession, pas en streaming — on demande une frame ponctuelle à chaque tick via `SCScreenshotManager.captureImage(contentFilter:configuration:)` (macOS 14+ API) ou l'équivalent macOS 13 (`SCStream` avec stop immédiat).

**Crop :**
Sur l'image capturée, on crop la bande supérieure (top 25 % de hauteur) où se trouve en général la toolbar Teams (bouton People/Participants). Réduit le volume OCR de 75 %.

**OCR :**
- `VNRecognizeTextRequest`, `recognitionLevel = .fast` (on cherche des chiffres, pas de la prose), `usesLanguageCorrection = false`.
- Pattern de recherche dans les textes reconnus (regex, case-insensitive) :
  `/(\d+)\s*(people|participants?|personnes|teilnehmer|personas)/i`
  et
  `/(people|participants?|personnes|teilnehmer|personas)\s*(\d+)/i`
- Si aucun match : garder la dernière valeur connue (`lastKnownCount`).
- Si N scans consécutifs sans match (N = 10, soit 10 s) : afficher un indicateur "?" dans le menu bar, mais continuer à compter avec `lastKnownCount` tant qu'il existe.

**Première valeur :** tant qu'aucune lecture OCR n'a réussi, le menu bar affiche `"— €"` et le coût ne tick pas. Dès la première lecture valide, le compteur démarre à partir de ce moment.

## 6. Calcul du coût

```swift
public enum RateCalculator {
    /// Coût d'un intervalle de dt secondes avec N participants.
    public static func cost(
        participants: Int,
        intervalSeconds: Double,
        dailyRate: Double,
        workDayHours: Double
    ) -> Double {
        let perPersonPerSecond = dailyRate / (workDayHours * 3600.0)
        return Double(participants) * perPersonPerSecond * intervalSeconds
    }
}
```

Appelé chaque seconde par `MeetingSession.tick()` avec `intervalSeconds = 1`. L'accumulation garantit que les changements de participants au milieu du meeting sont pris en compte avec précision à la seconde.

Exemple : 500 €/jour, 8 h : `perPersonPerSecond = 500 / 28800 = 0,01736 €`. Pour 7 personnes pendant 30 min : `7 × 0,01736 × 1800 = 218,75 €`.

## 7. MeetingSession

```swift
public final class MeetingSession: ObservableObject {
    @Published public private(set) var state: State
    @Published public private(set) var cost: Double
    @Published public private(set) var elapsedSeconds: Double
    @Published public private(set) var lastKnownCount: Int?

    public enum State: Equatable {
        case idle
        case inMeeting(startedAt: Date)
    }

    public func start()                      // appelé quand detector détecte un meeting
    public func end() -> MeetingRecord?      // appelé quand detector perd la fenêtre
    public func updateParticipantCount(_ n: Int)
    public func tick(interval: Double)       // appelé 1 Hz par un timer

    // Pour le calcul final: participants moyen pondéré par le temps.
}
```

Entrées : `participantCount` (depuis OCR), tick (depuis timer). Sorties : `cost`, `elapsedSeconds`, et un `MeetingRecord` à la fin.

Les participants moyens sont calculés comme moyenne pondérée par le temps : on garde l'intégrale `∑(count_i × Δt_i)` et on divise par la durée totale à la fin.

## 8. Historique

```swift
public struct MeetingRecord: Codable, Equatable, Identifiable {
    public let id: UUID
    public let startedAt: Date
    public let endedAt: Date
    public let durationSeconds: Double
    public let avgParticipants: Double
    public let totalCost: Double
    public let dailyRateAtTheTime: Double
    public let workDayHoursAtTheTime: Double
}
```

**Stockage :** fichier JSON dans `~/Library/Application Support/MeetingMeter/history.json`. Chargé à la startup, saved à chaque fin de meeting. Pas de limite de taille — à voir si ça devient un problème (10 ans de meetings tiendront largement en RAM).

**UI historique :** list scrollable dans le popover, triée par date desc, chaque ligne affiche date + durée formatée + "N pers · Y €".

## 9. Préférences

```swift
public struct Preferences: Codable, Equatable {
    public var dailyRate: Double          // défaut 500
    public var workDayHours: Double       // défaut 8
    public var currencySymbol: String     // défaut "€"
}
```

Persistance dans UserDefaults, clé `com.jbaubree.MeetingMeter.preferences`, même pattern que DofusSwitch (decodeIfPresent pour backward-compat).

## 10. UI

### Menu bar

Pendant l'idle : juste l'icône (SF Symbol `eurosign.circle` ou l'icône Teams si résolvable).

Pendant un meeting :
- Icône + texte collé : `"— €"` tant que l'OCR n'a rien lu
- Puis `"42,37 €"` qui tick chaque seconde
- Format : `NumberFormatter` avec `.currencyAccounting` et le symbol choisi

### Popover

Trois modes :
1. **Idle** : "Aucune réunion détectée. Lance une réunion Teams pour commencer."
2. **In meeting** : grand compteur de coût, nombre de participants courant, durée écoulée, taux appliqué (petit texte en bas).
3. **Settings** (toggle) : champs taux journalier + heures/jour + currency, bouton "Reset".
4. **Historique** (toggle) : liste des meetings passés, bouton "Clear history".

Navigation : header avec icône courante + bouton engrenage settings + bouton horloge historique. Footer : Quit.

### Onboarding

Si Accessibility non accordée → écran 1 (comme DofusSwitch).
Si Screen Recording non accordée → écran 2.
Les deux sont séquentiels, bouton "Revérifier" sur chaque.

## 11. Permissions

- **Accessibility** (obligatoire) : lire les fenêtres de Teams via AX
- **Screen Recording** (obligatoire) : capturer l'image de la fenêtre Teams
- **UserNotifications** (optionnelle) : demander au premier affichage de notif
- Pas d'entitlement réseau, sandbox OFF (incompatible AX cross-process)

## 12. Packaging

Identique à DofusSwitch :
- Target macOS 13+
- LSUIElement = true (pas de Dock icon)
- Hardened runtime OFF (incompat ad-hoc en dev), Manual signing avec identity `-`
- XcodeGen pour générer `.xcodeproj`
- Ad-hoc signing en v1

## 13. Testing

**Unitaires (XCTest, cible Core) :**
- `RateCalculatorTests` — formules, edges (0 participants, 0 h)
- `MeetingSessionTests` — start/end lifecycle, moyenne pondérée, accumulation du coût
- `MeetingRecordTests` — Codable round-trip
- `MeetingHistoryStoreTests` — load/save file, concurrent writes safe
- `PreferencesTests` — Codable + backward-compat
- `TeamsTitleMatcherTests` — pattern multilingue
- `OCRParticipantParserTests` — regex sur texte reconnu, pattern variants

**Non testés automatiquement** (nécessitent macOS, Teams, screen rec) :
- `TeamsWindowDetector`
- `ScreenCaptureService`
- `OCRService` (en end-to-end avec Vision)
- `MenuBarController`, UI SwiftUI

**Smoke test manuel documenté** dans le README (joindre une réunion Teams de test, vérifier compteur, participants, fin).

## 14. Structure du projet

```
MeetingMeter/
├── project.yml
├── Sources/
│   ├── MeetingMeterCore/
│   │   ├── RateCalculator.swift
│   │   ├── MeetingSession.swift
│   │   ├── MeetingRecord.swift
│   │   ├── MeetingHistoryStore.swift
│   │   ├── Preferences.swift
│   │   ├── PreferencesStore.swift
│   │   ├── TeamsTitleMatcher.swift
│   │   └── OCRParticipantParser.swift
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
│       └── (7 fichiers de test)
├── docs/
│   └── superpowers/
│       └── specs/
│           └── 2026-10-17-meeting-meter-design.md
├── README.md
├── LICENSE
└── .gitignore
```

## 15. Risques & questions ouvertes

| Risque | Mitigation |
|---|---|
| Bundle ID Teams inconnu | Essayer `com.microsoft.teams2` puis `com.microsoft.teams`, documenter dans README |
| Teams change son UI → regex OCR casse | Patterns multilingues, N-échecs → placeholder "?" sans crasher |
| Fenêtre Teams minimisée | ScreenCaptureKit ne capture pas une fenêtre minimisée → freeze lastKnownCount |
| OCR 1Hz CPU-heavy | Crop top 25 % de la fenêtre, `.fast` recognition, pas de language correction |
| Permission Screen Recording = big ask | Onboarding explicite, bénéfice immédiat visible |
| Teams web (navigateur) | Hors scope v1, documenté |
| Historique illimité → fichier qui grossit | Pas de limite v1, si problème : rotation annuelle |

## 16. Scope v1 vs plus tard

**v1 (ce spec) :**
F1–F8 ci-dessus. 7 tests Core.

**Explicitement reporté (potentiel v2) :**
- Support Teams Web (via WebKit frameworks ou DOM parsing)
- Support Zoom, Google Meet, Slack huddles
- Taux par participant
- Export CSV de l'historique
- Agrégats statistiques (coût total du mois, top 5 réunions les plus chères)
- Developer ID signing + notarization + DMG
- Alertes (notif si une réunion dépasse X €)
