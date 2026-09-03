import Foundation
import GameKit
import UIKit

/// Asynchronous 1v1 ghost races on Game Center turn-based matches.
///
/// Flow: player A opens the matchmaker and invites B (or auto-matches).
/// A flies; A's run (score + ghost trace) is stored in the match data and the
/// turn passes to B. B's game receives the match, races A's ghost, and when B's
/// run ends both runs are compared and the match is settled. Match data is JSON:
///   {"runs": {"<gamePlayerID>": entry, ...}}
///
/// Enable turn-based matches for the app in App Store Connect → Game Center.
final class AsyncMatchManager: NSObject {
    static let shared = AsyncMatchManager()
    weak var bridge: GameBridge?

    private var activeMatch: GKTurnBasedMatch?
    private var pendingPayload: [String: Any]?

    func openMatchmaker() {
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        request.inviteMessage = "Race my ghost in Starflappy 64!"
        let vc = GKTurnBasedMatchmakerViewController(matchRequest: request)
        vc.turnBasedMatchmakerDelegate = self
        vc.showExistingMatches = true
        GameCenterManager.rootViewController?.present(vc, animated: true)
    }

    /// Hand the opponent's run (if they have flown) to the page as the rival ghost.
    func present(match: GKTurnBasedMatch) {
        activeMatch = match
        let runs = Self.runs(from: match.matchData)
        let me = GKLocalPlayer.local.gamePlayerID
        let opponent = match.participants.first { $0.player?.gamePlayerID != me && $0.player != nil }
        var payload: [String: Any] = ["type": "match", "matchId": match.matchID]
        if let opponentID = opponent?.player?.gamePlayerID, let run = runs[opponentID] {
            var entry = run
            entry["id"] = opponentID
            entry["name"] = opponent?.player?.displayName ?? "RIVAL"
            payload["opponent"] = entry
        } else {
            payload["opponent"] = NSNull()
        }
        pendingPayload = payload
        deliverPendingMatch()
    }

    func deliverPendingMatch() {
        guard let payload = pendingPayload, let bridge else { return }
        bridge.send(payload)
        pendingPayload = nil
    }

    /// The local player's finished run for the active match.
    func submitRun(matchID: String, entry: [String: Any]) {
        guard let match = activeMatch, match.matchID == matchID else { return }
        var runs = Self.runs(from: match.matchData)
        let me = GKLocalPlayer.local.gamePlayerID
        runs[me] = entry
        guard JSONSerialization.isValidJSONObject(["runs": runs]),
              let data = try? JSONSerialization.data(withJSONObject: ["runs": runs]) else { return }

        if runs.count >= 2 {
            // Both pilots have flown: settle it.
            for participant in match.participants {
                guard let pid = participant.player?.gamePlayerID else { participant.matchOutcome = .tied; continue }
                let mine = runs[pid]?["score"] as? Int ?? 0
                let theirs = runs.first { $0.key != pid }?.value["score"] as? Int ?? 0
                participant.matchOutcome = mine == theirs ? .tied : (mine > theirs ? .won : .lost)
            }
            match.endMatchInTurn(withMatch: data) { error in
                if let error { print("Game Center: end match failed (\(error.localizedDescription))") }
            }
        } else {
            let next = match.participants.filter { $0.player?.gamePlayerID != me }
            match.endTurn(withNextParticipants: next, turnTimeout: GKTurnTimeoutDefault, match: data) { error in
                if let error { print("Game Center: end turn failed (\(error.localizedDescription))") }
            }
        }
        activeMatch = nil
    }

    private static func runs(from data: Data?) -> [String: [String: Any]] {
        guard let data, !data.isEmpty,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let runs = obj["runs"] as? [String: [String: Any]] else { return [:] }
        return runs
    }
}

extension AsyncMatchManager: GKTurnBasedMatchmakerViewControllerDelegate {
    func turnBasedMatchmakerViewControllerWasCancelled(_ viewController: GKTurnBasedMatchmakerViewController) {
        viewController.dismiss(animated: true)
    }

    func turnBasedMatchmakerViewController(_ viewController: GKTurnBasedMatchmakerViewController, didFailWithError error: Error) {
        viewController.dismiss(animated: true)
        print("Game Center: matchmaker failed (\(error.localizedDescription))")
    }
}

extension AsyncMatchManager: GKLocalPlayerListener {
    func player(_ player: GKPlayer, receivedTurnEventFor match: GKTurnBasedMatch, didBecomeActive: Bool) {
        GameCenterManager.rootViewController?.presentedViewController?.dismiss(animated: true)
        present(match: match)
    }

    func player(_ player: GKPlayer, matchEnded match: GKTurnBasedMatch) {
        present(match: match)
    }
}
