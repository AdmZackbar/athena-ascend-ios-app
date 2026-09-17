//
//  SessionCommandCenter.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/16/26.
//

import Observation

/// Bridge from "a command arrived from elsewhere" to "the on-screen RoutineSessionView should
/// react," analogous to how AudioManager.shared is referenced via @State elsewhere in that view.
///
/// Deliberately has no dependency on SessionConnectivity (WatchConnectivity isn't available to
/// app extensions): the app target wires SessionConnectivity's incoming commands into `submit`
/// itself (see AthenaMainApp.init), and Live Activity intents call `submit` directly. This keeps
/// the type compilable in the widget extension target, which is required so its Button(intent:)
/// closures can reference the same LiveActivityIntent types the app target links in.
@MainActor
@Observable
final class SessionCommandCenter {
    static let shared = SessionCommandCenter()

    private(set) var pendingCommand: SessionCommand?

    private init() {}

    func submit(_ command: SessionCommand) {
        pendingCommand = command
    }

    func consume() {
        pendingCommand = nil
    }
}
