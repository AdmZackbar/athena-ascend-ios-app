//
//  WorkoutManager.swift
//  Athena Watch App
//
//  Created by Zach Wassynger on 10/1/26.
//

import Foundation
import HealthKit
import Observation

/// Drives the HealthKit workout session that mirrors a live Athena session: a single,
/// indoor workout (type chosen on the phone in `SessionView`) that starts automatically
/// alongside `SessionLiveView` and is paused/resumed/ended only from the watch's own
/// controls - the Athena exercise timer never touches it.
///
/// `HKWorkoutSessionDelegate`/`HKLiveWorkoutBuilderDelegate` methods are documented as
/// delivered on an arbitrary background queue, so each is `nonisolated` and hops to the
/// main actor before touching state, mirroring the pattern `SessionConnectivity` uses.
@MainActor
@Observable
final class WorkoutManager: NSObject {
    static let shared = WorkoutManager()

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    /// The live session's persistent UUID, sent by the phone once mirroring connects.
    /// Attached to the saved workout as `HKMetadataKeyExternalUUID` so the two can be
    /// linked later (e.g. `HKQuery.predicateForObjects(withMetadataKey:allowedValues:)`).
    private var linkedSessionUUID: UUID?
    /// Throttles metrics sends to the phone to roughly once a second - HealthKit itself
    /// doesn't deliver samples much faster than that.
    private var lastMetricsSendDate: Date?

    /// Latest metrics, mirrored to the phone and rendered on the watch's metrics page.
    private(set) var metrics: WorkoutMetrics?
    /// The most recently finished workout, kept so the effort rating screen can look up
    /// and attach a `workoutEffortScore` to it after `finishWorkout()` returns.
    private(set) var lastWorkout: HKWorkout?

    private override init() {
        super.init()
    }

    private static let shareTypes: Set<HKSampleType> = [
        HKQuantityType.workoutType(),
        HKQuantityType(.workoutEffortScore),
    ]
    private static let readTypes: Set<HKObjectType> = [
        HKQuantityType(.heartRate),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.basalEnergyBurned),
        HKQuantityType(.estimatedWorkoutEffortScore),
        HKObjectType.activitySummaryType(),
    ]

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        do {
            try await healthStore.requestAuthorization(toShare: Self.shareTypes, read: Self.readTypes)
        } catch {
            print("WorkoutManager: authorization request failed: \(error)")
        }
    }

    /// Starts a new workout of the given activity type, unless one is already running -
    /// `startWatchApp(with:)` may call `handle(_:)` again if `SessionLiveView` reappears
    /// while a workout from the same session is still active.
    func startWorkout(activityType: HKWorkoutActivityType = .functionalStrengthTraining) async {
        guard session == nil else { return }
        lastWorkout = nil

        // Best-effort cleanup: `session == nil` here means this process has no in-memory
        // record of a running workout, but one can still exist in HealthKit if a previous
        // launch was force-quit mid-workout rather than cleanly ending it - the same
        // condition `handleActiveWorkoutRecovery()` is meant to catch after a crash.
        // HealthKit only runs one session system-wide, so leaving that one dangling would
        // silently kill it (or this one) the moment two sessions collide. Recovering and
        // reattaching to it, if one exists, avoids that rather than starting a competing
        // session blind. `try?` because there's no documented guarantee this succeeds
        // outside the crash-recovery callback - if it returns nil or throws, a fresh
        // session starts normally below.
        if let dangling = try? await healthStore.recoverActiveWorkoutSession(), dangling.state != .ended {
            attach(to: dangling)
            return
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder

            try await session.startMirroringToCompanionDevice()
            let start = Date()
            session.startActivity(with: start)
            try await builder.beginCollection(at: start)
            metrics = WorkoutMetrics(state: .running, startDate: start, elapsedTime: 0, heartRate: nil, activeEnergy: 0, totalEnergy: 0)
            sendMetricsIfDue()
        } catch {
            print("WorkoutManager: failed to start workout: \(error)")
            self.session = nil
            self.builder = nil
        }
    }

    /// Re-attaches to a workout session recovered after a crash. Called from
    /// `WKApplicationDelegate.handleActiveWorkoutRecovery()`.
    func recoverWorkout() async {
        do {
            guard let session = try await healthStore.recoverActiveWorkoutSession() else { return }
            attach(to: session)
        } catch {
            print("WorkoutManager: failed to recover workout: \(error)")
        }
    }

    /// Wires up delegates and seeds `metrics` for a session this instance didn't create
    /// itself - recovered either after a crash or found dangling from a previous launch.
    /// Note this doesn't re-establish companion mirroring; the phone's `WorkoutMirror`
    /// will reconnect on its own once this session next sends it data.
    private func attach(to session: HKWorkoutSession) {
        let builder = session.associatedWorkoutBuilder()
        session.delegate = self
        builder.delegate = self
        self.session = session
        self.builder = builder
        let state: WorkoutMetrics.State = session.state == .paused ? .paused : .running
        metrics = WorkoutMetrics(state: state, startDate: session.startDate ?? Date(), elapsedTime: 0, heartRate: nil, activeEnergy: 0, totalEnergy: 0)
    }

    func togglePause() {
        guard let session else { return }
        switch session.state {
        case .running:
            session.pause()
        case .paused:
            session.resume()
        default:
            break
        }
    }

    /// Requests the session end. The actual `endCollection`/`finishWorkout` sequence
    /// happens once the session delegate reports `.ended`, per Apple's documented
    /// pattern - calling `endCollection` immediately risks racing the session's own
    /// transition.
    func end() {
        session?.end()
    }

    /// Remembers which session this workout belongs to, so `finishWorkout` can attach
    /// it as metadata. Sent by the phone once the mirrored session reaches it.
    func linkSession(_ uuid: UUID) {
        linkedSessionUUID = uuid
    }

    /// Workouts shorter than this are discarded rather than saved - see the HIG's
    /// "Discard extremely brief workout sessions" guidance under Workouts: Best practices.
    private static let minimumWorkoutDuration: TimeInterval = 60

    private func finishWorkout(endDate: Date) async {
        guard let builder else { return }

        let duration = endDate.timeIntervalSince(session?.startDate ?? endDate)
        guard duration >= Self.minimumWorkoutDuration else {
            builder.discardWorkout()
            metrics?.state = .discarded
            sendMetricsIfDue()
            session = nil
            self.builder = nil
            linkedSessionUUID = nil
            return
        }

        do {
            try await builder.endCollection(at: endDate)
            var metadata: [String: Any] = [HKMetadataKeyIndoorWorkout: true]
            if let linkedSessionUUID {
                metadata[HKMetadataKeyExternalUUID] = linkedSessionUUID.uuidString
            }
            try await builder.addMetadata(metadata)
            lastWorkout = try await builder.finishWorkout()
        } catch {
            print("WorkoutManager: failed to finish workout: \(error)")
        }
        metrics?.state = .ended
        sendMetricsIfDue()
        session = nil
        self.builder = nil
        linkedSessionUUID = nil
    }

    /// Looks up the system's estimated effort score for `lastWorkout`, if HealthKit has
    /// produced one yet, so `EffortRatingView` can pre-fill the rating. Returns 1...10,
    /// matching the scale `saveEffort(_:)` writes in.
    func estimatedEffortScore() async -> Int? {
        guard let lastWorkout else { return nil }
        let descriptor = HKWorkoutEffortRelationshipQueryDescriptor(
            predicate: HKQuery.predicateForObjects(from: lastWorkout),
            anchor: nil,
            option: .mostRelevant
        )
        do {
            for try await result in descriptor.results(for: healthStore) {
                for relationship in result.relationships {
                    for sample in relationship.samples ?? [] {
                        if let quantity = sample as? HKQuantitySample {
                            let score = quantity.quantity.doubleValue(for: .appleEffortScore())
                            return Int(score.rounded())
                        }
                    }
                }
            }
        } catch {
            print("WorkoutManager: failed to query estimated effort score: \(error)")
        }
        return nil
    }

    /// Saves a 1...10 effort rating and links it to `lastWorkout`, the way the native
    /// Workout app's post-workout effort rating does.
    func saveEffort(_ score: Int) async {
        guard let lastWorkout else { return }
        let quantityType = HKQuantityType(.workoutEffortScore)
        let quantity = HKQuantity(unit: .appleEffortScore(), doubleValue: Double(score))
        let sample = HKQuantitySample(
            type: quantityType,
            quantity: quantity,
            start: lastWorkout.startDate,
            end: lastWorkout.endDate
        )
        do {
            try await healthStore.save(sample)
            try await healthStore.relateWorkoutEffortSample(sample, with: lastWorkout, activity: nil)
        } catch {
            print("WorkoutManager: failed to save effort score: \(error)")
        }
    }

    /// Live-ticking elapsed time, independent of the throttled `metrics.elapsedTime`
    /// snapshot sent to the phone. Meant to be read from inside a `TimelineView` on the
    /// watch's metrics page, so the clock keeps moving between HealthKit callbacks.
    func currentElapsedTime() -> TimeInterval {
        guard let builder else { return metrics?.elapsedTime ?? 0 }
        return builder.elapsedTime(at: Date())
    }

    private func updateMetrics() {
        guard let builder, var metrics else { return }
        if let hr = builder.statistics(for: HKQuantityType(.heartRate))?.mostRecentQuantity() {
            metrics.heartRate = hr.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        }
        let active = builder.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        let basal = builder.statistics(for: HKQuantityType(.basalEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        metrics.activeEnergy = active
        metrics.totalEnergy = active + basal
        metrics.elapsedTime = builder.elapsedTime(at: Date())
        self.metrics = metrics
        sendMetricsIfDue()
    }

    // ************** //
    // REMOTE MESSAGES //
    // ************** //

    private func send(_ message: WorkoutRemoteMessage) {
        guard let session, let data = try? JSONEncoder().encode(message) else { return }
        session.sendToRemoteWorkoutSession(data: data) { success, error in
            if let error {
                print("WorkoutManager: failed to send remote message: \(error)")
            }
        }
    }

    private func sendMetricsIfDue() {
        guard let metrics else { return }
        let now = Date()
        if let last = lastMetricsSendDate, now.timeIntervalSince(last) < 1, metrics.state == .running { return }
        lastMetricsSendDate = now
        send(.metrics(metrics))
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor in
            switch toState {
            case .running:
                self.metrics?.state = .running
                self.sendMetricsIfDue()
            case .paused:
                self.metrics?.state = .paused
                self.sendMetricsIfDue()
            case .ended:
                await self.finishWorkout(endDate: date)
            default:
                break
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("WorkoutManager: session failed: \(error)")
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didReceiveDataFromRemoteWorkoutSession data: [Data]) {
        for payload in data {
            guard let message = try? JSONDecoder().decode(WorkoutRemoteMessage.self, from: payload) else { continue }
            Task { @MainActor in
                switch message {
                case .end:
                    self.end()
                case .linkSession(let uuid):
                    self.linkSession(uuid)
                case .metrics:
                    break // the phone never sends metrics; it only receives them.
                }
            }
        }
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor in
            self.updateMetrics()
        }
    }
}
