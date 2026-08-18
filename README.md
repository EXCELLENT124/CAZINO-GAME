# CAZINO

CAZINO is an initial cross-platform Flutter prototype for a private-hand, two-player card game. It includes local demo authentication, registration and address capture, a metadata-only FICA workflow, profiles, lobby/challenges, chat, game UI, a pure Dart turn engine, configurable scoring, and tests.

## Run locally

Requirements: Flutter 3.22 or newer, Dart 3.3 or newer, and the platform tooling for the target.

```sh
flutter pub get
dart test
flutter run -d chrome
```

Other targets:

```sh
flutter run -d android
flutter run -d ios
flutter run -d windows
```

- Android: install Android Studio/SDK, accept licences, and start an emulator or connect a device.
- iOS: run on macOS with Xcode and CocoaPods installed; select a simulator or signing team.
- Windows: install Visual Studio with “Desktop development with C++”.
- Web: install Chrome. `flutter build web` creates a deployable build.

Demo login: `lebo@cazino.demo` / `demo123` (any non-empty password works in the in-memory adapter).

## Architecture and security boundary

- `lib/domain`: card model, state, engine, privacy projection, and scoring. It has no Flutter or backend dependency.
- `lib/data`: repository contracts plus a memory-only demo adapter.
- `lib/app`: application controller.
- `lib/main.dart`: Material UI and navigation.

The demo does **not** perform real KYC, upload files, persist passwords, or make identity claims. Production should implement the repository contracts with Supabase/Firebase plus an approved KYC provider, server-authoritative game actions, private object storage, row-level access control, encryption, audit logs, consent/retention policies, malware scanning, and jurisdiction-specific POPIA/FICA review. Never store identity documents in public buckets or application logs.

## Rules aligned with Khasino Rules v1.1

The two-player engine now treats the supplied Khasino Rules v1.1 PDF as the primary rules reference, with the user's explicit CAZINO clarifications applied where the document leaves room for local terminology or presentation.

- The 40-card deck is a standard deck with picture cards removed; Ace is 1 and the maximum build is 10.
- A player plays exactly one hand card per turn. A non-capturing play is called a drift.
- A chow/capture may take matching single cards, sets of loose cards that each total the played rank, and any selected builds of that rank.
- A simple build requires the builder to retain a hand card matching its value. Cards are stored largest-to-smallest so the smallest is visually on top.
- Only an opponent-owned simple build may have its value changed, using one hand card while retaining the new target card.
- A compound build contains two or more groups of the same value. Its value is locked, though its owner can augment it with another complete group of that same value.
- Two separate builds cannot be combined to form a higher build, and duplicate build values may not remain separately on the table.
- In round 1 of a two-player game, a player who owns an outstanding build cannot drift. Round 2 allows drifting.
- The last player to capture receives all loose cards and builds remaining when the game ends.
- Official two-player scoring is 11 points: four Aces (1 each), two of spades (1), ten of diamonds/razer (2), most cards (2), and most spades (2). Ties for most cards or spades split that category 1-1.

## Remaining implementation scope and ambiguities

1. The supplied rules resolve the earlier “7 fixed points” ambiguity: the ten of diamonds/razer is worth 2 points, so four Aces + spy two + mummy total 7.
2. “Black heart” is treated as the requested black spade because later scoring repeatedly says spades.
3. Razer and tree use diamond and club glyphs as temporary visual symbols; final art and suit terminology need confirmation.
4. A construct uses one played hand card plus selected loose, publicly visible table cards. It is legal only if their ranks form the target and the player retains another hand card of that target rank.
5. Version 1 automatically folds in other loose visible cards that independently complete `played card + visible card = target`. Multi-group/cascading build semantics need confirmation.
6. Captured packs are private and cannot be used for constructs. Only counts are projected to the opponent.
7. A take-off captures the played card and all loose visible cards of the same rank. Capture of builds, ownership restrictions, and multi-card arithmetic captures remain to be specified.
8. “Previous-round winner/host plays second” is interpreted as: the other player opens round 2. If nobody captured in round 1, the host is considered the round winner for order purposes.
9. Loose table cards/builds remain between rounds. End-of-game ownership of remaining table cards needs confirmation.
10. The earlier fixed thresholds for five/six spades and 20/21 cards have been replaced by the PDF's majority rules: most spades and most cards each award 2, with 1-1 on a tie.
11. Ties are resolved by captured-card count, then lexicographically stable player ID. This guarantees one winner but is explicitly a placeholder.
12. Opponent capture-pile augmentation, repeated exposure of newly uncovered top cards, stash/shiya partnership calls, table-only multi-actions within one turn, three/four-player flow, and partnership play require a richer multi-action turn transaction and are reserved for the next iteration.
13. Challenge acceptance, presence, moderation, message retention, reconnect/timeouts, forfeits, anti-cheat, and server conflict resolution are backend concerns reserved for the next iteration.

## Tests

Tests cover the 40-card deck, shuffled two-stage deal, private player projection, take-off, valid/invalid constructs, automatic visible-card inclusion, round transition/order, scoring ambiguity, and deterministic ties.
