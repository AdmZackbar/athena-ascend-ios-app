//
//  SessionRunnerTests.swift
//  AthenaAscendTests
//
//  Created by Zach Wassynger on 8/16/26.
//

import Foundation
import Testing
@testable import Athena

/// Covers `SessionRunner`'s traversal, phase machine, timer-duration, and repeater-rep logic.
/// These operate on plain `Session.ExerciseSet` values, so no `ModelContainer` is needed.
struct SessionRunnerTests {

    // MARK: - Fixture helpers

    private func genericExercise(sets: Int, dataType: Routine.GenericSets.DataType = .repWeight, sideType: Routine.SideType? = nil) -> Routine.Exercise {
        .generic(.init(name: "Generic", dataType: dataType, sideType: sideType, sets: (0..<sets).map { _ in .init(num: 5) }))
    }

    private func repeaterExercise(sets: Int, timeOn: Int = 7, timeOff: Int = 3) -> Routine.Exercise {
        .repeater(.init(tag: "Repeater", timeOn: timeOn, timeOff: timeOff, sets: (0..<sets).map { _ in .init() }))
    }

    private func maxHangExercise(sets: Int, isSingleArm: Bool = true, target: Int = 15) -> Routine.Exercise {
        .maxHang(.init(tag: "MaxHang", isSingleArm: isSingleArm, sets: (0..<sets).map { _ in .init(target: target) }))
    }

    private func campusExercise(doMirror: [Bool]) -> Routine.Exercise {
        .campus(.init(type: .maxLadder, sets: doMirror.map { .init(moves: .progressive, doMirror: $0) }))
    }

    private func exerciseSet(_ exercises: [Routine.Exercise], order: Routine.Order = .bfs, restTime: Int = 30) -> Session.ExerciseSet {
        .init(base: .init(exercises: exercises, restTime: restTime, order: order))
    }

    // MARK: - BFS traversal

    @Test func bfsForwardWalkVisitsColumnByColumnSkippingExhaustedExercises() {
        // A has 3 sets, B has 2 - a ragged column count.
        let set = exerciseSet([genericExercise(sets: 3), genericExercise(sets: 2)], order: .bfs)
        let runner = SessionRunner(sets: [set])

        var indices: ExerciseIndices? = nil
        let path: [ExerciseIndices?] = (0..<6).map { _ in
            indices = runner.nextIndices(from: indices)
            return indices
        }

        #expect(path == [
            .init(0, 0, 0), // A set 1
            .init(0, 1, 0), // B set 1
            .init(0, 0, 1), // A set 2
            .init(0, 1, 1), // B set 2
            .init(0, 0, 2), // A set 3 (B is exhausted)
            nil,            // finish screen
        ])
    }

    @Test func bfsRollsOverToNextRoutineSetWhenTheColumnIsExhausted() {
        let sets = [
            exerciseSet([genericExercise(sets: 1)], order: .bfs),
            exerciseSet([genericExercise(sets: 1)], order: .bfs),
        ]
        let runner = SessionRunner(sets: sets)

        #expect(runner.nextIndices(from: .init(0, 0, 0)) == .init(1))
    }

    @Test func bfsBackwardWalkIsTheExactInverseOfTheForwardWalk() {
        let set = exerciseSet([genericExercise(sets: 3), genericExercise(sets: 2)], order: .bfs)
        let runner = SessionRunner(sets: [set])

        let forwardPath: [ExerciseIndices] = [.init(0, 0, 0), .init(0, 1, 0), .init(0, 0, 1), .init(0, 1, 1), .init(0, 0, 2)]
        for (index, current) in forwardPath.enumerated() {
            let expectedPrev: ExerciseIndices? = index == 0 ? nil : forwardPath[index - 1]
            #expect(runner.prevIndices(from: current) == expectedPrev)
        }
    }

    @Test func bfsStartsAtTheFirstExerciseAndSetWhenThereAreNoIndicesYet() {
        let runner = SessionRunner(sets: [exerciseSet([genericExercise(sets: 1)], order: .bfs)])
        #expect(runner.nextIndices(from: nil) == .init(0, 0, 0))
    }

    // MARK: - DFS traversal

    @Test func dfsExhaustsAnExercisesSetsThenTheSetsExercisesThenTheRoutineSets() {
        let sets = [
            exerciseSet([genericExercise(sets: 2), genericExercise(sets: 1)], order: .dfs),
            exerciseSet([genericExercise(sets: 1)], order: .dfs),
        ]
        let runner = SessionRunner(sets: sets)

        var indices: ExerciseIndices? = nil
        let path = (0..<4).map { _ -> ExerciseIndices? in
            indices = runner.nextIndices(from: indices)
            return indices
        }

        #expect(path == [
            .init(0, 0, 0), // exercise A, set 1
            .init(0, 0, 1), // exercise A, set 2 (exhausts A)
            .init(0, 1, 0), // exercise B, set 1 (exhausts set 0's exercises)
            .init(1, 0, 0), // routine set 1's exercise (exhausts the routine sets)
        ])
        #expect(runner.nextIndices(from: path[3]!) == nil)
    }

    @Test func dfsPrevIndicesIsNilAtTheFirstPosition() {
        let runner = SessionRunner(sets: [exerciseSet([genericExercise(sets: 2)], order: .dfs)])
        #expect(runner.prevIndices(from: .init(0, 0, 0)) == nil)
    }

    @Test func dfsPrevIndicesWithinTheSameExerciseIsTheExactInverse() {
        let runner = SessionRunner(sets: [exerciseSet([genericExercise(sets: 2)], order: .dfs)])
        #expect(runner.prevIndices(from: .init(0, 0, 1)) == .init(0, 0, 0))
    }

    // MARK: - Phase machine

    @Test func genericRepBasedGoesReadyToRest() {
        let set = exerciseSet([genericExercise(sets: 1, dataType: .repWeight)])
        let runner = SessionRunner(sets: [set])
        #expect(runner.nextPhase(at: .init(0, 0, 0), phase: .ready, rep: .zero) == .rest)
    }

    @Test func genericTimedAlternatesOnAndOffUntilRepsAreExhaustedThenRests() {
        let set = exerciseSet([genericExercise(sets: 1, dataType: .timeWeight, sideType: .independent)])
        let runner = SessionRunner(sets: [set])
        let indices = ExerciseIndices(0, 0, 0)

        #expect(runner.nextPhase(at: indices, phase: .ready, rep: .zero) == .on)
        #expect(runner.nextPhase(at: indices, phase: .on, rep: .init(current: 1, max: 2)) == .off)
        #expect(runner.nextPhase(at: indices, phase: .off, rep: .init(current: 1, max: 2)) == .on)
        #expect(runner.nextPhase(at: indices, phase: .on, rep: .init(current: 2, max: 2)) == .rest)
        #expect(runner.nextPhase(at: indices, phase: .rest, rep: .zero) == nil)
    }

    @Test func repeaterAndMaxHangFollowReadyOnOffRest() {
        let repeaterSet = exerciseSet([repeaterExercise(sets: 1)])
        let maxHangSet = exerciseSet([maxHangExercise(sets: 1)])
        for set in [repeaterSet, maxHangSet] {
            let runner = SessionRunner(sets: [set])
            let indices = ExerciseIndices(0, 0, 0)
            #expect(runner.nextPhase(at: indices, phase: .ready, rep: .zero) == .on)
            #expect(runner.nextPhase(at: indices, phase: .on, rep: .init(current: 0, max: 1)) == .off)
            #expect(runner.nextPhase(at: indices, phase: .off, rep: .init(current: 1, max: 1)) == .on)
            #expect(runner.nextPhase(at: indices, phase: .on, rep: .init(current: 1, max: 1)) == .rest)
        }
    }

    @Test func campusGoesToOffOnlyWhenMirroredOtherwiseStraightToRest() {
        let mirrored = exerciseSet([campusExercise(doMirror: [true])])
        let unmirrored = exerciseSet([campusExercise(doMirror: [false])])
        let indices = ExerciseIndices(0, 0, 0)

        let mirroredRunner = SessionRunner(sets: [mirrored])
        #expect(mirroredRunner.nextPhase(at: indices, phase: .ready, rep: .init(current: 0, max: 1)) == .off)
        #expect(mirroredRunner.nextPhase(at: indices, phase: .off, rep: .zero) == .rest)
        #expect(mirroredRunner.nextPhase(at: indices, phase: .on, rep: .zero) == .rest)

        let unmirroredRunner = SessionRunner(sets: [unmirrored])
        #expect(unmirroredRunner.nextPhase(at: indices, phase: .ready, rep: .init(current: 0, max: 0)) == .rest)
    }

    @Test func nextPhaseIsNilWhenThereIsNoCurrentPhaseOrExercise() {
        let runner = SessionRunner(sets: [exerciseSet([genericExercise(sets: 1)])])
        #expect(runner.nextPhase(at: .init(0, 0, 0), phase: nil, rep: .zero) == nil)
        #expect(runner.nextPhase(at: nil, phase: .ready, rep: .zero) == nil)
    }

    @Test func prevPhaseGoesBackToReadyFromAnyPhaseExceptReadyOrNil() {
        let runner = SessionRunner(sets: [exerciseSet([genericExercise(sets: 1)])])
        #expect(runner.prevPhase(from: .ready) == nil)
        #expect(runner.prevPhase(from: nil) == nil)
        #expect(runner.prevPhase(from: .on) == .ready)
        #expect(runner.prevPhase(from: .off) == .ready)
        #expect(runner.prevPhase(from: .rest) == .ready)
    }

    // MARK: - Timer duration

    @Test func timerDurationForNonTimedGenericIsZeroExceptDuringRest() {
        let set = exerciseSet([genericExercise(sets: 1, dataType: .repWeight)], restTime: 45)
        let runner = SessionRunner(sets: [set])
        let indices = ExerciseIndices(0, 0, 0)

        #expect(runner.timerDuration(at: indices, phase: .ready) == .zero)
        #expect(runner.timerDuration(at: indices, phase: .on) == .zero)
        #expect(runner.timerDuration(at: indices, phase: .rest) == .seconds(45))
    }

    @Test func timerDurationForTimedGeneric() {
        let set = exerciseSet([genericExercise(sets: 1, dataType: .timeWeight)], restTime: 45)
        let runner = SessionRunner(sets: [set])
        let indices = ExerciseIndices(0, 0, 0)

        #expect(runner.timerDuration(at: indices, phase: .ready) == .seconds(5))
        #expect(runner.timerDuration(at: indices, phase: .off) == .seconds(5))
        #expect(runner.timerDuration(at: indices, phase: .on) == .seconds(5)) // Routine.GenericSet(num: 5)
        #expect(runner.timerDuration(at: indices, phase: .rest) == .seconds(45))
    }

    @Test func timerDurationForRepeater() {
        let set = exerciseSet([repeaterExercise(sets: 1, timeOn: 12, timeOff: 8)], restTime: 45)
        let runner = SessionRunner(sets: [set])
        let indices = ExerciseIndices(0, 0, 0)

        #expect(runner.timerDuration(at: indices, phase: .ready) == .seconds(10))
        #expect(runner.timerDuration(at: indices, phase: .on) == .seconds(12))
        #expect(runner.timerDuration(at: indices, phase: .off) == .seconds(8))
        #expect(runner.timerDuration(at: indices, phase: .rest) == .seconds(45))
    }

    @Test func timerDurationForMaxHang() {
        let set = exerciseSet([maxHangExercise(sets: 1, target: 15)], restTime: 45)
        let runner = SessionRunner(sets: [set])
        let indices = ExerciseIndices(0, 0, 0)

        #expect(runner.timerDuration(at: indices, phase: .ready) == .seconds(10))
        #expect(runner.timerDuration(at: indices, phase: .on) == .seconds(15))
        #expect(runner.timerDuration(at: indices, phase: .off) == .seconds(20))
        #expect(runner.timerDuration(at: indices, phase: .rest) == .seconds(45))
    }

    @Test func timerDurationForCampus() {
        let set = exerciseSet([campusExercise(doMirror: [true])], restTime: 45)
        let runner = SessionRunner(sets: [set])
        let indices = ExerciseIndices(0, 0, 0)

        #expect(runner.timerDuration(at: indices, phase: .ready) == .seconds(10))
        #expect(runner.timerDuration(at: indices, phase: .on) == .seconds(10))
        #expect(runner.timerDuration(at: indices, phase: .off) == .seconds(45))
        #expect(runner.timerDuration(at: indices, phase: .rest) == .seconds(45))
    }

    @Test func timerDurationIsZeroWithNoIndicesOrPhase() {
        let runner = SessionRunner(sets: [exerciseSet([genericExercise(sets: 1)])])
        #expect(runner.timerDuration(at: nil, phase: .ready) == .zero)
        #expect(runner.timerDuration(at: .init(0, 0, 0), phase: nil) == .zero)
    }

    // MARK: - Repeater rep seeding

    @Test func repeaterRepSeedsTwoForIndependentSidedTimedGeneric() {
        let set = exerciseSet([genericExercise(sets: 1, dataType: .timeWeight, sideType: .independent)])
        let runner = SessionRunner(sets: [set])
        #expect(runner.repeaterRep(at: .init(0, 0, 0), phase: .ready, current: .zero) == .init(max: 2))
    }

    @Test func repeaterRepSeedsOneForDependentSidedTimedGeneric() {
        let set = exerciseSet([genericExercise(sets: 1, dataType: .timeWeight, sideType: .dependent)])
        let runner = SessionRunner(sets: [set])
        #expect(runner.repeaterRep(at: .init(0, 0, 0), phase: .ready, current: .zero) == .init(max: 1))
    }

    @Test func repeaterRepSeedsZeroForRepBasedGeneric() {
        let set = exerciseSet([genericExercise(sets: 1, dataType: .repWeight)])
        let runner = SessionRunner(sets: [set])
        #expect(runner.repeaterRep(at: .init(0, 0, 0), phase: .ready, current: .zero) == .init(max: 0))
    }

    @Test func repeaterRepSeedsTwoForSingleArmMaxHangAndOneOtherwise() {
        let singleArm = exerciseSet([maxHangExercise(sets: 1, isSingleArm: true)])
        let twoHanded = exerciseSet([maxHangExercise(sets: 1, isSingleArm: false)])
        let indices = ExerciseIndices(0, 0, 0)

        #expect(SessionRunner(sets: [singleArm]).repeaterRep(at: indices, phase: .ready, current: .zero) == .init(max: 2))
        #expect(SessionRunner(sets: [twoHanded]).repeaterRep(at: indices, phase: .ready, current: .zero) == .init(max: 1))
    }

    @Test func repeaterRepSeedsOneForMirroredCampusAndZeroOtherwise() {
        let mirrored = exerciseSet([campusExercise(doMirror: [true])])
        let unmirrored = exerciseSet([campusExercise(doMirror: [false])])
        let indices = ExerciseIndices(0, 0, 0)

        #expect(SessionRunner(sets: [mirrored]).repeaterRep(at: indices, phase: .ready, current: .zero) == .init(max: 1))
        #expect(SessionRunner(sets: [unmirrored]).repeaterRep(at: indices, phase: .ready, current: .zero) == .init(max: 0))
    }

    @Test func repeaterRepAdvancesOnOnAndHoldsOnOff() {
        let set = exerciseSet([repeaterExercise(sets: 1)])
        let runner = SessionRunner(sets: [set])
        let indices = ExerciseIndices(0, 0, 0)
        let current = RepeaterRep(current: 1, max: 3)

        #expect(runner.repeaterRep(at: indices, phase: .on, current: current) == current.next())
        #expect(runner.repeaterRep(at: indices, phase: .off, current: current) == current)
    }
}
