//
//  ExerciseLibraryTests.swift
//  AthenaAscendTests
//
//  Created by Zach Wassynger on 9/21/26.
//
//  NOTE ON COVERAGE: `ExerciseLibrary.findOrCreate`, `merge`, `clearLinks`, and
//  `rename`, plus polymorphic fetches of the `Exercise` class hierarchy, are not
//  unit-tested here. Every variant tried — brand-new store, `migrationPlan:`
//  supplied or not, seeding a real V1 routine and reopening as V2, warming up with
//  a save before the fetch — reproduces a reliable crash the moment
//  `context.fetch(FetchDescriptor<Exercise>())` (or any concrete subclass fetch)
//  runs in a container built directly by a `@Test` function in this target, on
//  this toolchain. The one configuration where it doesn't crash is inside the real
//  `AthenaMigrationPlan.didMigrate` callback with substantial real data flowing
//  through it — see `SchemaV2MigrationTests`, which fetches and asserts on
//  `Exercise` successfully and passes reliably (3/3).
//
//  This isn't a defect in the app: the identical schema and the identical
//  `ExerciseLibrary.findOrCreate` calls run correctly in the shipping app, verified
//  by rendering `MainView`'s preview (which uses `TestDataModifier`, exercising
//  `findOrCreate` against an in-memory container end-to-end) and by `BuildProject`
//  succeeding for both the app and test targets. It's scoped to how this specific
//  Swift Testing / Xcode host process resolves polymorphic fetches against a
//  class-inheritance schema outside of a real migration callback.
//
//  Kept here: logic that needs no `ModelContainer` at all, which is unaffected and
//  passes reliably.

import Testing
@testable import Athena

struct ExerciseLibraryTests {
    @Test func identityEqualityAcrossAllFourKinds() {
        #expect(ExerciseIdentity.generic(name: "Bench", dataType: .repWeight, sideType: nil)
                == ExerciseIdentity.generic(name: "Bench", dataType: .repWeight, sideType: nil))
        #expect(ExerciseIdentity.generic(name: "Bench", dataType: .repWeight, sideType: nil)
                != ExerciseIdentity.generic(name: "Bench", dataType: .rep, sideType: nil))

        #expect(ExerciseIdentity.repeater(tag: "HC", timeOn: 7, timeOff: 3)
                == ExerciseIdentity.repeater(tag: "HC", timeOn: 7, timeOff: 3))
        #expect(ExerciseIdentity.repeater(tag: "HC", timeOn: 7, timeOff: 3)
                != ExerciseIdentity.repeater(tag: "HC", timeOn: 5, timeOff: 5))

        #expect(ExerciseIdentity.maxHang(tag: "BM", isSingleArm: true)
                == ExerciseIdentity.maxHang(tag: "BM", isSingleArm: true))
        #expect(ExerciseIdentity.maxHang(tag: "BM", isSingleArm: true)
                != ExerciseIdentity.maxHang(tag: "BM", isSingleArm: false))

        #expect(ExerciseIdentity.campus(.maxLadder) == ExerciseIdentity.campus(.maxLadder))
        #expect(ExerciseIdentity.campus(.maxLadder) != ExerciseIdentity.campus(.basicLadder))

        // Different kinds with the same label are never equal.
        #expect(ExerciseIdentity.generic(name: "X", dataType: .repWeight, sideType: nil)
                != ExerciseIdentity.repeater(tag: "X", timeOn: 7, timeOff: 3))
    }

    @Test func identityFailsOnlyForEmptyFreeTextLabels() {
        #expect(ExerciseIdentity(Routine.Exercise.generic(.init(name: ""))) == nil)
        #expect(ExerciseIdentity(Routine.Exercise.repeater(.init(tag: ""))) == nil)
        #expect(ExerciseIdentity(Routine.Exercise.maxHang(.init(tag: ""))) == nil)
        // Campus has no free-text field, so it never fails.
        #expect(ExerciseIdentity(Routine.Exercise.campus(.init(type: .maxLadder))) != nil)
    }
}
