# Starflappy 64 — iOS

A native iOS app that hosts the web game in a `WKWebView` and wires it to
Game Center through a small JavaScript ⇄ Swift bridge. The game itself is the
same `index.html` as the web build (copied into `Starflappy64/web/`).

## Open and run

1. `open ios/Starflappy64.xcodeproj` (Xcode 15 or newer, iOS 16+).
   Prefer XcodeGen? `brew install xcodegen && cd ios && xcodegen generate`
   rebuilds the project from `project.yml`.
2. Select the **Starflappy64** target → *Signing & Capabilities* → pick your
   team and set a unique bundle identifier (default `com.example.starflappy64`).
   The **Game Center** capability is already in the entitlements file.
3. Run on a device or simulator signed in to Game Center (Settings → Game Center).
   Without sign-in the game still plays; the leaderboard shows as empty.

After editing the web game, run `ios/sync-web.sh` (or copy `index.html` into
`Starflappy64/web/`) so the bundle picks it up.

## Game Center setup (App Store Connect → your app → Game Center)

| Kind | ID | Notes |
| --- | --- | --- |
| Leaderboard | `sf64.score` | integer, high-to-low, all-time — the main board |
| Leaderboard | `sf64.distance` | integer, high-to-low — metres flown |
| Achievement | `sf64.ach.first_flight` | First Flight |
| Achievement | `sf64.ach.dist_1000` | Kilometer Club |
| Achievement | `sf64.ach.dist_5000` | Long Haul |
| Achievement | `sf64.ach.barrel_roll` | Do a Barrel Roll |
| Achievement | `sf64.ach.series_10` | Ten-Ring Circus (clear a 10-ring series) |
| Achievement | `sf64.ach.full_school` | All You Can Eat (scoop a school of 5+) |
| Achievement | `sf64.ach.under_keel` | Under the Keel (dive under a container ship) |
| Achievement | `sf64.ach.skip_3` | Skipping Stone (three skips in a row) |
| Achievement | `sf64.ach.night_owl` | Night Shift (survive the opening night) |

Also enable **turn-based multiplayer** for the app so the async ghost
challenges can create matches.

## What talks to what

- `GameView.swift` — the web view; loads `web/index.html`.
- `GameBridge.swift` — `WKScriptMessageHandler` on the `starflappy` channel.
  The page posts `{type, ...}` messages; the app answers by calling
  `window.__sf.onNative({...})`. Message list is documented in the file.
- `GameCenterManager.swift` — sign-in (`GKLocalPlayer.authenticateHandler`),
  the `GKAccessPoint`, score submission to both leaderboards (with the other
  stat in `context`), loading the top entries back into the in-game board,
  achievement reporting, and the native leaderboard UI.
  Game Center leaderboards carry numbers only, so each player's best ghost
  trace is stored on-device and attached to their own row; opponents' ghosts
  come from matches.
- `AsyncMatchManager.swift` — asynchronous 1v1 ghost races as
  `GKTurnBasedMatch`es: the challenger flies, their run (score + ghost trace)
  goes into the match data, the turn passes to the opponent, who races that
  ghost; when both have flown the outcome is settled and both see it in the
  Game Center match list. The page receives `{type:"match", opponent}` and
  races that ghost; it reports back with `matchResult`.

The Swift sources were written without access to Xcode in the authoring
environment — build once and fix anything the compiler flags before shipping.
