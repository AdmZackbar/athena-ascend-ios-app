//
//  Schema.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/14/26.
//

import SwiftData

typealias CurrentSchema = SchemaV3

enum SchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        .init(3, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [Athlete.self, Routine.self, RoutineData.self, Session.self, Exercise.self, ExerciseData.self]
    }
}
