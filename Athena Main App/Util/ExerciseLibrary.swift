//
//  ExerciseLibrary.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/21/26.
//

import Foundation
import SwiftData

/// The dedupe key for an exercise. Two payloads with the same identity are considered
/// the same trained exercise for library purposes, matching the existing `isBasedOn(_:)`
/// semantics in ModelUtilities.swift.
nonisolated enum ExerciseIdentity: Hashable {
    case generic(name: String, dataType: Routine.GenericSets.DataType, sideType: Routine.SideType?)
    case repeater(tag: String, timeOn: Int, timeOff: Int)
    case maxHang(tag: String, isSingleArm: Bool)
    case campus(Routine.CampusSets.Exercise)

    /// Fails only when the payload has no usable label yet (e.g. a freshly-added,
    /// not-yet-named exercise). Campus payloads always have a label (`type.text`),
    /// so that case never fails.
    init?(_ payload: Routine.Exercise) {
        switch payload {
        case .generic(let d):
            guard !d.name.isEmpty else { return nil }
            self = .generic(name: d.name, dataType: d.dataType, sideType: d.sideType)
        case .repeater(let d):
            guard !d.tag.isEmpty else { return nil }
            self = .repeater(tag: d.tag, timeOn: d.timeOn, timeOff: d.timeOff)
        case .maxHang(let d):
            guard !d.tag.isEmpty else { return nil }
            self = .maxHang(tag: d.tag, isSingleArm: d.isSingleArm)
        case .campus(let d):
            self = .campus(d.type)
        }
    }

    /// Same as above, derived from a session snapshot's `expected` prescription.
    init?(_ payload: Session.Exercise) {
        switch payload {
        case .generic(let d): self.init(.generic(d.expected))
        case .repeater(let d): self.init(.repeater(d.expected))
        case .maxHang(let d): self.init(.maxHang(d.expected))
        case .campus(let d): self.init(.campus(d.expected))
        }
    }
}

/// Groups routine/session exercise occurrences by their stable library ID, so a
/// rename no longer splits history in two. Falls back to the derived identity for
/// anything that predates the exercise library.
nonisolated enum ExerciseGroupKey: Hashable {
    case linked(UUID)
    case unlinked(ExerciseIdentity)

    init?(_ payload: Routine.Exercise) {
        if let id = payload.exerciseID {
            self = .linked(id)
            return
        }
        guard let identity = ExerciseIdentity(payload) else { return nil }
        self = .unlinked(identity)
    }

    init?(_ payload: Session.Exercise) {
        if let id = payload.exerciseID {
            self = .linked(id)
            return
        }
        guard let identity = ExerciseIdentity(payload) else { return nil }
        self = .unlinked(identity)
    }
}

/// Shared helpers for the exercise library. The single insertion point
/// (`findOrCreate`) keeps the library free of duplicates; everything else here reads
/// or rewrites the `exerciseID` links on routine/session payloads.
enum ExerciseLibrary {
    /// Finds an existing library entry matching `identity`, else creates and inserts
    /// the appropriate subclass. Does one polymorphic fetch, so prefer this only for
    /// interactive, one-off insertions (new-exercise sheets) rather than tight loops —
    /// the migration backfill builds its own local dedupe map instead.
    static func findOrCreate(for payload: Routine.Exercise, in context: ModelContext) -> Exercise? {
        guard let identity = ExerciseIdentity(payload) else { return nil }
        return findOrCreate(for: identity, in: context)
    }

    /// Same as above, for a session snapshot payload — derives identity from its
    /// `expected` prescription, which is a `Routine.*Sets` under the hood.
    static func findOrCreate(for payload: Session.Exercise, in context: ModelContext) -> Exercise? {
        switch payload {
        case .generic(let d): return findOrCreate(for: .generic(d.expected), in: context)
        case .repeater(let d): return findOrCreate(for: .repeater(d.expected), in: context)
        case .maxHang(let d): return findOrCreate(for: .maxHang(d.expected), in: context)
        case .campus(let d): return findOrCreate(for: .campus(d.expected), in: context)
        }
    }

    static func findOrCreate(for identity: ExerciseIdentity, in context: ModelContext) -> Exercise {
        let all = try? context.fetch(FetchDescriptor<Exercise>())
        if let existing = all?.first(where: { $0.identity == identity }) {
            return existing
        }
        let newExercise = makeExercise(for: identity)
        context.insert(newExercise)
        return newExercise
    }

    /// Constructs (but does not insert) the subclass instance for an identity. Exposed
    /// so the migration plan can build entries directly from its own dedupe map without
    /// paying for a fetch per payload.
    static func makeExercise(for identity: ExerciseIdentity, createdAt: Date = .now, lastUsedAt: Date? = nil) -> Exercise {
        switch identity {
        case .generic(let name, let dataType, let sideType):
            return GenericExercise(name: name, dataType: dataType, sideType: sideType, createdAt: createdAt, lastUsedAt: lastUsedAt)
        case .repeater(let tag, let timeOn, let timeOff):
            return RepeaterExercise(name: tag, timeOn: timeOn, timeOff: timeOff, createdAt: createdAt, lastUsedAt: lastUsedAt)
        case .maxHang(let tag, let isSingleArm):
            return MaxHangExercise(name: tag, isSingleArm: isSingleArm, createdAt: createdAt, lastUsedAt: lastUsedAt)
        case .campus(let campusType):
            return CampusLibraryExercise(name: campusType.text, campusType: campusType, createdAt: createdAt, lastUsedAt: lastUsedAt)
        }
    }

    /// Builds a blank-prescription routine payload prefilled from a library entry,
    /// for the "From Library…" picker in `RoutineEditView`.
    static func makeRoutineExercise(from exercise: Exercise) -> Routine.Exercise? {
        switch exercise {
        case let e as GenericExercise:
            return .generic(.init(name: e.name, dataType: e.dataType, sideType: e.sideType, exerciseID: e.uuid))
        case let e as RepeaterExercise:
            return .repeater(.init(tag: e.name, timeOn: e.timeOn, timeOff: e.timeOff, exerciseID: e.uuid))
        case let e as MaxHangExercise:
            return .maxHang(.init(tag: e.name, isSingleArm: e.isSingleArm, exerciseID: e.uuid))
        case let e as CampusLibraryExercise:
            return .campus(.init(type: e.campusType, exerciseID: e.uuid))
        default:
            return nil
        }
    }

    /// Same as `makeRoutineExercise`, wrapped as a session payload for the mid-session
    /// "Add Exercise…" picker. Reuses the existing enum mapping rather than re-deriving it.
    static func makeSessionExercise(from exercise: Exercise) -> Session.Exercise? {
        guard let routineExercise = makeRoutineExercise(from: exercise) else { return nil }
        return Session.ExerciseSet.toSessionExercise(routineExercise)
    }

    /// One polymorphic fetch to resolve a batch of IDs to their library entries, e.g.
    /// for grouping session history by exercise.
    static func resolve(ids: [UUID], in context: ModelContext) -> [UUID: Exercise] {
        guard !ids.isEmpty else { return [:] }
        let idSet = Set(ids)
        let predicate = #Predicate<Exercise> { idSet.contains($0.uuid) }
        let all = try? context.fetch(FetchDescriptor<Exercise>(predicate: predicate))
        return Dictionary(uniqueKeysWithValues: (all ?? []).map { ($0.uuid, $0) })
    }

    static func usageCount(of exercise: Exercise, routines: [Routine], sessions: [Session]) -> (routines: Int, sessions: Int) {
        let id = exercise.uuid
        let routineCount = routines.filter { routine in
            routine.sets.contains { $0.exercises.contains { $0.exerciseID == id } }
        }.count
        let sessionCount = sessions.filter { session in
            session.sets.contains { $0.exercises.contains { $0.exerciseID == id } }
        }.count
        return (routineCount, sessionCount)
    }

    /// Propagates a rename to every linked routine, and to unfinished sessions only.
    /// Finished sessions keep the label they were recorded under —
    /// `RoutineView.swift` deliberately surfaces "this session's exercise diverged from
    /// the routine", and rewriting history would erase that signal. Grouping is by ID,
    /// so history stays unified regardless of the label shown.
    ///
    /// No-op for campus payloads: a campus exercise's label is always derived from its
    /// `campusType`, which has no free-text field to rewrite.
    static func rename(_ exercise: Exercise, to newName: String, routines: [Routine], sessions: [Session]) {
        exercise.name = newName
        let id = exercise.uuid
        for routine in routines {
            for setIndex in routine.sets.indices {
                for exIndex in routine.sets[setIndex].exercises.indices {
                    if routine.sets[setIndex].exercises[exIndex].exerciseID == id {
                        routine.sets[setIndex].exercises[exIndex].rawLabel = newName
                    }
                }
            }
        }
        for session in sessions where !session.finished {
            for setIndex in session.sets.indices {
                for exIndex in session.sets[setIndex].exercises.indices {
                    if session.sets[setIndex].exercises[exIndex].exerciseID == id {
                        session.sets[setIndex].exercises[exIndex].rawLabel = newName
                    }
                }
            }
        }
    }

    /// Re-points every reference from `source` to `target` and deletes `source`. Both
    /// must be the same concrete subclass — the merge-target picker in
    /// `ExerciseLibraryView` only ever offers same-kind entries, but this guard keeps
    /// the helper honest even if called from elsewhere.
    static func merge(_ source: Exercise, into target: Exercise, routines: [Routine], sessions: [Session], context: ModelContext) {
        precondition(type(of: source) == type(of: target), "Cannot merge exercises of different kinds")
        let sourceID = source.uuid
        let targetID = target.uuid
        for routine in routines {
            for setIndex in routine.sets.indices {
                for exIndex in routine.sets[setIndex].exercises.indices {
                    if routine.sets[setIndex].exercises[exIndex].exerciseID == sourceID {
                        routine.sets[setIndex].exercises[exIndex].exerciseID = targetID
                    }
                }
            }
        }
        for session in sessions {
            for setIndex in session.sets.indices {
                for exIndex in session.sets[setIndex].exercises.indices {
                    if session.sets[setIndex].exercises[exIndex].exerciseID == sourceID {
                        session.sets[setIndex].exercises[exIndex].exerciseID = targetID
                    }
                }
            }
        }
        context.delete(source)
    }

    /// Un-links every routine/session payload pointing at `exercise`, leaving their
    /// name and config untouched — they just go back to unlinked. Call before deleting
    /// `exercise` so nothing is left holding a dangling UUID.
    static func clearLinks(to exercise: Exercise, routines: [Routine], sessions: [Session]) {
        let id = exercise.uuid
        for routine in routines {
            for setIndex in routine.sets.indices {
                for exIndex in routine.sets[setIndex].exercises.indices {
                    if routine.sets[setIndex].exercises[exIndex].exerciseID == id {
                        routine.sets[setIndex].exercises[exIndex].exerciseID = nil
                    }
                }
            }
        }
        for session in sessions {
            for setIndex in session.sets.indices {
                for exIndex in session.sets[setIndex].exercises.indices {
                    if session.sets[setIndex].exercises[exIndex].exerciseID == id {
                        session.sets[setIndex].exercises[exIndex].exerciseID = nil
                    }
                }
            }
        }
    }
}
