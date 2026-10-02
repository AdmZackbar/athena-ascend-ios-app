//
//  WorkoutMirror.swift
//  Athena
//
//  Created by Zach Wassynger on 10/1/26.
//

import Foundation
import HealthKit

/// Receives the HealthKit workout the watch mirrors over to the phone when a live,
/// single-athlete session starts one (see `WorkoutManager` on the watch side).
///
/// `HKWorkoutSessionDelegate` methods are documented as delivered on an arbitrary
/// background queue, so each is `nonisolated` and hops to the main actor before
/// touching state - the same pattern `SessionConnectivity` uses.
@MainActor
@Observable
final class WorkoutMirror: NSObject {
    static let shared = WorkoutMirror()

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    /// The session this mirrored workout belongs to, remembered from `startIfEligible`
    /// so its UUID can be sent to the watch once mirroring actually connects.
    private var pendingSessionUUID: UUID?

    /// Latest metrics mirrored from the watch, for `SessionLiveView`'s metrics strip.
    private(set) var metrics: WorkoutMetrics?

    /// The HK workout type to start on the watch, chosen from `SessionView`'s picker.
    var workoutType: WorkoutType = .strengthFunctional

    enum WorkoutType: String, CaseIterable, Identifiable {
        case strengthFunctional
        case yoga
        case core

        var id: Self { self }

        var name: String {
            switch self {
            case .strengthFunctional: "Str. Training"
            case .yoga: "Yoga"
            case .core: "Core Training"
            }
        }
        
        var icon: String {
            switch self {
            case .strengthFunctional: "figure.strengthtraining.functional"
            case .yoga: "figure.yoga"
            case .core: "figure.core.training"
            }
        }

        var activityType: HKWorkoutActivityType {
            switch self {
            case .strengthFunctional: .functionalStrengthTraining
            case .yoga: .yoga
            case .core: .coreTraining
            }
        }
    }

    private static let shareTypes: Set<HKSampleType> = [
        HKQuantityType.workoutType(),
    ]
    private static let readTypes: Set<HKObjectType> = [
        HKQuantityType(.heartRate),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.basalEnergyBurned),
        HKObjectType.activitySummaryType(),
    ]

    private override init() {
        super.init()
        // Assign this as soon as the app launches, per Apple's documented guidance,
        // so a mirrored session started while this app isn't active still arrives.
        healthStore.workoutSessionMirroringStartHandler = { mirroredSession in
            // Routed through the singleton rather than a captured `self` - the handler
            // closure is `@Sendable`, and `WorkoutMirror` (a `@MainActor` class) outlives
            // the app anyway, same as `SessionConnectivity.shared`.
            Task { @MainActor in
                WorkoutMirror.shared.attach(to: mirroredSession)
            }
        }
    }

    private func attach(to mirroredSession: HKWorkoutSession) {
        mirroredSession.delegate = self
        session = mirroredSession
        if let pendingSessionUUID {
            send(.linkSession(pendingSessionUUID))
        }
    }

    /// Starts the watch's workout (of the selected `workoutType`) for `session`, unless
    /// it has more than one athlete - the watch wearer can only stand in for one.
    func startIfEligible(for session: Session) {
        guard session.athletes.count == 1, HKHealthStore.isHealthDataAvailable() else { return }
        pendingSessionUUID = session.uuid
        Task {
            do {
                try await healthStore.requestAuthorization(toShare: Self.shareTypes, read: Self.readTypes)
                let configuration = HKWorkoutConfiguration()
                configuration.activityType = workoutType.activityType
                configuration.locationType = .indoor
                try await healthStore.startWatchApp(toHandle: configuration)
            } catch {
                print("WorkoutMirror: failed to start watch workout: \(error)")
            }
        }
    }

    /// Tells the watch to end (and save) its workout - called when the routine finishes.
    func requestEnd() {
        send(.end)
    }

    private func send(_ message: WorkoutRemoteMessage) {
        guard let session, let data = try? JSONEncoder().encode(message) else { return }
        session.sendToRemoteWorkoutSession(data: data) { success, error in
            if let error {
                print("WorkoutMirror: failed to send remote message: \(error)")
            }
        }
    }

    private func clear() {
        session = nil
        pendingSessionUUID = nil
        metrics = nil
    }
}

extension WorkoutMirror: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        guard toState == .ended else { return }
        Task { @MainActor in
            self.clear()
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("WorkoutMirror: mirrored session failed: \(error)")
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didDisconnectFromRemoteDeviceWithError error: Error?) {
        // The watch's primary session may still be running and will reconnect,
        // calling workoutSessionMirroringStartHandler again with a fresh session.
        Task { @MainActor in
            self.clear()
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didReceiveDataFromRemoteWorkoutSession data: [Data]) {
        for payload in data {
            guard let message = try? JSONDecoder().decode(WorkoutRemoteMessage.self, from: payload) else { continue }
            Task { @MainActor in
                switch message {
                case .metrics(let metrics):
                    self.metrics = metrics
                case .end, .linkSession:
                    break // the watch never sends these; it only receives them.
                }
            }
        }
    }
}
