# MeetingMeter

Compteur en direct du coût d'une réunion Microsoft Teams, affiché dans la barre de menus macOS. OCR du nombre de participants, 1 Hz, calcul `nb participants × taux_horaire × Δt` avec un taux configurable.

## Fonctionnalités

- Détection automatique d'une fenêtre Teams en meeting (multilingue : EN/FR/DE/ES)
- Capture + OCR de la fenêtre à 1 Hz pour extraire le compteur de participants
- Compteur de coût ticking (1 Hz) dans la barre de menus
- Taux journalier, heures de travail et devise configurables (défauts : 650 €, 8 h, €)
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

### Permissions qui sautent après chaque rebuild

**Symptôme :** l'app affiche "Autorisations requises" alors que tu as déjà cliqué sur les toggles dans Réglages Système.

**Cause :** la signature ad-hoc change à chaque `xcodebuild`. macOS stocke les permissions TCC par signature (pas par bundle id seul), donc après un rebuild l'ancienne entrée ne match plus la nouvelle binaire. Résultat : le toggle est ON dans Réglages Système mais l'app voit `isTrusted = false`.

**Fix** (à relancer après chaque rebuild) :

```bash
pkill -f MeetingMeter
tccutil reset Accessibility com.jbaubree.MeetingMeter
tccutil reset ScreenCapture com.jbaubree.MeetingMeter
open ~/Library/Developer/Xcode/DerivedData/MeetingMeter-*/Build/Products/Debug/MeetingMeter.app
```

Puis re-coche les 2 permissions dans Réglages Système → Confidentialité et sécurité.

**Solution pérenne (optionnelle) :** signer avec un vrai **Developer ID** au lieu d'ad-hoc. La signature devient stable entre rebuilds et les permissions TCC tiennent. Nécessite un abonnement Apple Developer (99 €/an) et un cert `Developer ID Application`. Modifier dans `project.yml` : `CODE_SIGN_IDENTITY: "Developer ID Application"` + `DEVELOPMENT_TEAM: <ton team id>`.

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

44 tests XCTest sur la Core. Les services système ne sont pas testés automatiquement.

## Licence

MIT.
