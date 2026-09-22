//
//  Exercise.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/21/26.
//

import Foundation
import SwiftData

typealias Exercise = SchemaV2.Exercise
typealias GenericExercise = SchemaV2.GenericExercise
typealias RepeaterExercise = SchemaV2.RepeaterExercise
typealias MaxHangExercise = SchemaV2.MaxHangExercise
typealias CampusLibraryExercise = SchemaV2.CampusLibraryExercise

extension SchemaV2 {
    /// A reusable exercise library entry. Never instantiated directly — always one of
    /// the concrete subclasses below, matching `Routine.Exercise`'s four cases.
    @Model
    class Exercise {
        /// Stable link target for `exerciseID` on the routine/session payloads.
        var uuid: UUID = UUID()
        /// Display name: `name` for generic, `tag` for repeater/max hang,
        /// `campusType.text` for campus.
        var name: String = ""
        var createdAt: Date = Date()
        var lastUsedAt: Date? = nil

        init(name: String = "", createdAt: Date = .now, lastUsedAt: Date? = nil) {
            self.name = name
            self.createdAt = createdAt
            self.lastUsedAt = lastUsedAt
        }

        /// Dedupe key. Never called on the base — overridden by every subclass.
        var identity: ExerciseIdentity {
            fatalError("Exercise.identity must be overridden by a subclass")
        }
    }

    @available(iOS 26, *)
    @Model
    final class GenericExercise: Exercise {
        var dataType: Routine.GenericSets.DataType = Routine.GenericSets.DataType.repWeight
        /// Genuinely optional: nil means "not sided" (e.g. plank, barbell bench press).
        var sideType: Routine.SideType? = nil

        init(name: String = "", dataType: Routine.GenericSets.DataType = .repWeight, sideType: Routine.SideType? = nil, createdAt: Date = .now, lastUsedAt: Date? = nil) {
            self.dataType = dataType
            self.sideType = sideType
            super.init(name: name, createdAt: createdAt, lastUsedAt: lastUsedAt)
        }

        override var identity: ExerciseIdentity {
            .generic(name: name, dataType: dataType, sideType: sideType)
        }
    }

    @available(iOS 26, *)
    @Model
    final class RepeaterExercise: Exercise {
        var timeOn: Int = 7
        var timeOff: Int = 3

        init(name: String = "", timeOn: Int = 7, timeOff: Int = 3, createdAt: Date = .now, lastUsedAt: Date? = nil) {
            self.timeOn = timeOn
            self.timeOff = timeOff
            super.init(name: name, createdAt: createdAt, lastUsedAt: lastUsedAt)
        }

        override var identity: ExerciseIdentity {
            .repeater(tag: name, timeOn: timeOn, timeOff: timeOff)
        }
    }

    @available(iOS 26, *)
    @Model
    final class MaxHangExercise: Exercise {
        var isSingleArm: Bool = true

        init(name: String = "", isSingleArm: Bool = true, createdAt: Date = .now, lastUsedAt: Date? = nil) {
            self.isSingleArm = isSingleArm
            super.init(name: name, createdAt: createdAt, lastUsedAt: lastUsedAt)
        }

        override var identity: ExerciseIdentity {
            .maxHang(tag: name, isSingleArm: isSingleArm)
        }
    }

    @available(iOS 26, *)
    @Model
    final class CampusLibraryExercise: Exercise {
        var campusType: Routine.CampusSets.Exercise = Routine.CampusSets.Exercise.maxLadder

        init(name: String = "", campusType: Routine.CampusSets.Exercise = .maxLadder, createdAt: Date = .now, lastUsedAt: Date? = nil) {
            self.campusType = campusType
            super.init(name: name, createdAt: createdAt, lastUsedAt: lastUsedAt)
        }

        override var identity: ExerciseIdentity {
            .campus(campusType)
        }
    }
}
