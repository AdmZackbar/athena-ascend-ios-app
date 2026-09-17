//
//  SessionLiveActivity.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/17/26.
//

import ActivityKit
import Foundation

/// Mirrors RoutineSessionView's activeSessionSnapshot into a Live Activity, exactly like
/// SessionConnectivity.send(_:) mirrors it to the watch — one idempotent entry point taking the
/// same optional snapshot, called from the same three hooks.
@MainActor
final class SessionLiveActivity {
    static let shared = SessionLiveActivity()

    private var activity: Activity<WorkoutActivityAttributes>?

    private init() {
        // A crash or force-quit can leave an activity running past the session it described;
        // reclaim and end any strays left over from a previous run.
        for stray in Activity<WorkoutActivityAttributes>.activities {
            Task { await stray.end(nil, dismissalPolicy: .immediate) }
        }
    }

    func sync(_ snapshot: ActiveSessionSnapshot?) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            end()
            return
        }
        guard let snapshot else {
            end()
            return
        }
        if let activity, activity.attributes.sessionStartTime != snapshot.sessionStartTime {
            end()
        }
        if let activity {
            Task { await activity.update(ActivityContent(state: snapshot, staleDate: nil)) }
        } else {
            let attributes = WorkoutActivityAttributes(
                sessionStartTime: snapshot.sessionStartTime,
                routineName: snapshot.routineName
            )
            activity = try? Activity.request(
                attributes: attributes,
                content: ActivityContent(state: snapshot, staleDate: nil),
                pushType: nil
            )
        }
    }

    private func end() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
