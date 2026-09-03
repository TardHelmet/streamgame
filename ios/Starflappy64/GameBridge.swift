import Foundation
import WebKit

/// JS ⇄ Swift bridge.
///
/// Page → app:  window.webkit.messageHandlers.starflappy.postMessage({type, ...})
/// App → page:  window.__sf.onNative({type, ...})
///
/// Message types the page sends:
///   ready                       page loaded; reply with `player` and any pending match
///   top {n}                     request the leaderboard → reply `board`
///   submit {entry}              a finished run (score, dist, rings, fish, trace)
///   achievement {id, percent}   unlock an achievement
///   showLeaderboard             open the Game Center leaderboard UI
///   challenge                   open the turn-based matchmaker (async 1v1 ghost race)
///   matchResult {matchId,entry} the local player's run for an active match
final class GameBridge: NSObject, WKScriptMessageHandler {
    static let channel = "starflappy"
    weak var webView: WKWebView?

    override init() {
        super.init()
        GameCenterManager.shared.bridge = self
        AsyncMatchManager.shared.bridge = self
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Self.channel,
              let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }

        switch type {
        case "ready":
            GameCenterManager.shared.sendPlayer()
            GameCenterManager.shared.loadTop(50)
            AsyncMatchManager.shared.deliverPendingMatch()
        case "top":
            GameCenterManager.shared.loadTop(body["n"] as? Int ?? 50)
        case "submit":
            if let entry = body["entry"] as? [String: Any] {
                GameCenterManager.shared.submit(entry: entry)
            }
        case "achievement":
            if let id = body["id"] as? String {
                GameCenterManager.shared.report(achievement: id, percent: body["percent"] as? Double ?? 100)
            }
        case "showLeaderboard":
            GameCenterManager.shared.showLeaderboard()
        case "challenge":
            AsyncMatchManager.shared.openMatchmaker()
        case "matchResult":
            if let id = body["matchId"] as? String, let entry = body["entry"] as? [String: Any] {
                AsyncMatchManager.shared.submitRun(matchID: id, entry: entry)
            }
        default:
            break
        }
    }

    /// Deliver a payload to the page as `window.__sf.onNative(payload)`.
    func send(_ payload: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        let js = "window.__sf && window.__sf.onNative(\(json));"
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}
