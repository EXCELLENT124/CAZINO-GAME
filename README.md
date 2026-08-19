# CAZINO

CAZINO is an initial cross-platform Flutter prototype for a private-hand, two-player card game. It includes authentication, registration with unique usernames, profiles, lobby/challenges, chat, game UI, a pure Dart turn engine, configurable scoring, and tests. FICA verification is temporarily removed from the user flow.

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

The demo does **not** perform real KYC or make identity claims. FICA verification is deferred until a compliant provider and reviewed workflow are ready.

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

## Online Supabase setup

Packaged CAZINO builds use the live Supabase project by default, including Android, iOS, web, and Windows artifacts produced by GitHub Actions. Real accounts can sign in with a unique username or email address and use online presence, friend requests, challenges, chat, wallets, and wagers.

The offline demonstration is opt-in for local development only:

```sh
flutter run --dart-define=CAZINO_OFFLINE_DEMO=true
```

Normal builds must never silently enter demo mode. The project URL and publishable client key have safe defaults and can still be overridden with `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`. Never put a Supabase secret or service-role key in the Flutter application.

1. Create a separate Supabase project named `CAZINO GAME` (do not use an unrelated project).
2. Open Supabase **SQL Editor** and run `supabase/migrations/202608190001_online_cazino.sql` once.
3. In **Authentication → URL Configuration**, add the deployed web URL and mobile redirect URLs.
4. For the current one-screen registration flow, turn off email confirmation during local testing. Before production, enable confirmation and add a post-confirmation profile completion screen.
5. Copy the Project URL and publishable key from Supabase. Never place a service-role key in Flutter.
6. Run with:

```powershell
flutter run -d chrome --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

For this repository, VS Code now includes **CAZINO Online (Chrome)** and **CAZINO Online (Select Device)** launch configurations connected to the CAZINO GAME project. Open **Run and Debug**, choose one, and press the green Run button.

Use the same two `--dart-define` values for Android, iOS, and Windows builds. Publishable keys are safe to embed because database access is protected by Row Level Security; service-role keys are not.

### Coins and wagers

- Each signed-in player may claim 500 virtual coins once per UTC day. The claim is idempotent in the database.
- Allowed equal stakes are 100, 150, 200, 250, 300, 350, 400, and 500. The requested `2900` was treated as a likely typo for `200`; edit both `AppController.allowedStakes` and the SQL checks if 2,900 was intended.
- Accepting a challenge atomically verifies both balances, deducts both stakes, records ledger entries, and creates a pot worth twice the stake.
- Winner settlement is service-role-only. Before real online wagering is enabled, deploy an authoritative server game validator that replays signed game actions and calls `settle_game_authoritative`. The Flutter client must never choose the winner for payment.
- Coins are virtual, have no cash value, cannot be purchased, transferred, or withdrawn in this version. Obtain legal advice before enabling purchases, cash prizes, or gambling-like features.

### Real-time two-player matches

- Run both SQL migrations in filename order. The second adds challenge joining, optimistic match versions, turn ownership checks, an event audit log, indexes, and the `game_sessions` Realtime publication.
- A recipient can accept a pending challenge. Supabase atomically escrows both stakes and creates one game session. Both players can then press **Join** on the accepted challenge.
- Each accepted move updates the shared snapshot only when its version is current and the authenticated caller owns the current turn. Both phones receive the update through Supabase Realtime.
- The app disables manual **Switch Player** during an online match and prevents another local action while the previous move is synchronizing.
- This is functional trusted-client multiplayer, not the final anti-cheat boundary. The current snapshot contains complete deterministic engine state so a technically modified client could inspect hidden cards or propose an invalid state. Do not enable purchased/cash-convertible coins until move validation and private-hand custody are moved into an authoritative Edge Function or server.

### Privacy and deferred FICA

Lobby users can read only usernames/display names, presence, and public wallet balance. Phone, identity number, date of birth, and address are isolated in `private_profiles` with owner-only policies. The FICA screen is currently disabled and users proceed directly to the home screen after registration.
