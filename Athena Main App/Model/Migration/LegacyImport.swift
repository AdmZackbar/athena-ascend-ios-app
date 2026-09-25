//
//  LegacyImport.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/24/26.
//

import Foundation
import SwiftData

/// Rebuilds a V3 store from the JSON produced by `DataExporter.exportAllModels` on a
/// V2 build. This replaces an in-place SwiftData migration: V2→V3 renames/decomposes
/// the Codable blob columns and de-inherits the `Exercise` class hierarchy, neither of
/// which SwiftData's lightweight migration can express, and a custom `didMigrate`
/// stage can't read the V2 blobs once the V3 schema has already been applied. Starting
/// from an empty V3 store and importing the export sidesteps all of that, and never
/// needs the polymorphic V2 `Exercise` fetch that crashes reliably in-target
/// (`ExerciseLibraryTests.swift`) — `ExerciseExportDTO.Kind` is already flattened per
/// subclass.
///
/// The V2 store itself is never touched by this type — it is only ever read via its
/// exported JSON — so re-exporting from a reinstalled V2 build remains possible for as
/// long as that JSON might be wrong or incomplete.
nonisolated enum LegacyImport {

    // MARK: - Archive

    struct Archive {
        var athletes: [AthleteExportDTO]
        var exercises: [ExerciseExportDTO]
        var routines: [RoutineExportDTO]
        var sessions: [SessionExportDTO]
        var teamSessions: [TeamSessionExportDTO]
    }

    enum ImportError: Error {
        /// The destination store already has data. Import is only meant to run once,
        /// against a freshly created V3 store — there is no merge/dedupe logic here.
        case storeNotEmpty
    }

    /// Decodes the five files `DataExporter.exportAllModels` writes. A missing file
    /// decodes as an empty array rather than throwing, so an export that predates a
    /// given entity (or simply has none of it) still imports cleanly.
    static func readArchive(from directory: URL) throws -> Archive {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        func decodeArray<Element: Decodable>(_ type: Element.Type, filename: String) throws -> [Element] {
            let url = directory.appending(path: filename)
            guard FileManager.default.fileExists(atPath: url.path) else { return [] }
            let data = try Data(contentsOf: url)
            return try decoder.decode([Element].self, from: data)
        }

        return Archive(
            athletes: try decodeArray(AthleteExportDTO.self, filename: "athletes.json"),
            exercises: try decodeArray(ExerciseExportDTO.self, filename: "exercises.json"),
            routines: try decodeArray(RoutineExportDTO.self, filename: "routines.json"),
            sessions: try decodeArray(SessionExportDTO.self, filename: "sessions.json"),
            teamSessions: try decodeArray(TeamSessionExportDTO.self, filename: "teamSessions.json")
        )
    }

    // MARK: - Summary (dry-run / post-import report)

    struct Summary: Equatable {
        var athletesImported = 0
        var exercisesImported = 0
        var exercisesSkippedUnknownKind = 0
        var routinesImported = 0
        var routineDataRows = 0
        var duplicateRoutineNames: [String] = []
        var soloSessionsImported = 0
        var teamSessionsImported = 0
        var exerciseDataRows = 0
        var teamMatchesByTier: [TeamEntryMatch.Tier: Int] = [:]
        var unmatchedEntryReferences = 0
        var unclaimedTeamCandidates = 0
    }

    // MARK: - Team-entry matching

    /// The JSON has no shared team-session ID (`SessionExportDTO` only carries
    /// `isTeamSessionEntry`, `TeamSessionExportDTO` only carries `entryAthleteIDs`), so
    /// entries are matched heuristically. `TeamSession.finish`/`updateEndTime`
    /// (`TeamSessionV2.swift`) assign the *identical* `Date` to the parent and every
    /// entry, so an exact `endTime` match is effectively collision-free for any
    /// finished team session. `startTime` only matches exactly after a manual edit
    /// (`updateStartTime`), so it's a weaker secondary signal, with proximity plus a
    /// set-shape check as a last resort.
    struct TeamEntryMatch: Equatable {
        var sessionIndex: Int
        var tier: Tier

        enum Tier: Hashable {
            case exactEndTime
            case exactStartTime
            case proximity
        }
    }

    struct TeamMatchResult {
        /// `teamSessions` index -> athlete UUID -> the session it was matched to.
        var claims: [Int: [UUID: TeamEntryMatch]] = [:]
        /// Indices into `sessions` that are team entries (`isTeamSessionEntry == true`)
        /// but were never claimed by any team session. Per the import plan, these are
        /// not dropped — they become their own standalone V3 `Session`.
        var unclaimedCandidates: [Int] = []
        /// `entryAthleteIDs` references with no matching candidate at all (e.g. the
        /// entry was deleted after the team session recorded it).
        var unmatchedEntryReferences: [(teamSessionIndex: Int, athleteID: UUID)] = []
    }

    static func matchTeamEntries(
        sessions: [SessionExportDTO],
        teamSessions: [TeamSessionExportDTO],
        proximityTolerance: TimeInterval = 300
    ) -> TeamMatchResult {
        var result = TeamMatchResult()
        var claimedIndices: Set<Int> = []
        let candidateIndices = sessions.indices.filter { sessions[$0].isTeamSessionEntry }

        let teamOrder = teamSessions.indices.sorted { teamSessions[$0].startTime < teamSessions[$1].startTime }

        for t in teamOrder {
            let team = teamSessions[t]
            var athleteClaims: [UUID: TeamEntryMatch] = [:]
            for athleteID in team.entryAthleteIDs {
                let pool = candidateIndices.filter { !claimedIndices.contains($0) && sessions[$0].athleteID == athleteID }
                guard let match = bestMatch(in: pool, sessions: sessions, team: team, proximityTolerance: proximityTolerance) else {
                    result.unmatchedEntryReferences.append((teamSessionIndex: t, athleteID: athleteID))
                    continue
                }
                athleteClaims[athleteID] = match
                claimedIndices.insert(match.sessionIndex)
            }
            result.claims[t] = athleteClaims
        }

        result.unclaimedCandidates = candidateIndices.filter { !claimedIndices.contains($0) }
        return result
    }

    private static func bestMatch(
        in pool: [Int],
        sessions: [SessionExportDTO],
        team: TeamSessionExportDTO,
        proximityTolerance: TimeInterval
    ) -> TeamEntryMatch? {
        if let teamEnd = team.endTime, let match = pool.first(where: { sessions[$0].endTime == teamEnd }) {
            return .init(sessionIndex: match, tier: .exactEndTime)
        }
        if let match = pool.first(where: { sessions[$0].startTime == team.startTime }) {
            return .init(sessionIndex: match, tier: .exactStartTime)
        }
        let byProximity = pool
            .filter { sessions[$0].sets.count == team.sets.count }
            .map { ($0, abs(sessions[$0].startTime.timeIntervalSince(team.startTime))) }
            .filter { $0.1 <= proximityTolerance }
            .sorted { $0.1 < $1.1 }
        guard let closest = byProximity.first else { return nil }
        return .init(sessionIndex: closest.0, tier: .proximity)
    }

    // MARK: - Exercise library dedupe

    enum LibraryKey: Hashable {
        case linked(UUID)
        case unlinked(SchemaV3.Exercise.Category)
    }

    // MARK: - Plan (dry run)

    /// Runs the full import against a scratch in-memory container and discards it,
    /// returning only the `Summary`. This calls the exact same `apply` logic used for
    /// a real import, so the reported counts are guaranteed to match what a real
    /// import would produce — not a separate, hand-counted approximation that could
    /// drift out of sync with it.
    @MainActor
    static func plan(_ archive: Archive) throws -> Summary {
        let schema = Schema(SchemaV3.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return try apply(archive, into: container.mainContext)
    }

    // MARK: - Apply

    @discardableResult
    @MainActor
    static func apply(_ archive: Archive, into context: ModelContext) throws -> Summary {
        try guardEmpty(context)

        var summary = Summary()

        // MARK: Pass 0 — Athletes

        var athleteByUUID: [UUID: SchemaV3.Athlete] = [:]
        for dto in archive.athletes {
            let athlete = SchemaV3.Athlete(
                uuid: dto.uuid,
                name: dto.name,
                firstName: dto.firstName,
                lastName: dto.lastName,
                createdAt: dto.createdAt
            )
            context.insert(athlete)
            athleteByUUID[dto.uuid] = athlete
            summary.athletesImported += 1
        }

        // `ExerciseData.athlete` is non-optional while `SessionExportDTO.athleteID` is
        // optional, so every session needs a fallback owner. Prefer the earliest-
        // created real athlete; only synthesize one if the roster is empty.
        let fallbackOwner: SchemaV3.Athlete
        if let earliest = archive.athletes.min(by: { $0.createdAt < $1.createdAt }),
           let existing = athleteByUUID[earliest.uuid] {
            fallbackOwner = existing
        } else {
            // The frozen `SchemaV2.Athlete.defaultName` value, inlined — this importer
            // must not depend on that (V2-only, dropped-in-V3) static constant.
            let seeded = SchemaV3.Athlete(name: "Zach Wassynger")
            context.insert(seeded)
            fallbackOwner = seeded
            summary.athletesImported += 1
        }

        // MARK: Pass 1 — Exercise library

        var exerciseByKey: [LibraryKey: SchemaV3.Exercise] = [:]
        for dto in archive.exercises {
            guard let category = V2ToV3Conversion.category(for: dto.kind, name: dto.name) else {
                summary.exercisesSkippedUnknownKind += 1
                continue
            }
            let exercise = SchemaV3.Exercise(createdAt: dto.createdAt, category: category)
            context.insert(exercise)
            exerciseByKey[.linked(dto.uuid)] = exercise
            summary.exercisesImported += 1
        }

        // Single insertion point, mirroring `AthenaMigrationPlan.backfill`'s
        // `exercise(for:)`. `fallbackCategory` only matters for `.linked` keys whose
        // UUID is missing from `exercises.json` (unexpected, but not fatal) — an
        // `.unlinked` key already carries its own category.
        func exercise(for key: LibraryKey, fallbackCategory: @autoclosure () -> SchemaV3.Exercise.Category) -> SchemaV3.Exercise {
            if let existing = exerciseByKey[key] { return existing }
            let category: SchemaV3.Exercise.Category
            if case .unlinked(let unlinkedCategory) = key {
                category = unlinkedCategory
            } else {
                category = fallbackCategory()
            }
            let newExercise = SchemaV3.Exercise(category: category)
            context.insert(newExercise)
            exerciseByKey[key] = newExercise
            summary.exercisesImported += 1
            return newExercise
        }

        func libraryKey(for payload: SchemaV2.Routine.Exercise) -> LibraryKey {
            payload.exerciseID.map { .linked($0) } ?? .unlinked(V2ToV3Conversion.category(for: payload))
        }

        func libraryKey(for payload: SchemaV2.Session.Exercise) -> LibraryKey {
            payload.exerciseID.map { .linked($0) } ?? .unlinked(V2ToV3Conversion.category(for: payload))
        }

        // MARK: Pass 2 — Routines

        var routineByName: [String: SchemaV3.Routine] = [:]
        var duplicateRoutineNames: Set<String> = []
        let sortedRoutines = archive.routines.sorted {
            $0.createdAt != $1.createdAt ? $0.createdAt < $1.createdAt : $0.name < $1.name
        }
        for dto in sortedRoutines {
            if routineByName[dto.name] != nil {
                duplicateRoutineNames.insert(dto.name)
            }
            let v3Routine = SchemaV3.Routine(
                name: dto.name,
                superSets: dto.sets.map(V2ToV3Conversion.superSet),
                createdAt: dto.createdAt
            )
            context.insert(v3Routine)
            // First one wins for name-based session linking; the routine itself (and
            // its own data) is still fully imported regardless.
            if routineByName[dto.name] == nil {
                routineByName[dto.name] = v3Routine
            }
            summary.routinesImported += 1

            for (superSetIndex, set) in dto.sets.enumerated() {
                for (setIndex, payload) in set.exercises.enumerated() {
                    let key = libraryKey(for: payload)
                    let ex = exercise(for: key, fallbackCategory: V2ToV3Conversion.category(for: payload))
                    let routineData = SchemaV3.RoutineData(
                        exercise: ex,
                        routine: v3Routine,
                        position: .init(superSetIndex: superSetIndex, setIndex: setIndex),
                        expectedData: V2ToV3Conversion.expectedData(for: payload)
                    )
                    context.insert(routineData)
                    summary.routineDataRows += 1
                }
            }
        }
        summary.duplicateRoutineNames = duplicateRoutineNames.sorted()

        // MARK: Pass 3 — Team-entry matching

        let match = matchTeamEntries(sessions: archive.sessions, teamSessions: archive.teamSessions)
        var claimedSessionIndices: Set<Int> = []
        for athleteMap in match.claims.values {
            for entryMatch in athleteMap.values {
                claimedSessionIndices.insert(entryMatch.sessionIndex)
                summary.teamMatchesByTier[entryMatch.tier, default: 0] += 1
            }
        }
        summary.unmatchedEntryReferences = match.unmatchedEntryReferences.count
        summary.unclaimedTeamCandidates = match.unclaimedCandidates.count

        // MARK: Pass 4 — Solo sessions (never-team, plus unclaimed team candidates)

        func makeExerciseDataRows(
            for dto: SessionExportDTO,
            session: SchemaV3.Session,
            athlete: SchemaV3.Athlete
        ) {
            for (superSetIndex, set) in dto.sets.enumerated() {
                for (setIndex, payload) in set.exercises.enumerated() {
                    let key = libraryKey(for: payload)
                    let ex = exercise(for: key, fallbackCategory: V2ToV3Conversion.category(for: payload))
                    let row = SchemaV3.ExerciseData(
                        exercise: ex,
                        session: session,
                        athlete: athlete,
                        position: .init(superSetIndex: superSetIndex, setIndex: setIndex),
                        expectedData: V2ToV3Conversion.expectedData(for: V2ToV3Conversion.routinePayload(from: payload)),
                        actualData: V2ToV3Conversion.actualData(for: payload),
                        notes: V2ToV3Conversion.notes(for: payload)
                    )
                    context.insert(row)
                    summary.exerciseDataRows += 1
                }
            }
        }

        for i in archive.sessions.indices where !claimedSessionIndices.contains(i) {
            let dto = archive.sessions[i]
            let routine = dto.routineName.flatMap { routineByName[$0] }
            let athlete = dto.athleteID.flatMap { athleteByUUID[$0] } ?? fallbackOwner
            let v3Session = SchemaV3.Session(
                routine: routine,
                startTime: dto.startTime,
                endTime: dto.endTime,
                superSets: dto.sets.map(V2ToV3Conversion.superSet),
                notes: dto.notes,
                standoutSong: dto.standoutSong.map { .init(name: $0.name, artist: $0.artist) }
            )
            v3Session.athletes = [athlete]
            context.insert(v3Session)
            summary.soloSessionsImported += 1
            makeExerciseDataRows(for: dto, session: v3Session, athlete: athlete)
        }

        // MARK: Pass 5 — Team sessions

        for t in archive.teamSessions.indices {
            let dto = archive.teamSessions[t]
            let athleteMap = match.claims[t] ?? [:]
            let orderedEntries = athleteMap.sorted {
                (athleteByUUID[$0.key]?.name ?? "") < (athleteByUUID[$1.key]?.name ?? "")
            }

            var superSets = dto.sets.map(V2ToV3Conversion.superSet)
            for (_, entryMatch) in orderedEntries {
                let entryDTO = archive.sessions[entryMatch.sessionIndex]
                if entryDTO.sets.count > superSets.count {
                    for extraSet in entryDTO.sets[superSets.count...] {
                        superSets.append(V2ToV3Conversion.superSet(extraSet))
                    }
                }
            }

            var noteLines: [String] = dto.notes.isEmpty ? [] : [dto.notes]
            var athleteNoteLines: [String] = []
            for (athleteID, entryMatch) in orderedEntries {
                let entryDTO = archive.sessions[entryMatch.sessionIndex]
                guard !entryDTO.notes.isEmpty else { continue }
                let name = athleteByUUID[athleteID]?.name ?? "Unknown"
                athleteNoteLines.append("\(name): \(entryDTO.notes)")
            }
            if !noteLines.isEmpty && !athleteNoteLines.isEmpty {
                noteLines.append("")
            }
            noteLines.append(contentsOf: athleteNoteLines)

            let v3Session = SchemaV3.Session(
                routine: dto.routineName.flatMap { routineByName[$0] },
                startTime: dto.startTime,
                endTime: dto.endTime,
                superSets: superSets,
                notes: noteLines.joined(separator: "\n"),
                standoutSong: nil
            )
            // Dedupes against `fallbackOwner` standing in for more than one missing
            // `athleteID` (a claimed entry whose athlete was deleted after the fact) —
            // without this, the same fallback athlete could appear twice in `athletes`.
            var participatingAthletes: [SchemaV3.Athlete] = []
            var seenAthleteUUIDs: Set<UUID> = []
            for (athleteID, _) in orderedEntries {
                let athlete = athleteByUUID[athleteID] ?? fallbackOwner
                if seenAthleteUUIDs.insert(athlete.uuid).inserted {
                    participatingAthletes.append(athlete)
                }
            }
            v3Session.athletes = participatingAthletes
            context.insert(v3Session)
            summary.teamSessionsImported += 1

            for (athleteID, entryMatch) in orderedEntries {
                let entryDTO = archive.sessions[entryMatch.sessionIndex]
                let athlete = athleteByUUID[athleteID] ?? fallbackOwner
                makeExerciseDataRows(for: entryDTO, session: v3Session, athlete: athlete)
            }
        }

        try context.save()
        return summary
    }

    @MainActor
    private static func guardEmpty(_ context: ModelContext) throws {
        let counts = try [
            context.fetchCount(FetchDescriptor<SchemaV3.Athlete>()),
            context.fetchCount(FetchDescriptor<SchemaV3.Exercise>()),
            context.fetchCount(FetchDescriptor<SchemaV3.Routine>()),
            context.fetchCount(FetchDescriptor<SchemaV3.Session>()),
        ]
        guard counts.allSatisfy({ $0 == 0 }) else {
            throw ImportError.storeNotEmpty
        }
    }
}
