//
//  SessionConnectivity.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/16/26.
//

import Foundation
import Observation
import WatchConnectivity

/// The single WCSessionDelegate wrapper shared by both the phone and watch targets.
///
/// WCSessionDelegate methods are documented as delivered on a background thread regardless of
/// the module's default actor isolation, so each delegate method is `nonisolated` and hops to
/// the main actor explicitly before touching any published state.
@MainActor
@Observable
final class SessionConnectivity: NSObject, WCSessionDelegate {
    static let shared = SessionConnectivity()

    /// Watch reads this to render the mirrored session.
    private(set) var latestSnapshot: ActiveSessionSnapshot?
    /// Phone sets this to learn about incoming remote commands.
    var onCommandReceived: ((SessionCommand) -> Void)?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Phone -> watch. Call whenever the active snapshot changes.
    func send(_ snapshot: ActiveSessionSnapshot?) {
        guard let data = try? JSONEncoder().encode(ActiveSessionState(snapshot: snapshot)) else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        // Deliberately NOT gated on isPaired/isWatchAppInstalled: those flags have been
        // observed to lag or misreport after a fresh activation (especially in Simulator),
        // and gating on them silently blocked delivery even once a real counterpart was
        // installed and running. Attempting the send and letting it fail harmlessly (logged,
        // swallowed by try?) is what actually lets this recover once the pairing catches up.
        try? session.updateApplicationContext(["activeSession": data])
        if session.isReachable {
            session.sendMessage(["activeSession": data], replyHandler: nil, errorHandler: nil)
        }
    }

    /// Watch -> phone.
    func sendCommand(_ command: SessionCommand) {
        guard let data = try? JSONEncoder().encode(command) else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return }
        session.sendMessage(["command": data], replyHandler: nil, errorHandler: nil)
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncoming(message)
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleIncoming(applicationContext)
    }

    nonisolated private func handleIncoming(_ payload: [String: Any]) {
        if let data = payload["activeSession"] as? Data,
           let state = try? JSONDecoder().decode(ActiveSessionState.self, from: data) {
            Task { @MainActor in self.latestSnapshot = state.snapshot }
        }
        if let data = payload["command"] as? Data,
           let command = try? JSONDecoder().decode(SessionCommand.self, from: data) {
            Task { @MainActor in self.onCommandReceived?(command) }
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
