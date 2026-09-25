//
//  Exercise.swift
//  Athena
//
//  Created by Zach Wassynger on 9/24/26.
//

import Foundation
import SwiftData

extension SchemaV3 {
    @Model
    final class Exercise {
        var createdAt: Date = Date()
        var category: Category = Category.generic(name: "", dataTypes: [.reps], sideType: .none)
        var notes: String = ""
        /// No point in keeping exercise data for a deleted exercise
        @Relationship(deleteRule: .cascade, inverse: \ExerciseData.exercise)
        var data: [ExerciseData]! = []
        /// No point in keeping routine data for a deleted exercise
        @Relationship(deleteRule: .cascade, inverse: \RoutineData.exercise)
        var routineData: [RoutineData]! = []
        
        var name: String {
            switch category {
            case .generic(let name, _, _):
                return name
            case .repeater(let tag, let timeOn, let timeOff):
                return "\(tag) \(timeOn)s/\(timeOff)s"
            case .maxHang(let tag, let sideType):
                return sideType == .none ? "\(tag) [L+R]" : "\(tag) [L/R]"
            case .campus(let name, _):
                return name
            }
        }

        init(createdAt: Date = .now,
             category: Category,
             notes: String = "") {
            self.createdAt = createdAt
            self.category = category
            self.notes = notes
        }
        
        enum Category: Codable, Hashable {
            case generic(name: String, dataTypes: [DataType], sideType: SideType)
            case repeater(tag: String, timeOn: Int, timeOff: Int)
            case maxHang(tag: String, sideType: SideType)
            case campus(name: String, mirrorSets: Bool)
        }
        
        enum DataType: CaseIterable, Codable, Hashable {
            case reps
            case time
            case weight
            case distance
        }
        
        /// Denotes usage of weight/time/reps w/r left/right side
        enum SideType: CaseIterable, Codable, Hashable {
            /// Side-less exercise: only one value is used
            /// e.g. barbell bench press, plank
            case none
            /// Two weights/reps/time are used for both sides, but always are the same anount
            /// e.g. dumbbell bench press, lateral-to-front raise
            case dependent
            /// Two weights/reps/time are used, and the amounts can differ
            /// e.g. 1-arm row, ninja kick hold, hip abductor
            case independent
        }
    }
}
