//
//  Schema.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/14/26.
//

import SwiftData

typealias CurrentSchema = SchemaV2

enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        .init(1, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [Routine.self]
    }
}

enum SchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        .init(2, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [Routine.self, Session.self, Exercise.self,
         GenericExercise.self, RepeaterExercise.self, MaxHangExercise.self, CampusLibraryExercise.self]
    }
}
