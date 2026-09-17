//
//  SessionCommandCenter.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/16/26.
//

import Observation

/// Phone-only bridge from "a command arrived on a background thread" to "the on-screen
/// RoutineSessionView should react," analogous to how AudioManager.shared is referenced
/// via @State elsewhere in that view.
@MainActor
@Observable
final class SessionCommandCenter {
    static let shared = SessionCommandCenter()

    private(set) var pendingCommand: SessionCommand?

    private init() {
        SessionConnectivity.shared.onCommandReceived = { [weak self] command in
            self?.pendingCommand = command
        }
    }

    func consume() {
        pendingCommand = nil
    }
}
