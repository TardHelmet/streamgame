import Foundation
import GameKit
import UIKit

/// Game Center: sign-in, the access point, leaderboards, achievements.
///
/// Configure these IDs in App Store Connect → your app → Game Center:
///   Leaderboards  sf64.score (integer, high-to-low), sf64.distance (integer, high-to-low)
///   Achievements  sf64.ach.<id> for every id in ACHIEVEMENTS below
final class GameCenterManager: NSObject {
    static let shared = GameCenterManager()
    weak var bridge: GameBridge?

    static let scoreBoardID = "sf64.score"
    static let distanceBoardID = "sf64.distance"
    static let achievements = ["first_flight", "dist_1000", "dist_5000", "barrel_roll", "series_10",
                               "full_school", "under_keel", "skip_3", "night_owl"]
    static func achievementID(_ id: String) -> String { "sf64.ach.\(id)" }

    private(set) var isAuthenticated = false

    /// Game Center leaderboards carry scores, not flight paths, so each
    /// player's best ghost trace is kept on-device and attached to their
    /// row when the board is loaded. Async 1v1 matches carry traces in
    /// the match data (see AsyncMatchManager).
    private var localGhosts: [String: [String: Any]] = [:]

    override init() {
        super.init()
        loadGhosts()
    }

    // MARK: sign-in

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            guard let self else { return }
            if let vc = viewController {
                Self.rootViewController?.present(vc, animated: true)
                return
            }
            self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
            if self.isAuthenticated {
                GKAccessPoint.shared.location = .topTrailing
                GKAccessPoint.shared.showHighlights = true
                GKAccessPoint.shared.isActive = true
                GKLocalPlayer.local.register(AsyncMatchManager.shared)
                self.sendPlayer()
                self.loadTop(50)
            } else if let error {
                print("Game Center: not signed in (\(error.localizedDescription))")
                self.sendPlayer()
            }
        }
    }

    func sendPlayer() {
        let p = GKLocalPlayer.local
        bridge?.send([
            "type": "player",
            "id": p.isAuthenticated ? p.gamePlayerID : "",
            "name": p.isAuthenticated ? p.displayName : "",
        ])
    }

    // MARK: leaderboards

    func submit(entry: [String: Any]) {
        guard isAuthenticated else { return }
        let score = entry["score"] as? Int ?? 0
        let dist = entry["dist"] as? Int ?? 0
        localGhosts[GKLocalPlayer.local.gamePlayerID] = entry
        saveGhosts()
        GKLeaderboard.submitScore(score, context: dist, player: GKLocalPlayer.local,
                                  leaderboardIDs: [Self.scoreBoardID]) { error in
            if let error { print("Game Center: score submit failed (\(error.localizedDescription))") }
        }
        GKLeaderboard.submitScore(dist, context: score, player: GKLocalPlayer.local,
                                  leaderboardIDs: [Self.distanceBoardID]) { _ in }
    }

    func loadTop(_ n: Int) {
        guard isAuthenticated else {
            bridge?.send(["type": "board", "entries": []])
            return
        }
        GKLeaderboard.loadLeaderboards(IDs: [Self.scoreBoardID]) { [weak self] boards, _ in
            guard let self, let board = boards?.first else {
                self?.bridge?.send(["type": "board", "entries": []])
                return
            }
            let range = NSRange(location: 1, length: max(1, min(n, 100)))
            board.loadEntries(for: .global, timeScope: .allTime, range: range) { _, entries, _, _ in
                var list: [[String: Any]] = []
                for e in entries ?? [] {
                    var row: [String: Any] = [
                        "id": e.player.gamePlayerID,
                        "name": e.player.displayName,
                        "score": e.score,
                        "dist": e.context,
                        "rank": e.rank,
                        "ts": Int(e.date.timeIntervalSince1970 * 1000),
                    ]
                    if let ghost = self.localGhosts[e.player.gamePlayerID], let trace = ghost["trace"] as? String {
                        row["trace"] = trace
                        row["rings"] = ghost["rings"] ?? 0
                        row["fish"] = ghost["fish"] ?? 0
                    }
                    list.append(row)
                }
                self.bridge?.send(["type": "board", "entries": list])
            }
        }
    }

    func showLeaderboard() {
        let vc = GKGameCenterViewController(leaderboardID: Self.scoreBoardID, playerScope: .global, timeScope: .allTime)
        vc.gameCenterDelegate = self
        Self.rootViewController?.present(vc, animated: true)
    }

    // MARK: achievements

    func report(achievement id: String, percent: Double) {
        guard isAuthenticated, Self.achievements.contains(id) else { return }
        let a = GKAchievement(identifier: Self.achievementID(id))
        a.percentComplete = percent
        a.showsCompletionBanner = true
        GKAchievement.report([a]) { error in
            if let error { print("Game Center: achievement failed (\(error.localizedDescription))") }
        }
    }

    // MARK: local ghost persistence

    private var ghostsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ghosts.json")
    }

    private func saveGhosts() {
        guard JSONSerialization.isValidJSONObject(localGhosts),
              let data = try? JSONSerialization.data(withJSONObject: localGhosts) else { return }
        try? data.write(to: ghostsURL, options: .atomic)
    }

    private func loadGhosts() {
        guard let data = try? Data(contentsOf: ghostsURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else { return }
        localGhosts = obj
    }

    // MARK: helpers

    static var rootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}

extension GameCenterManager: GKGameCenterControllerDelegate {
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
