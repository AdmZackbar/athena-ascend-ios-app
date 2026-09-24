//
//  ModelExportDTOs.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/24/26.
//

import Foundation

/// Flat, `Codable` mirror of `Athlete` for JSON export via `DataExporter`.
struct AthleteExportDTO: Codable {
    var uuid: UUID
    var name: String
    var firstName: String?
    var lastName: String?
    var createdAt: Date
    var lastUsedAt: Date?

    init(_ athlete: Athlete) {
        uuid = athlete.uuid
        name = athlete.name
        firstName = athlete.firstName
        lastName = athlete.lastName
        createdAt = athlete.createdAt
        lastUsedAt = athlete.lastUsedAt
    }
}

/// Flat, `Codable` mirror of `Exercise` (and its four concrete subclasses) for JSON
/// export via `DataExporter`. `kind` carries whichever subclass's fields apply.
struct ExerciseExportDTO: Codable {
    var uuid: UUID
    var name: String
    var createdAt: Date
    var lastUsedAt: Date?
    var kind: Kind

    init(_ exercise: Exercise) {
        uuid = exercise.uuid
        name = exercise.name
        createdAt = exercise.createdAt
        lastUsedAt = exercise.lastUsedAt

        switch exercise {
        case let generic as GenericExercise:
            kind = .generic(dataType: generic.dataType, sideType: generic.sideType)
        case let repeater as RepeaterExercise:
            kind = .repeater(timeOn: repeater.timeOn, timeOff: repeater.timeOff)
        case let maxHang as MaxHangExercise:
            kind = .maxHang(isSingleArm: maxHang.isSingleArm)
        case let campus as CampusLibraryExercise:
            kind = .campus(campusType: campus.campusType)
        default:
            kind = .unknown
        }
    }

    enum Kind: Codable {
        case generic(dataType: Routine.GenericSets.DataType, sideType: Routine.SideType?)
        case repeater(timeOn: Int, timeOff: Int)
        case maxHang(isSingleArm: Bool)
        case campus(campusType: Routine.CampusSets.Exercise)
        /// Only possible if a future subclass is added without updating this DTO.
        case unknown
    }
}

/// Flat, `Codable` mirror of `Routine` for JSON export via `DataExporter`. `Routine`
/// has no stable ID field, so cross-references from `Session`/`TeamSession` exports
/// use `name`, matching the app's own `routineName` snapshot fallback pattern.
struct RoutineExportDTO: Codable {
    var name: String
    var sets: [Routine.ExerciseSet]
    var createdAt: Date
    var lastUsedAt: Date?

    init(_ routine: Routine) {
        name = routine.name
        sets = routine.sets
        createdAt = routine.createdAt
        lastUsedAt = routine.lastUsedAt
    }
}

/// Flat, `Codable` mirror of `Session` for JSON export via `DataExporter`.
struct SessionExportDTO: Codable {
    var athleteID: UUID?
    var routineName: String?
    var startTime: Date
    var endTime: Date?
    var sets: [Session.ExerciseSet]
    var notes: String
    var bodyWeight: Double
    var standoutSong: Session.Song?
    /// True if this session is one athlete's slice of a `TeamSession`.
    var isTeamSessionEntry: Bool

    init(_ session: Session) {
        athleteID = session.athlete?.uuid
        routineName = session.routine?.name ?? session.routineName
        startTime = session.startTime
        endTime = session.endTime
        sets = session.sets
        notes = session.notes
        bodyWeight = session.bodyWeight
        standoutSong = session.standoutSong
        isTeamSessionEntry = session.teamSession != nil
    }
}

/// Flat, `Codable` mirror of `TeamSession` for JSON export via `DataExporter`.
/// `entryAthleteIDs` cross-references the `athleteID` field of each corresponding
/// `SessionExportDTO`.
struct TeamSessionExportDTO: Codable {
    var routineName: String?
    var startTime: Date
    var endTime: Date?
    var notes: String
    var sets: [Session.ExerciseSet]
    var entryAthleteIDs: [UUID]

    init(_ teamSession: TeamSession) {
        routineName = teamSession.routine?.name ?? teamSession.routineName
        startTime = teamSession.startTime
        endTime = teamSession.endTime
        notes = teamSession.notes
        sets = teamSession.sets
        entryAthleteIDs = teamSession.entries.compactMap { $0.athlete?.uuid }
    }
}
