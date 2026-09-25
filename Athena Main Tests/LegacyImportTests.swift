//
//  LegacyImportTests.swift
//  AthenaAscendTests
//
//  Created by Zach Wassynger on 9/24/26.
//
//  Fixtures here are built directly from V2 model objects and fed through the same
//  DTO initializers `DataExporter` uses (`AthleteExportDTO(_:)`, `ExerciseExportDTO(_:)`,
//  …), rather than committed JSON files — this exercises the exact same decode-free
//  path while staying self-contained. `decodingRoundTripPreservesDates` separately
//  guards the actual JSON encode/decode strategy match.

import Foundation
import SwiftData
import Testing
@testable import Athena

/// Serialized: each test builds its own `ModelContainer`, and running many of them
/// concurrently (Swift Testing's default) triggers a reliable crash in this host —
/// tests pass individually but crash when run alongside each other in parallel.
@Suite(.serialized)
struct LegacyImportTests {

    // MARK: - Fixture

    private struct Fixture {
        var archive: LegacyImport.Archive
        var athleteA: SchemaV2.Athlete
        var athleteB: SchemaV2.Athlete
        var benchExerciseUUID: UUID
        var routineName: String
        /// `ModelContext` does not retain its owning `ModelContainer` — a context (or
        /// any `@Model` object tied to one) becomes invalid once the container that
        /// created it is deallocated. `athleteA`/`athleteB` above are read by callers
        /// after `makeFixture` returns, so the container that owns them must be kept
        /// alive for at least as long as the `Fixture` itself; this field is that
        /// anchor and is otherwise unused.
        var v2Container: ModelContainer
    }

    /// One routine (2 super sets, all four exercise kinds, one unlinked payload, one
    /// renamed library row), one solo finished session recording every kind (including
    /// a mirrored and an unmirrored campus set), one diverged session (3 expected sets,
    /// 2 recorded), one finished team session with one matched entry, and one orphaned
    /// team-flagged entry whose team session was never exported.
    @MainActor
    private func makeFixture() throws -> Fixture {
        let container = try makeV2Container()
        let context = container.mainContext

        let athleteA = SchemaV2.Athlete(name: "Alice", createdAt: .now.addingTimeInterval(-86400 * 30))
        let athleteB = SchemaV2.Athlete(name: "Bob", createdAt: .now.addingTimeInterval(-86400 * 10))
        context.insert(athleteA)
        context.insert(athleteB)

        // Library rows. `benchExercise.name` is the post-rename label; the routine
        // payload below still says "Bench Press" — proving the import prefers the
        // library row's name over the payload's stale one.
        let benchExercise = SchemaV2.GenericExercise(name: "Bench Press (renamed)", dataType: .repWeight, sideType: .independent)
        let repeaterExercise = SchemaV2.RepeaterExercise(name: "Half Crimp", timeOn: 7, timeOff: 3)
        let maxHangExercise = SchemaV2.MaxHangExercise(name: "Big Move", isSingleArm: true)
        let campusExercise = SchemaV2.CampusLibraryExercise(name: "Max Ladder", campusType: .maxLadder)
        context.insert(benchExercise)
        context.insert(repeaterExercise)
        context.insert(maxHangExercise)
        context.insert(campusExercise)

        let genericSets = SchemaV2.Routine.GenericSets(name: "Bench Press", dataType: .repWeight, sideType: .independent, sets: [.init(min: 8, max: 12)], exerciseID: benchExercise.uuid)
        let degenerateGenericSets = SchemaV2.Routine.GenericSets(name: "Plank", dataType: .rep, sideType: nil, sets: [.init(num: 5)], exerciseID: nil)
        let repeaterSets = SchemaV2.Routine.RepeaterSets(tag: "Half Crimp", timeOn: 7, timeOff: 3, sets: [.init(numReps: 6, weight: 0)], exerciseID: repeaterExercise.uuid)
        let maxHangSets = SchemaV2.Routine.MaxHangSets(tag: "Big Move", isSingleArm: true, sets: [.init(target: 10, targetAlt: 8, weight: 0, weightAlt: -5)], exerciseID: maxHangExercise.uuid)
        let campusDefined = SchemaV2.Routine.CampusSets.PlannedSet(board: .largeEdges, moves: .defined([.init(rung: .full(1), side: .both)]), doMirror: true)
        let campusBaseline = SchemaV2.Routine.CampusSets.PlannedSet(board: .largeEdges, moves: .baseline([0, 2, 4]), doMirror: false)
        let campusProgressive = SchemaV2.Routine.CampusSets.PlannedSet(board: .largeEdges, moves: .progressive, doMirror: false)
        let campusSets = SchemaV2.Routine.CampusSets(type: .maxLadder, sets: [campusDefined, campusBaseline, campusProgressive], exerciseID: campusExercise.uuid)
        let doublesSets = SchemaV2.Routine.CampusSets(type: .doubles, sets: [.init(board: .largeEdges, moves: .defined([.init(rung: .full(3), side: .both)]), doMirror: true)], exerciseID: nil)

        let setA = SchemaV2.Routine.ExerciseSet(name: "Set A", exercises: [.generic(genericSets), .generic(degenerateGenericSets)], restTime: 60, order: .dfs)
        let setB = SchemaV2.Routine.ExerciseSet(name: "Set B", exercises: [.repeater(repeaterSets), .maxHang(maxHangSets), .campus(campusSets), .campus(doublesSets)], restTime: 90, order: .bfs)
        let routine = SchemaV2.Routine(name: "Test Routine", sets: [setA, setB], createdAt: .now.addingTimeInterval(-86400 * 20))
        context.insert(routine)

        // Solo finished session recording every kind.
        var soloSetA = SchemaV2.Session.ExerciseSet(base: setA)
        soloSetA.exercises[0] = .generic(.init(expected: genericSets, actual: [.init(numReps: 10, numRepsAlt: 10, weight: 135, weightAlt: 140, notes: "PR")], notes: "felt strong"))
        soloSetA.exercises[1] = .generic(.init(expected: degenerateGenericSets, actual: [.init(numReps: 5)], notes: ""))

        var soloSetB = SchemaV2.Session.ExerciseSet(base: setB)
        soloSetB.exercises[0] = .repeater(.init(expected: repeaterSets, actual: [.init(numReps: 6, weight: 5, notes: "")], notes: ""))
        soloSetB.exercises[1] = .maxHang(.init(expected: maxHangSets, actual: [.init(time: 10, timeAlt: 8, weight: 0, weightAlt: -5, notes: "")], notes: ""))
        soloSetB.exercises[2] = .campus(.init(expected: campusSets, actual: [
            .init(main: .init(board: .largeEdges, moves: [.init(rung: .full(1), side: .both)], notes: "clean"),
                  alt: .init(board: .largeEdges, moves: [.init(rung: .full(1), side: .both)], notes: "clean")),
            .init(main: .init(board: .largeEdges, moves: [.init(rung: .full(3), side: .right)]), alt: nil),
        ], notes: ""))
        // soloSetB.exercises[3] (doubles) left as its blank base snapshot — an expected-only position.

        let soloSession = SchemaV2.Session(
            startTime: .now.addingTimeInterval(-3600 * 5), endTime: .now.addingTimeInterval(-3600 * 4),
            sets: [soloSetA, soloSetB], notes: "great session", bodyWeight: 165,
            standoutSong: .init(name: "Song", artist: "Artist"), athlete: athleteA
        )
        context.insert(soloSession)
        soloSession.routine = routine
        soloSession.routineName = routine.name

        // Diverged session: 3 expected sets, only 2 recorded.
        let divergedSets = SchemaV2.Routine.GenericSets(name: "Divergence Test", dataType: .rep, sets: [.init(num: 5), .init(num: 5), .init(num: 5)], exerciseID: nil)
        let divergedRoutineSet = SchemaV2.Routine.ExerciseSet(name: "Solo Set", exercises: [.generic(divergedSets)], restTime: 30, order: .bfs)
        var divergedSessionSet = SchemaV2.Session.ExerciseSet(base: divergedRoutineSet)
        divergedSessionSet.exercises[0] = .generic(.init(expected: divergedSets, actual: [.init(numReps: 5), .init(numReps: 5)], notes: ""))
        let divergedSession = SchemaV2.Session(
            startTime: .now.addingTimeInterval(-3600 * 3), endTime: .now.addingTimeInterval(-3600 * 2),
            sets: [divergedSessionSet], notes: "", bodyWeight: 160, athlete: athleteA
        )
        context.insert(divergedSession)

        // Team session with one matched entry (Alice) and one entry whose team was
        // never exported (Bob) — an orphaned candidate that must import standalone.
        let teamSets = SchemaV2.Routine.GenericSets(name: "Team Bench", dataType: .repWeight, sets: [.init(min: 5, max: 5)], exerciseID: nil)
        let teamRoutineSet = SchemaV2.Routine.ExerciseSet(name: "Team Set", exercises: [.generic(teamSets)], restTime: 60, order: .bfs)
        let teamTemplate = SchemaV2.Session.ExerciseSet(base: teamRoutineSet)

        let teamStart = Date.now.addingTimeInterval(-3600 * 8)
        let teamEnd = Date.now.addingTimeInterval(-3600 * 7)

        var entryASet = teamTemplate
        entryASet.exercises[0] = .generic(.init(expected: teamSets, actual: [.init(numReps: 5, weight: 100)], notes: ""))
        let entryA = SchemaV2.Session(startTime: teamStart, endTime: teamEnd, sets: [entryASet], notes: "Alice notes", bodyWeight: 140, athlete: athleteA)
        context.insert(entryA)

        let team = SchemaV2.TeamSession(startTime: teamStart, endTime: teamEnd, notes: "Team notes", sets: [teamTemplate], entries: [entryA])
        context.insert(team)
        entryA.teamSession = team

        let phantomTeam = SchemaV2.TeamSession(startTime: .distantPast, endTime: .distantPast.addingTimeInterval(1))
        context.insert(phantomTeam)
        let orphanEntry = SchemaV2.Session(startTime: .distantPast, endTime: .distantPast.addingTimeInterval(1), sets: [], notes: "orphan", bodyWeight: 150, athlete: athleteB)
        context.insert(orphanEntry)
        orphanEntry.teamSession = phantomTeam

        try context.save()

        let archive = LegacyImport.Archive(
            athletes: [AthleteExportDTO(athleteA), AthleteExportDTO(athleteB)],
            exercises: [ExerciseExportDTO(benchExercise), ExerciseExportDTO(repeaterExercise), ExerciseExportDTO(maxHangExercise), ExerciseExportDTO(campusExercise)],
            routines: [RoutineExportDTO(routine)],
            sessions: [SessionExportDTO(soloSession), SessionExportDTO(divergedSession), SessionExportDTO(entryA), SessionExportDTO(orphanEntry)],
            teamSessions: [TeamSessionExportDTO(team)]
        )

        return Fixture(archive: archive, athleteA: athleteA, athleteB: athleteB, benchExerciseUUID: benchExercise.uuid, routineName: routine.name, v2Container: container)
    }

    @MainActor
    private func makeV3Container() throws -> ModelContainer {
        let schema = Schema(SchemaV3.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// A fresh in-memory V2 container. Callers must keep the returned container alive
    /// (as a local `let`, or embedded in a returned value like `Fixture.v2Container`)
    /// for as long as its `.mainContext` or any `@Model` object tied to it is used —
    /// `ModelContext` does not retain its owning container, so a context whose
    /// container has been deallocated crashes on first use. Always call this and read
    /// `.mainContext` from the *caller's* scope; never return `.mainContext` directly
    /// from a helper, since the container backing it would be released the moment that
    /// helper returns.
    @MainActor
    private func makeV2Container() throws -> ModelContainer {
        let schema = Schema(SchemaV2.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - Decode

    @Test func decodingRoundTripPreservesDates() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let originalDate = Date.now.addingTimeInterval(-12345)
        let athlete = SchemaV2.Athlete(name: "Alice", createdAt: originalDate)
        let dto = AthleteExportDTO(athlete)
        let data = try encoder.encode([dto])

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([AthleteExportDTO].self, from: data)

        #expect(decoded.count == 1)
        // ISO 8601 truncates sub-second precision, so compare with a small tolerance.
        #expect(abs(decoded[0].createdAt.timeIntervalSince(originalDate)) < 1)
        #expect(decoded[0].uuid == athlete.uuid)
    }

    @Test func readArchiveToleratesMissingFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "legacy-import-empty-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let archive = try LegacyImport.readArchive(from: directory)
        #expect(archive.athletes.isEmpty)
        #expect(archive.exercises.isEmpty)
        #expect(archive.routines.isEmpty)
        #expect(archive.sessions.isEmpty)
        #expect(archive.teamSessions.isEmpty)
    }

    // MARK: - Team matching (pure)

    @MainActor
    @Test func teamMatchingPrefersExactEndTimeOverStartTime() throws {
        let container = try makeV2Container()
        let context = container.mainContext
        let athlete = UUID()
        let end = Date.now
        let sessions = [
            try SessionExportDTO.stub(athleteID: athlete, startTime: end.addingTimeInterval(-100), endTime: end, isTeamSessionEntry: true, in: context),
        ]
        let team = try TeamSessionExportDTO.stub(startTime: end.addingTimeInterval(-50), endTime: end, entryAthleteIDs: [athlete], in: context)
        let result = LegacyImport.matchTeamEntries(sessions: sessions, teamSessions: [team])
        #expect(result.claims[0]?[athlete]?.sessionIndex == 0)
        #expect(result.claims[0]?[athlete]?.tier == .exactEndTime)
    }

    @MainActor
    @Test func teamMatchingFallsBackToStartTimeWhenNoEndTimeMatches() throws {
        let container = try makeV2Container()
        let context = container.mainContext
        let athlete = UUID()
        let start = Date.now
        let sessions = [
            try SessionExportDTO.stub(athleteID: athlete, startTime: start, endTime: nil, isTeamSessionEntry: true, in: context),
        ]
        let team = try TeamSessionExportDTO.stub(startTime: start, endTime: nil, entryAthleteIDs: [athlete], in: context)
        let result = LegacyImport.matchTeamEntries(sessions: sessions, teamSessions: [team])
        #expect(result.claims[0]?[athlete]?.tier == .exactStartTime)
    }

    @MainActor
    @Test func teamMatchingReportsUnmatchedEntryReference() throws {
        let container = try makeV2Container()
        let context = container.mainContext
        let athlete = UUID()
        let team = try TeamSessionExportDTO.stub(startTime: .now, endTime: .now, entryAthleteIDs: [athlete], in: context)
        let result = LegacyImport.matchTeamEntries(sessions: [], teamSessions: [team])
        #expect(result.unmatchedEntryReferences.count == 1)
        #expect(result.unmatchedEntryReferences[0].athleteID == athlete)
    }

    @MainActor
    @Test func teamMatchingLeavesUnclaimedCandidatesUnclaimed() throws {
        let container = try makeV2Container()
        let context = container.mainContext
        let athlete = UUID()
        // A team-flagged session whose start/end never match any team session.
        let sessions = [
            try SessionExportDTO.stub(athleteID: athlete, startTime: .distantPast, endTime: .distantPast, isTeamSessionEntry: true, in: context),
        ]
        let result = LegacyImport.matchTeamEntries(sessions: sessions, teamSessions: [])
        #expect(result.unclaimedCandidates == [0])
    }

    @MainActor
    @Test func teamMatchingNeverClaimsANonTeamSession() throws {
        let container = try makeV2Container()
        let context = container.mainContext
        let athlete = UUID()
        let end = Date.now
        let sessions = [
            try SessionExportDTO.stub(athleteID: athlete, startTime: end, endTime: end, isTeamSessionEntry: false, in: context),
        ]
        let team = try TeamSessionExportDTO.stub(startTime: end, endTime: end, entryAthleteIDs: [athlete], in: context)
        let result = LegacyImport.matchTeamEntries(sessions: sessions, teamSessions: [team])
        #expect(result.claims[0]?[athlete] == nil)
        #expect(result.unmatchedEntryReferences.count == 1)
    }

    // MARK: - Import (container)

    @MainActor
    @Test func refusesImportIntoNonEmptyStore() throws {
        let container = try makeV3Container()
        container.mainContext.insert(SchemaV3.Athlete(name: "Existing"))
        try container.mainContext.save()

        let fixture = try makeFixture()
        #expect(throws: LegacyImport.ImportError.storeNotEmpty) {
            try LegacyImport.apply(fixture.archive, into: container.mainContext)
        }
    }

    @MainActor
    @Test func importsRoutinesIntoRoutineDataRows() throws {
        let fixture = try makeFixture()
        let container = try makeV3Container()
        try LegacyImport.apply(fixture.archive, into: container.mainContext)

        let routines = try container.mainContext.fetch(FetchDescriptor<SchemaV3.Routine>())
        let routine = try #require(routines.first { $0.name == fixture.routineName })
        #expect(routine.superSets.count == 2)
        #expect(routine.superSets[0].restTime == 60)
        #expect(routine.superSets[0].order == .dfs)
        #expect(routine.superSets[1].order == .bfs)

        let routineData = try container.mainContext.fetch(FetchDescriptor<SchemaV3.RoutineData>())
        // setA has 2 exercises, setB has 4 -> 6 RoutineData rows for this routine.
        #expect(routineData.filter { $0.routine?.name == fixture.routineName }.count == 6)

        // Identify Bench's row by its known position (superSetIndex 0, setIndex 0)
        // rather than `$0.exercise?.name`: reading `Exercise.category` (which `.name`
        // switches on) crashes this test host whenever the fetched set spans more than
        // one distinct `Category` case, as this routine's exercises deliberately do —
        // a reproducible SwiftData/toolchain limitation for heterogeneous Codable-enum
        // attributes, the V3 analogue of the polymorphic-class-fetch crash documented
        // in `ExerciseLibraryTests.swift`. Verified in isolation: fetching even two
        // `Exercise` rows of different categories and reading `.category` on either
        // one crashes, while any number of same-category rows is fine.
        let benchRow = try #require(routineData.first { $0.position == .init(superSetIndex: 0, setIndex: 0) })
        guard case .range(let min, let max) = benchRow.expectedData.first?[.reps] else {
            Issue.record("Expected a .range value for the 8-12 prescription")
            return
        }
        #expect(min == 8 && max == 12)
    }

    @MainActor
    @Test func preservesExerciseLibraryGroupingsAcrossRenames() throws {
        let fixture = try makeFixture()
        let container = try makeV3Container()
        try LegacyImport.apply(fixture.archive, into: container.mainContext)

        // Verify dedup via object identity rather than `.name` (see the note in
        // `importsRoutinesIntoRoutineDataRows` on why reading `Exercise.category`
        // across heterogeneous rows crashes this test host). Bench appears both as a
        // routine payload (linked by `exerciseID`) and as a solo-session recording of
        // the same exercise; "not duplicated" means both occurrences resolve to the
        // exact same `Exercise` object.
        let routineData = try container.mainContext.fetch(FetchDescriptor<SchemaV3.RoutineData>())
        let exerciseData = try container.mainContext.fetch(FetchDescriptor<SchemaV3.ExerciseData>())

        let benchRoutineRow = try #require(routineData.first { $0.position == .init(superSetIndex: 0, setIndex: 0) })
        let benchSessionRow = try #require(exerciseData.first {
            $0.position == .init(superSetIndex: 0, setIndex: 0) && $0.session?.notes == "great session"
        })
        #expect(benchRoutineRow.exercise === benchSessionRow.exercise)

        // "Plank" is unlinked (`exerciseID == nil`) in both the routine and the same
        // solo session — dedup here must happen by derived category instead of a UUID
        // link, and should likewise resolve to one shared object.
        let plankRoutineRow = try #require(routineData.first { $0.position == .init(superSetIndex: 0, setIndex: 1) })
        let plankSessionRow = try #require(exerciseData.first {
            $0.position == .init(superSetIndex: 0, setIndex: 1) && $0.session?.notes == "great session"
        })
        #expect(plankRoutineRow.exercise === plankSessionRow.exercise)
        #expect(plankRoutineRow.exercise !== benchRoutineRow.exercise)
    }

    @MainActor
    @Test func importsSoloSessionDataWithSparseAltAndHoistedCampusNotes() throws {
        let fixture = try makeFixture()
        let container = try makeV3Container()
        try LegacyImport.apply(fixture.archive, into: container.mainContext)

        let sessions = try container.mainContext.fetch(FetchDescriptor<SchemaV3.Session>())
        let soloSession = try #require(sessions.first { $0.notes == "great session" })
        #expect(soloSession.standoutSong?.name == "Song")
        #expect(soloSession.routine?.name == fixture.routineName)
        #expect(soloSession.athletes.map(\.uuid) == [fixture.athleteA.uuid])

        let allData = try container.mainContext.fetch(FetchDescriptor<SchemaV3.ExerciseData>())
        let sessionData = allData.filter { $0.session === soloSession }
        #expect(sessionData.count == 6) // 2 (setA) + 4 (setB), including the blank doubles slot

        // Identified by position, not `$0.exercise?.name` — see the note in
        // `importsRoutinesIntoRoutineDataRows` on the heterogeneous-category fetch
        // crash. Bench sits at setA[0]; the maxLadder campus exercise sits at setB[2].
        let benchRow = try #require(sessionData.first { $0.position == .init(superSetIndex: 0, setIndex: 0) })
        #expect(benchRow.athlete?.uuid == fixture.athleteA.uuid)
        // numRepsAlt (10) equals numReps (10) -> omitted; weightAlt (140) differs from
        // weight (135) -> kept.
        #expect(benchRow.actualData.first?[.repsAlt] == nil)
        #expect(benchRow.actualData.first?[.weightAlt] == .number(140))
        #expect(benchRow.actualData.first?[.notes] == .text("PR"))

        let campusRow = try #require(sessionData.first { $0.position == .init(superSetIndex: 1, setIndex: 2) })
        #expect(campusRow.actualData.count == 2)
        #expect(campusRow.actualData[0][.campusAlt] != nil)  // mirrored
        #expect(campusRow.actualData[1][.campusAlt] == nil)  // not mirrored
        #expect(campusRow.actualData[0][.notes] == .text("clean")) // hoisted from main, not duplicated from alt
    }

    @MainActor
    @Test func preservesDivergedActualDataVerbatim() throws {
        let fixture = try makeFixture()
        let container = try makeV3Container()
        try LegacyImport.apply(fixture.archive, into: container.mainContext)

        // Identified by its data shape (three .reps(discrete(5)) expected sets is
        // unique to this row), not `$0.exercise?.name` — see the note in
        // `importsRoutinesIntoRoutineDataRows` on the heterogeneous-category fetch
        // crash this avoids.
        let allData = try container.mainContext.fetch(FetchDescriptor<SchemaV3.ExerciseData>())
        let row = try #require(allData.first {
            $0.expectedData.count == 3 && $0.expectedData.allSatisfy { $0[.reps] == .discrete(5) }
        })
        #expect(row.expectedData.count == 3)
        #expect(row.actualData.count == 2)
    }

    @MainActor
    @Test func importsTeamSessionAsOneSessionWithPerAthleteData() throws {
        let fixture = try makeFixture()
        let container = try makeV3Container()
        try LegacyImport.apply(fixture.archive, into: container.mainContext)

        let sessions = try container.mainContext.fetch(FetchDescriptor<SchemaV3.Session>())
        let teamSessions = sessions.filter { $0.notes.contains("Team notes") }
        #expect(teamSessions.count == 1)
        let teamSession = try #require(teamSessions.first)
        #expect(teamSession.notes == "Team notes\n\nAlice: Alice notes")
        // Only Alice's entry matched (`entryA`) — Bob's orphaned entry becomes its own
        // standalone session and isn't one of this team session's athletes.
        #expect(teamSession.athletes.map(\.uuid) == [fixture.athleteA.uuid])

        let allData = try container.mainContext.fetch(FetchDescriptor<SchemaV3.ExerciseData>())
        let teamData = allData.filter { $0.session === teamSession }
        #expect(teamData.count == 1)
        #expect(teamData[0].athlete?.uuid == fixture.athleteA.uuid)
    }

    @MainActor
    @Test func orphanedTeamEntryBecomesStandaloneSession() throws {
        let fixture = try makeFixture()
        let container = try makeV3Container()
        try LegacyImport.apply(fixture.archive, into: container.mainContext)

        let sessions = try container.mainContext.fetch(FetchDescriptor<SchemaV3.Session>())
        let orphanSessions = sessions.filter { $0.notes == "orphan" }
        #expect(orphanSessions.count == 1)
        #expect(orphanSessions.first?.athletes.map(\.uuid) == [fixture.athleteB.uuid])

        let allData = try container.mainContext.fetch(FetchDescriptor<SchemaV3.ExerciseData>())
        #expect(allData.contains { $0.session === orphanSessions.first && $0.athlete?.uuid == fixture.athleteB.uuid } == false)
        // The orphan entry has no exercises, so it contributes zero ExerciseData rows
        // but must still have imported as its own standalone Session (asserted above).
    }

    @MainActor
    @Test func preservesAthleteUUIDs() throws {
        let fixture = try makeFixture()
        let container = try makeV3Container()
        try LegacyImport.apply(fixture.archive, into: container.mainContext)

        let athletes = try container.mainContext.fetch(FetchDescriptor<SchemaV3.Athlete>())
        #expect(athletes.contains { $0.uuid == fixture.athleteA.uuid })
        #expect(athletes.contains { $0.uuid == fixture.athleteB.uuid })
    }
}

// MARK: - Test-only DTO stubs

/// `SessionExportDTO`/`TeamSessionExportDTO` only expose the model-deriving
/// initializer, which requires a real `Session`/`TeamSession` object. These stubs
/// build one just to extract the DTO, so the pure `matchTeamEntries` tests can work
/// with plain UUIDs/dates instead of a full fixture.
private extension SessionExportDTO {
    /// Free-standing (never-inserted) `@Model` objects reliably crash when their
    /// relationship properties are read in this test host, so `context` must be a
    /// real, live `ModelContext` that both objects are inserted into before any
    /// relationship is assigned or read.
    @MainActor
    static func stub(athleteID: UUID, startTime: Date, endTime: Date?, isTeamSessionEntry: Bool, in context: ModelContext) throws -> SessionExportDTO {
        let athlete = SchemaV2.Athlete(name: "Stub")
        context.insert(athlete)
        // `AthleteExportDTO`/`SessionExportDTO` read `athlete.uuid`, which is
        // regenerated per-instance — force it to the requested value via a second
        // pass isn't possible (uuid has no setter override here), so route through a
        // real Session with a matching athlete `uuid` set at construction instead.
        let session = SchemaV2.Session(startTime: startTime, endTime: endTime, athlete: athlete)
        context.insert(session)
        if isTeamSessionEntry {
            let team = SchemaV2.TeamSession()
            context.insert(team)
            session.teamSession = team
        }
        try context.save()
        var dto = SessionExportDTO(session)
        dto.athleteID = athleteID
        return dto
    }
}

private extension TeamSessionExportDTO {
    @MainActor
    static func stub(startTime: Date, endTime: Date?, entryAthleteIDs: [UUID], in context: ModelContext) throws -> TeamSessionExportDTO {
        let team = SchemaV2.TeamSession(startTime: startTime, endTime: endTime)
        context.insert(team)
        try context.save()
        var dto = TeamSessionExportDTO(team)
        dto.entryAthleteIDs = entryAthleteIDs
        return dto
    }
}
