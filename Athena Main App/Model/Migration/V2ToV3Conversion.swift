//
//  V2ToV3Conversion.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/24/26.
//

import Foundation

/// Pure field-mapping helpers for the V2 → V3 legacy import. Every function here is a
/// plain value transform — no `ModelContext`, no `@Model` types, no fetches — so this
/// file is fully unit-testable without a `ModelContainer`.
///
/// All V2 and V3 types are referenced with their full `SchemaV2.`/`SchemaV3.` prefix
/// rather than the ambient global typealiases (`Routine`, `Exercise`, …), which today
/// point at `SchemaV2` and will move to point at `SchemaV3` once the view layer is
/// migrated. Using the bare names here would silently retarget half of this file at
/// that point instead of failing to compile.
///
/// Two conventions apply across every `*Alt` field this file emits:
/// - **Sparse alt.** A `*Alt` field is only written when its value actually differs
///   from the corresponding main value. V2 is inconsistent here — generic payloads are
///   already sparse, max hang payloads are written densely (alt present even when
///   equal), campus is alt-iff-mirrored — so this file normalizes all of them to
///   sparse. Readers must coalesce `*Alt ?? main`, and must consult the parent
///   `Exercise.category`'s `SideType` (not alt-field presence) to know whether a right
///   side exists at all: an absent alt can mean either "no right side" or "right side
///   equals left", and only `SideType` disambiguates.
/// - **Empty fields are omitted**, not written with a placeholder. A `DataSet` only
///   contains the keys that had a value in V2.
nonisolated enum V2ToV3Conversion {

    // MARK: - Exercise category

    /// Derives a V3 category directly from a routine payload's own fields. Used as the
    /// fallback when a payload has no library link (`exerciseID == nil` — pre-V2 data
    /// that never got backfilled) and there is no `ExerciseExportDTO` to consult.
    ///
    /// Unlike `ExerciseIdentity.init?`, this never fails: an empty free-text label is
    /// still a valid (if degenerate) category and dedupes correctly by equality.
    static func category(for payload: SchemaV2.Routine.Exercise) -> SchemaV3.Exercise.Category {
        switch payload {
        case .generic(let d):
            return .generic(name: d.name, dataTypes: dataTypes(for: d.dataType), sideType: sideType(for: d.sideType))
        case .repeater(let d):
            return .repeater(tag: d.tag, timeOn: d.timeOn, timeOff: d.timeOff)
        case .maxHang(let d):
            return .maxHang(tag: d.tag, sideType: sideType(isSingleArm: d.isSingleArm))
        case .campus(let d):
            return .campus(name: campusName(for: d.type), mirrorSets: d.type.canMirror)
        }
    }

    /// Same as above, derived from a session snapshot's `expected` prescription.
    static func category(for payload: SchemaV2.Session.Exercise) -> SchemaV3.Exercise.Category {
        switch payload {
        case .generic(let d): category(for: .generic(d.expected))
        case .repeater(let d): category(for: .repeater(d.expected))
        case .maxHang(let d): category(for: .maxHang(d.expected))
        case .campus(let d): category(for: .campus(d.expected))
        }
    }

    /// Derives a V3 category from an already-exported library row. Preferred over the
    /// payload-derived overloads above whenever a linked `ExerciseExportDTO` is
    /// available, since it preserves the user's own rename/merge groupings exactly.
    /// `nil` only for `Kind.unknown` — a defensive case for a future subclass that
    /// predates this importer.
    static func category(for kind: ExerciseExportDTO.Kind, name: String) -> SchemaV3.Exercise.Category? {
        switch kind {
        case .generic(let dataType, let sideTypeValue):
            return .generic(name: name, dataTypes: dataTypes(for: dataType), sideType: sideType(for: sideTypeValue))
        case .repeater(let timeOn, let timeOff):
            return .repeater(tag: name, timeOn: timeOn, timeOff: timeOff)
        case .maxHang(let isSingleArm):
            return .maxHang(tag: name, sideType: sideType(isSingleArm: isSingleArm))
        case .campus(let campusType):
            return .campus(name: campusName(for: campusType), mirrorSets: campusType.canMirror)
        case .unknown:
            return nil
        }
    }

    static func dataTypes(for dataType: SchemaV2.Routine.GenericSets.DataType) -> [SchemaV3.Exercise.DataType] {
        switch dataType {
        case .rep: [.reps]
        case .repWeight: [.reps, .weight]
        case .time: [.time]
        case .timeWeight: [.time, .weight]
        }
    }

    static func sideType(for sideType: SchemaV2.Routine.SideType?) -> SchemaV3.Exercise.SideType {
        switch sideType {
        case nil: .none
        case .dependent: .dependent
        case .independent: .independent
        }
    }

    /// `isSingleArm == false` ("both arms use a single pair of time/weight",
    /// `RoutineV2.swift`) maps to `.none`. `isSingleArm == true` maps to `.independent`
    /// rather than `.dependent`, because V2 explicitly permits differing per-arm values
    /// for single-arm sets (`ExerciseEntryDraft.swift` writes all four left/right
    /// fields) — collapsing to `.dependent` would risk silently discarding real
    /// side-to-side variance.
    static func sideType(isSingleArm: Bool) -> SchemaV3.Exercise.SideType {
        isSingleArm ? .independent : .none
    }

    /// Frozen copy of `CampusExercise.text` (`View/CampusBoardView.swift:26-37`), which
    /// is what V2 persisted as `CampusLibraryExercise.name`. Deliberately not a call
    /// into that view extension: a future UI rename must not retroactively rewrite
    /// already-imported library names.
    static func campusName(for type: SchemaV2.Routine.CampusSets.Exercise) -> String {
        switch type {
        case .basicLadder: "Basic Ladder"
        case .maxLadder: "Max Ladder"
        case .maxFirst: "Max First"
        case .bumps: "Bumps"
        case .touches: "Touches"
        case .doubles: "Doubles"
        case .downUps: "Down-Ups"
        }
    }

    /// Unwraps a session snapshot's `expected` prescription back into the routine
    /// payload shape, so the same `expectedData(for:)` overload can be reused for both
    /// a routine template and a session's own per-exercise prescription snapshot.
    static func routinePayload(from payload: SchemaV2.Session.Exercise) -> SchemaV2.Routine.Exercise {
        switch payload {
        case .generic(let d): .generic(d.expected)
        case .repeater(let d): .repeater(d.expected)
        case .maxHang(let d): .maxHang(d.expected)
        case .campus(let d): .campus(d.expected)
        }
    }

    /// The exercise-level notes carried by a session snapshot's wrapper — distinct
    /// from the per-set notes already folded into each `DataSet` by `actualData(for:)`.
    static func notes(for payload: SchemaV2.Session.Exercise) -> String {
        switch payload {
        case .generic(let d): d.notes
        case .repeater(let d): d.notes
        case .maxHang(let d): d.notes
        case .campus(let d): d.notes
        }
    }

    // MARK: - Super sets

    static func superSet(_ set: SchemaV2.Routine.ExerciseSet) -> SchemaV3.Routine.SuperSet {
        .init(name: set.name, restTime: set.restTime, order: order(set.order))
    }

    static func superSet(_ set: SchemaV2.Session.ExerciseSet) -> SchemaV3.Routine.SuperSet {
        .init(name: set.name, restTime: set.restTime, order: order(set.order))
    }

    private static func order(_ order: SchemaV2.Routine.Order) -> SchemaV3.Routine.SuperSet.Order {
        switch order {
        case .bfs: .bfs
        case .dfs: .dfs
        }
    }

    // MARK: - Expected data (routine templates)

    /// One `DataSet` per prescribed set, in order — this becomes
    /// `RoutineData.expectedData` / `ExerciseData.expectedData`.
    static func expectedData(for payload: SchemaV2.Routine.Exercise) -> [SchemaV3.ExerciseData.DataSet] {
        switch payload {
        case .generic(let d):
            // A range/discrete rep-or-time prescription. V2 never prescribes an
            // expected weight for generic exercises — only `actual` weight is tracked.
            let field: SchemaV3.ExerciseData.Field = (d.dataType == .rep || d.dataType == .repWeight) ? .reps : .time
            return d.sets.map { set in
                [field: rangeOrDiscrete(min: set.min, max: set.max)]
            }
        case .repeater(let d):
            return d.sets.map { set in
                [.reps: .discrete(set.numReps), .weight: .number(set.weight)]
            }
        case .maxHang(let d):
            return d.sets.map { set in
                var dataSet: SchemaV3.ExerciseData.DataSet = [
                    .time: .discrete(set.target),
                    .weight: .number(set.weight),
                ]
                if let targetAlt = set.targetAlt, targetAlt != set.target {
                    dataSet[.timeAlt] = .discrete(targetAlt)
                }
                if let weightAlt = set.weightAlt, weightAlt != set.weight {
                    dataSet[.weightAlt] = .number(weightAlt)
                }
                return dataSet
            }
        case .campus(let d):
            return d.sets.map { plannedSet in
                let mainSet = campusSet(from: plannedSet)
                var dataSet: SchemaV3.ExerciseData.DataSet = [.campus: .campus(mainSet)]
                if plannedSet.doMirror && d.type.canMirror {
                    let mirrored = SchemaV3.ExerciseData.CampusSet(board: mainSet.board, moves: flipped(mainSet.moves))
                    dataSet[.campusAlt] = .campus(mirrored)
                }
                return dataSet
            }
        }
    }

    // MARK: - Actual data (recorded sessions)

    /// One `DataSet` per recorded set, in order — this becomes
    /// `ExerciseData.actualData`. Deliberately preserves whatever count V2 recorded,
    /// even when it differs from the expected count (`SessionRunner.apply` appends
    /// past the end of `expected.sets` when a set is skipped, so the two arrays can
    /// legitimately diverge in length — that drift is real data, not corruption, and
    /// padding it would invent values that were never recorded).
    static func actualData(for payload: SchemaV2.Session.Exercise) -> [SchemaV3.ExerciseData.DataSet] {
        switch payload {
        case .generic(let d):
            return d.actual.map { set in
                var dataSet: SchemaV3.ExerciseData.DataSet = [:]
                if let numReps = set.numReps { dataSet[.reps] = .discrete(numReps) }
                if let numRepsAlt = set.numRepsAlt, numRepsAlt != set.numReps {
                    dataSet[.repsAlt] = .discrete(numRepsAlt)
                }
                if let time = set.time { dataSet[.time] = .discrete(time) }
                if let timeAlt = set.timeAlt, timeAlt != set.time {
                    dataSet[.timeAlt] = .discrete(timeAlt)
                }
                if let weight = set.weight { dataSet[.weight] = .number(weight) }
                if let weightAlt = set.weightAlt, weightAlt != set.weight {
                    dataSet[.weightAlt] = .number(weightAlt)
                }
                if !set.notes.isEmpty { dataSet[.notes] = .text(set.notes) }
                return dataSet
            }
        case .repeater(let d):
            return d.actual.map { set in
                var dataSet: SchemaV3.ExerciseData.DataSet = [
                    .reps: .discrete(set.numReps),
                    .weight: .number(set.weight),
                ]
                if !set.notes.isEmpty { dataSet[.notes] = .text(set.notes) }
                return dataSet
            }
        case .maxHang(let d):
            return d.actual.map { set in
                var dataSet: SchemaV3.ExerciseData.DataSet = [:]
                if let time = set.time { dataSet[.time] = .discrete(time) }
                if let timeAlt = set.timeAlt, timeAlt != set.time {
                    dataSet[.timeAlt] = .discrete(timeAlt)
                }
                if let weight = set.weight { dataSet[.weight] = .number(weight) }
                if let weightAlt = set.weightAlt, weightAlt != set.weight {
                    dataSet[.weightAlt] = .number(weightAlt)
                }
                if !set.notes.isEmpty { dataSet[.notes] = .text(set.notes) }
                return dataSet
            }
        case .campus(let d):
            return d.actual.map { pair in
                var dataSet: SchemaV3.ExerciseData.DataSet = [.campus: .campus(campusSet(pair.main))]
                if let alt = pair.alt {
                    dataSet[.campusAlt] = .campus(campusSet(alt))
                }
                // `main.notes` is the single source of truth for a mirrored pair's
                // notes (`ExerciseEntryDraft.swift`); `alt.notes` is always a
                // duplicate of it and is dropped.
                if !pair.main.notes.isEmpty { dataSet[.notes] = .text(pair.main.notes) }
                return dataSet
            }
        }
    }

    // MARK: - Campus value conversion

    /// Converts a recorded V2 `CampusSet` to its V3 counterpart, dropping `notes`
    /// (hoisted separately to `Field.notes` by the callers above — V3's `CampusSet`
    /// has no `notes` field of its own).
    static func campusSet(_ set: SchemaV2.CampusSet) -> SchemaV3.ExerciseData.CampusSet {
        .init(board: board(set.board), moves: set.moves.map(move), tempo: set.tempo.map(tempo))
    }

    /// Converts a routine template's planned set to a V3 `CampusSet`. `.baseline`/
    /// `.progressive` moves have no V3 representation (`Value.campus` requires
    /// concrete moves) and degrade to an empty move list with the correct board —
    /// exactly what `SessionRunner.swift` already does at runtime for the same cases.
    /// Only reachable from routine templates; recorded session data is always
    /// `.defined`. Planned sets carry no tempo (only recorded sets do).
    static func campusSet(from plannedSet: SchemaV2.Routine.CampusSets.PlannedSet) -> SchemaV3.ExerciseData.CampusSet {
        let moves: [SchemaV3.ExerciseData.CampusSet.Move]
        switch plannedSet.moves {
        case .defined(let definedMoves):
            moves = definedMoves.map(move)
        case .baseline, .progressive:
            moves = []
        }
        return .init(board: board(plannedSet.board), moves: moves)
    }

    static func flipped(_ moves: [SchemaV3.ExerciseData.CampusSet.Move]) -> [SchemaV3.ExerciseData.CampusSet.Move] {
        moves.map { .init(rung: $0.rung, side: $0.side.flipped) }
    }

    private static func board(_ board: SchemaV2.CampusSet.Board) -> SchemaV3.ExerciseData.CampusSet.Board {
        .init(name: board.name, startRung: rung(board.startRung), endRung: rung(board.endRung), hasHalf: board.hasHalf)
    }

    private static func rung(_ rung: SchemaV2.CampusSet.Rung) -> SchemaV3.ExerciseData.CampusSet.Rung {
        .init(num: rung.num, isHalf: rung.isHalf)
    }

    private static func move(_ move: SchemaV2.CampusSet.Move) -> SchemaV3.ExerciseData.CampusSet.Move {
        .init(rung: rung(move.rung), side: side(move.side))
    }

    private static func side(_ side: SchemaV2.CampusSet.Side) -> SchemaV3.ExerciseData.CampusSet.Side {
        switch side {
        case .both: .both
        case .left: .left
        case .right: .right
        }
    }

    private static func tempo(_ tempo: SchemaV2.CampusSet.Tempo) -> SchemaV3.ExerciseData.CampusSet.Tempo {
        switch tempo {
        case .bpm(let value): .bpm(value: value)
        }
    }

    // MARK: - Range collapsing

    /// `min == max` collapses to `.discrete` — `Routine.GenericSet.init(num:)` sets
    /// both equal and is the dominant shape, and the two denote the identical
    /// prescription, so nothing is lost. `.range` is reserved for genuine ranges.
    static func rangeOrDiscrete(min: Int, max: Int) -> SchemaV3.ExerciseData.Value {
        min == max ? .discrete(min) : .range(min: min, max: max)
    }
}
