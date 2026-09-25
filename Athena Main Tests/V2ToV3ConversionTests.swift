//
//  V2ToV3ConversionTests.swift
//  AthenaAscendTests
//
//  Created by Zach Wassynger on 9/24/26.
//

import Foundation
import Testing
@testable import Athena

struct V2ToV3ConversionTests {

    // MARK: - Category / identity primitives

    @Test func dataTypesMapping() {
        #expect(V2ToV3Conversion.dataTypes(for: .rep) == [.reps])
        #expect(V2ToV3Conversion.dataTypes(for: .repWeight) == [.reps, .weight])
        #expect(V2ToV3Conversion.dataTypes(for: .time) == [.time])
        #expect(V2ToV3Conversion.dataTypes(for: .timeWeight) == [.time, .weight])
    }

    @Test func sideTypeFromOptional() {
        #expect(V2ToV3Conversion.sideType(for: nil) == .none)
        #expect(V2ToV3Conversion.sideType(for: .dependent) == .dependent)
        #expect(V2ToV3Conversion.sideType(for: .independent) == .independent)
    }

    @Test func sideTypeFromIsSingleArm() {
        // isSingleArm == false: both arms share one value ([L+R]) -> .none.
        #expect(V2ToV3Conversion.sideType(isSingleArm: false) == .none)
        // isSingleArm == true: V2 permits differing per-arm values, so this maps to
        // .independent rather than .dependent to avoid silently discarding variance.
        #expect(V2ToV3Conversion.sideType(isSingleArm: true) == .independent)
    }

    @Test func campusNameMatchesViewLayerText() {
        for type in SchemaV2.Routine.CampusSets.Exercise.allCases {
            #expect(V2ToV3Conversion.campusName(for: type) == type.text)
        }
    }

    @Test func categoryFromRoutinePayload() {
        let generic = SchemaV2.Routine.Exercise.generic(.init(name: "Bench", dataType: .repWeight, sideType: .independent))
        #expect(V2ToV3Conversion.category(for: generic) == .generic(name: "Bench", dataTypes: [.reps, .weight], sideType: .independent))

        let repeater = SchemaV2.Routine.Exercise.repeater(.init(tag: "HC", timeOn: 7, timeOff: 3))
        #expect(V2ToV3Conversion.category(for: repeater) == .repeater(tag: "HC", timeOn: 7, timeOff: 3))

        let maxHang = SchemaV2.Routine.Exercise.maxHang(.init(tag: "BM", isSingleArm: true))
        #expect(V2ToV3Conversion.category(for: maxHang) == .maxHang(tag: "BM", sideType: .independent))

        let campus = SchemaV2.Routine.Exercise.campus(.init(type: .maxLadder))
        #expect(V2ToV3Conversion.category(for: campus) == .campus(name: "Max Ladder", mirrorSets: true))

        let doubles = SchemaV2.Routine.Exercise.campus(.init(type: .doubles))
        #expect(V2ToV3Conversion.category(for: doubles) == .campus(name: "Doubles", mirrorSets: false))
    }

    @Test func categoryFromSessionPayloadDelegatesToExpected() {
        let payload = SchemaV2.Session.Exercise.generic(.init(expected: .init(name: "Bench", dataType: .rep, sideType: nil)))
        #expect(V2ToV3Conversion.category(for: payload) == .generic(name: "Bench", dataTypes: [.reps], sideType: .none))
    }

    @Test func categoryFromExportKind() {
        #expect(V2ToV3Conversion.category(for: .generic(dataType: .timeWeight, sideType: .dependent), name: "Plank")
                == .generic(name: "Plank", dataTypes: [.time, .weight], sideType: .dependent))
        #expect(V2ToV3Conversion.category(for: .repeater(timeOn: 7, timeOff: 3), name: "HC")
                == .repeater(tag: "HC", timeOn: 7, timeOff: 3))
        #expect(V2ToV3Conversion.category(for: .maxHang(isSingleArm: false), name: "BM")
                == .maxHang(tag: "BM", sideType: .none))
        #expect(V2ToV3Conversion.category(for: .campus(campusType: .bumps), name: "ignored")
                == .campus(name: "Bumps", mirrorSets: true))
        #expect(V2ToV3Conversion.category(for: .unknown, name: "X") == nil)
    }

    // MARK: - Super sets

    @Test func superSetFromRoutineExerciseSet() {
        let set = SchemaV2.Routine.ExerciseSet(name: "Set A", restTime: 60, order: .dfs)
        let superSet = V2ToV3Conversion.superSet(set)
        #expect(superSet.name == "Set A")
        #expect(superSet.restTime == 60)
        #expect(superSet.order == .dfs)
    }

    @Test func superSetFromSessionExerciseSet() {
        let base = SchemaV2.Routine.ExerciseSet(name: "Set B", restTime: 30, order: .bfs)
        let set = SchemaV2.Session.ExerciseSet(base: base)
        let superSet = V2ToV3Conversion.superSet(set)
        #expect(superSet.name == "Set B")
        #expect(superSet.restTime == 30)
        #expect(superSet.order == .bfs)
    }

    // MARK: - Range collapsing

    @Test func rangeCollapsesToDiscreteWhenEqual() {
        #expect(V2ToV3Conversion.rangeOrDiscrete(min: 5, max: 5) == .discrete(5))
        #expect(V2ToV3Conversion.rangeOrDiscrete(min: 8, max: 12) == .range(min: 8, max: 12))
    }

    // MARK: - Expected data: generic

    @Test func expectedDataGenericUsesRepsFieldForRepBasedTypes() {
        let payload = SchemaV2.Routine.Exercise.generic(.init(dataType: .rep, sets: [.init(min: 8, max: 12), .init(num: 5)]))
        let data = V2ToV3Conversion.expectedData(for: payload)
        #expect(data == [[.reps: .range(min: 8, max: 12)], [.reps: .discrete(5)]])
    }

    @Test func expectedDataGenericUsesTimeFieldForTimeBasedTypes() {
        let payload = SchemaV2.Routine.Exercise.generic(.init(dataType: .timeWeight, sets: [.init(num: 30)]))
        let data = V2ToV3Conversion.expectedData(for: payload)
        #expect(data == [[.time: .discrete(30)]])
        // No expected weight field for generic — V2 never prescribes one.
        #expect(data.allSatisfy { !$0.keys.contains(.weight) })
    }

    // MARK: - Expected data: repeater

    @Test func expectedDataRepeaterAlwaysCarriesRepsAndWeight() {
        let payload = SchemaV2.Routine.Exercise.repeater(.init(sets: [.init(numReps: 6, weight: 10)]))
        let data = V2ToV3Conversion.expectedData(for: payload)
        #expect(data == [[.reps: .discrete(6), .weight: .number(10)]])
    }

    // MARK: - Expected data: max hang

    @Test func expectedDataMaxHangOmitsAltWhenEqual() {
        let payload = SchemaV2.Routine.Exercise.maxHang(.init(sets: [.init(target: 10, targetAlt: 10, weight: 0, weightAlt: 0)]))
        let data = V2ToV3Conversion.expectedData(for: payload)
        #expect(data == [[.time: .discrete(10), .weight: .number(0)]])
    }

    @Test func expectedDataMaxHangIncludesAltWhenDifferent() {
        let payload = SchemaV2.Routine.Exercise.maxHang(.init(sets: [.init(target: 10, targetAlt: 8, weight: 0, weightAlt: -5)]))
        let data = V2ToV3Conversion.expectedData(for: payload)
        #expect(data == [[.time: .discrete(10), .timeAlt: .discrete(8), .weight: .number(0), .weightAlt: .number(-5)]])
    }

    // MARK: - Expected data: campus

    @Test func expectedDataCampusDefinedMovesRoundTrip() {
        let plannedSet = SchemaV2.Routine.CampusSets.PlannedSet(
            board: .largeEdges,
            moves: .defined([.init(rung: .full(1), side: .both), .init(rung: .full(5), side: .right)]),
            doMirror: false
        )
        let payload = SchemaV2.Routine.Exercise.campus(.init(type: .doubles, sets: [plannedSet]))
        let data = V2ToV3Conversion.expectedData(for: payload)
        #expect(data.count == 1)
        guard case .campus(let campusSet) = data[0][.campus] else {
            Issue.record("Expected a .campus value")
            return
        }
        #expect(campusSet.moves.count == 2)
        #expect(campusSet.moves[0].side == .both)
        #expect(campusSet.moves[1].side == .right)
        // .doubles cannot mirror, so no alt is emitted even though doMirror is false anyway.
        #expect(data[0][.campusAlt] == nil)
    }

    @Test func expectedDataCampusMirroringEmitsFlippedAlt() {
        let plannedSet = SchemaV2.Routine.CampusSets.PlannedSet(
            board: .largeEdges,
            moves: .defined([.init(rung: .full(5), side: .right)]),
            doMirror: true
        )
        // .maxLadder can mirror.
        let payload = SchemaV2.Routine.Exercise.campus(.init(type: .maxLadder, sets: [plannedSet]))
        let data = V2ToV3Conversion.expectedData(for: payload)
        guard case .campus(let alt) = data[0][.campusAlt] else {
            Issue.record("Expected a .campusAlt value when doMirror && canMirror")
            return
        }
        #expect(alt.moves == [.init(rung: .full(5), side: .left)])
    }

    @Test func expectedDataCampusDoMirrorIgnoredWhenTypeCannotMirror() {
        let plannedSet = SchemaV2.Routine.CampusSets.PlannedSet(
            board: .largeEdges,
            moves: .defined([.init(rung: .full(3), side: .both)]),
            doMirror: true
        )
        // .doubles cannot mirror even if doMirror is true.
        let payload = SchemaV2.Routine.Exercise.campus(.init(type: .doubles, sets: [plannedSet]))
        let data = V2ToV3Conversion.expectedData(for: payload)
        #expect(data[0][.campusAlt] == nil)
    }

    @Test func expectedDataCampusBaselineAndProgressiveDegradeToEmptyMoves() {
        let baseline = SchemaV2.Routine.CampusSets.PlannedSet(board: .largeEdges, moves: .baseline([0, 2, 4]), doMirror: false)
        let progressive = SchemaV2.Routine.CampusSets.PlannedSet(board: .smallEdges, moves: .progressive, doMirror: false)
        let payload = SchemaV2.Routine.Exercise.campus(.init(type: .maxLadder, sets: [baseline, progressive]))
        let data = V2ToV3Conversion.expectedData(for: payload)

        guard case .campus(let baselineSet) = data[0][.campus] else {
            Issue.record("Expected a .campus value")
            return
        }
        #expect(baselineSet.moves.isEmpty)
        #expect(baselineSet.board.name == "Large Edges")

        guard case .campus(let progressiveSet) = data[1][.campus] else {
            Issue.record("Expected a .campus value")
            return
        }
        #expect(progressiveSet.moves.isEmpty)
        #expect(progressiveSet.board.name == "Small Edges")
    }

    // MARK: - Actual data: generic

    @Test func actualDataGenericOmitsAbsentAndEqualAltFields() {
        let payload = SchemaV2.Session.Exercise.generic(.init(
            expected: .init(),
            actual: [.init(numReps: 8, numRepsAlt: 8, weight: 100, weightAlt: 90, notes: "felt easy")]
        ))
        let data = V2ToV3Conversion.actualData(for: payload)
        // numRepsAlt equals numReps, so it's omitted; weightAlt differs, so it's kept.
        #expect(data == [[.reps: .discrete(8), .weight: .number(100), .weightAlt: .number(90), .notes: .text("felt easy")]])
    }

    @Test func actualDataGenericOmitsEmptyNotes() {
        let payload = SchemaV2.Session.Exercise.generic(.init(expected: .init(), actual: [.init(numReps: 8)]))
        let data = V2ToV3Conversion.actualData(for: payload)
        #expect(data == [[.reps: .discrete(8)]])
    }

    // MARK: - Actual data: repeater

    @Test func actualDataRepeaterAlwaysCarriesRepsAndWeight() {
        let payload = SchemaV2.Session.Exercise.repeater(.init(expected: .init(), actual: [.init(numReps: 6, weight: 10, notes: "")]))
        let data = V2ToV3Conversion.actualData(for: payload)
        #expect(data == [[.reps: .discrete(6), .weight: .number(10)]])
    }

    // MARK: - Actual data: max hang

    @Test func actualDataMaxHangSparseAlt() {
        let payload = SchemaV2.Session.Exercise.maxHang(.init(
            expected: .init(),
            actual: [.init(time: 10, timeAlt: 10, weight: 0, weightAlt: -5, notes: "")]
        ))
        let data = V2ToV3Conversion.actualData(for: payload)
        #expect(data == [[.time: .discrete(10), .weight: .number(0), .weightAlt: .number(-5)]])
    }

    // MARK: - Actual data: campus

    @Test func actualDataCampusMirroredPairHoistsNotesFromMainOnly() {
        let main = SchemaV2.CampusSet(board: .largeEdges, moves: [.init(rung: .full(1), side: .left)], notes: "good")
        let alt = SchemaV2.CampusSet(board: .largeEdges, moves: [.init(rung: .full(1), side: .right)], notes: "good")
        let payload = SchemaV2.Session.Exercise.campus(.init(expected: .init(), actual: [.init(main: main, alt: alt)]))
        let data = V2ToV3Conversion.actualData(for: payload)

        #expect(data.count == 1)
        #expect(data[0][.notes] == .text("good"))
        guard case .campus = data[0][.campus] else {
            Issue.record("Expected a .campus value")
            return
        }
        guard case .campus = data[0][.campusAlt] else {
            Issue.record("Expected a .campusAlt value since alt was recorded")
            return
        }
    }

    @Test func actualDataCampusUnmirroredPairHasNoAlt() {
        let main = SchemaV2.CampusSet(board: .largeEdges, moves: [.init(rung: .full(1), side: .both)])
        let payload = SchemaV2.Session.Exercise.campus(.init(expected: .init(), actual: [.init(main: main, alt: nil)]))
        let data = V2ToV3Conversion.actualData(for: payload)
        #expect(data[0][.campusAlt] == nil)
    }

    // MARK: - No .distance ever emitted

    @Test func distanceFieldsAreNeverEmittedByAnyConversion() {
        let genericExpected = V2ToV3Conversion.expectedData(for: .generic(.init(sets: [.init(min: 1, max: 5)])))
        let genericActual = V2ToV3Conversion.actualData(for: .generic(.init(expected: .init(), actual: [.init(numReps: 5, weight: 10)])))
        let repeaterExpected = V2ToV3Conversion.expectedData(for: .repeater(.init(sets: [.init()])))
        let maxHangExpected = V2ToV3Conversion.expectedData(for: .maxHang(.init(sets: [.init()])))
        for dataSet in genericExpected + genericActual + repeaterExpected + maxHangExpected {
            #expect(!dataSet.keys.contains(.distance))
            #expect(!dataSet.keys.contains(.distanceAlt))
        }
    }

    // MARK: - Campus value conversion helpers

    @Test func campusSetConversionDropsNotesAndPreservesStructure() {
        let v2Set = SchemaV2.CampusSet(
            board: .init(name: "Custom", startRung: .full(2), endRung: .half(9), hasHalf: true),
            moves: [.init(rung: .full(1), side: .both), .init(rung: .half(3), side: .left)],
            tempo: .bpm(value: 120),
            notes: "should be dropped"
        )
        let v3Set = V2ToV3Conversion.campusSet(v2Set)
        #expect(v3Set.board.name == "Custom")
        #expect(v3Set.board.startRung == .init(num: 2))
        #expect(v3Set.board.endRung == .init(num: 9, isHalf: true))
        #expect(v3Set.moves.count == 2)
        #expect(v3Set.moves[1].rung == .init(num: 3, isHalf: true))
        #expect(v3Set.tempo == .bpm(value: 120))
    }

    @Test func flippedReversesSideAndPreservesRung() {
        let moves: [SchemaV3.ExerciseData.CampusSet.Move] = [
            .init(rung: .full(1), side: .both),
            .init(rung: .full(5), side: .left),
            .init(rung: .full(7), side: .right),
        ]
        let flipped = V2ToV3Conversion.flipped(moves)
        #expect(flipped == [
            .init(rung: .full(1), side: .both),
            .init(rung: .full(5), side: .right),
            .init(rung: .full(7), side: .left),
        ])
    }

    // MARK: - Session -> routine payload unwrapping

    @Test func routinePayloadUnwrapsExpectedFromEverySessionKind() {
        let generic = SchemaV2.Session.Exercise.generic(.init(expected: .init(name: "Bench")))
        #expect(V2ToV3Conversion.routinePayload(from: generic) == .generic(.init(name: "Bench")))

        let repeater = SchemaV2.Session.Exercise.repeater(.init(expected: .init(tag: "HC")))
        #expect(V2ToV3Conversion.routinePayload(from: repeater) == .repeater(.init(tag: "HC")))
    }

    @Test func notesExtractsWrapperLevelNotesFromEverySessionKind() {
        let generic = SchemaV2.Session.Exercise.generic(.init(expected: .init(), notes: "wrapper notes"))
        #expect(V2ToV3Conversion.notes(for: generic) == "wrapper notes")

        let repeater = SchemaV2.Session.Exercise.repeater(.init(expected: .init(), notes: "other notes"))
        #expect(V2ToV3Conversion.notes(for: repeater) == "other notes")
    }
}
