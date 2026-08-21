//
//  Session.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/17/26.
//

import Foundation
import SwiftData

typealias Session = SchemaV1.Session

extension SchemaV1 {
    @Model
    final class Session {
        var routine: Routine? = nil
        var startTime: Date = Date()
        var endTime: Date? = nil
        var sets: [ExerciseSet] = []
        var notes: String = ""
        var bodyWeight: Double = 160
        var standoutSong: Song? = nil
        
        init(startTime: Date = .now, endTime: Date? = nil, sets: [ExerciseSet] = [], notes: String = "", bodyWeight: Double = 160, standoutSong: Song? = nil) {
            self.startTime = startTime
            self.endTime = endTime
            self.sets = sets
            self.notes = notes
            self.bodyWeight = bodyWeight
            self.standoutSong = standoutSong
        }
        
        struct ExerciseSet: Codable, Hashable, Equatable {
            /// The name of the set
            var name: String
            /// The list of exercises to execute for the set
            var exercises: [Exercise]
            /// The amount of rest time between exercises in seconds
            var restTime: Int
            /// The ordering of exercises and their sets
            /// * BFS: one set from each exercise before moving to the next set in each exercise
            /// * DFS: all sets from the first exercise before moving to the next exercise
            var order: Routine.Order
            
            init(base: Routine.ExerciseSet) {
                self.name = base.name
                self.exercises = base.exercises.map(ExerciseSet.toSessionExercise)
                self.restTime = base.restTime
                self.order = base.order
            }
            
            static func toSessionExercise(_ exercise: Routine.Exercise) -> Exercise {
                switch exercise {
                case .generic(let d):
                    return .generic(.init(expected: d))
                case .repeater(let d):
                    return .repeater(.init(expected: d))
                case .maxHang(let d):
                    return .maxHang(.init(expected: d))
                }
            }
        }
        
        enum Exercise: Codable, Hashable, Equatable {
            case generic(_ data: GenericData)
            case repeater(_ data: RepeaterData)
            case maxHang(_ data: MaxHangData)
        }
        
        struct GenericData: Codable, Hashable, Equatable {
            var expected: Routine.GenericSets
            var actual: [GenericDataSet]
            var notes: String
            
            init(expected: Routine.GenericSets, actual: [GenericDataSet] = [], notes: String = "") {
                self.expected = expected
                self.actual = actual
                self.notes = notes
            }
        }
        
        struct GenericDataSet: Codable, Hashable, Equatable {
            /// The number of reps in the set
            /// If numRepsAlt is nil, used for both sides (if applicable)
            /// If numRepsAlt is not nil, used for the left side
            var numReps: Int?
            /// If not nil, used to store a different number of reps for the right side
            var numRepsAlt: Int?
            /// The amount of time on
            var time: Int?
            /// See explanation in numReps for alt usage
            var timeAlt: Int?
            /// The amount of weight used in the set
            var weight: Double?
            /// See explanation in numReps for alt usage
            var weightAlt: Double?
            /// Any additional details about the set
            var notes: String
            
            init(numReps: Int? = nil, numRepsAlt: Int? = nil, time: Int? = nil, timeAlt: Int? = nil, weight: Double? = nil, weightAlt: Double? = nil, notes: String = "") {
                self.numReps = numReps
                self.numRepsAlt = numRepsAlt
                self.time = time
                self.timeAlt = timeAlt
                self.weight = weight
                self.weightAlt = weightAlt
                self.notes = notes
            }
        }
        
        struct RepeaterData: Codable, Hashable, Equatable {
            var expected: Routine.RepeaterSets
            var actual: [RepeaterSet]
            var notes: String
            
            init(expected: Routine.RepeaterSets, actual: [RepeaterSet] = [], notes: String = "") {
                self.expected = expected
                self.actual = actual
                self.notes = notes
            }
        }
        
        struct RepeaterSet: Codable, Hashable, Equatable {
            /// The number of times on the hold
            var numReps: Int
            /// The amount of weight added or removed in pounds (negative is removed, positive is added)
            var weight: Double
            /// Any additional notes or comments about the set
            var notes: String
            
            init(numReps: Int = 6, weight: Double = 0.0, notes: String = "") {
                self.numReps = numReps
                self.weight = weight
                self.notes = notes
            }
        }
        
        struct MaxHangData: Codable, Hashable, Equatable {
            var expected: Routine.MaxHangSets
            var actual: [MaxHangSet]
            var notes: String
            
            init(expected: Routine.MaxHangSets, actual: [MaxHangSet] = [], notes: String = "") {
                self.expected = expected
                self.actual = actual
                self.notes = notes
            }
        }
        
        struct MaxHangSet: Codable, Hashable, Equatable {
            /// The arm used for this set
            var side: Routine.Side
            /// The expected time on the hold in seconds
            var target: Int
            /// The amount of weight added or removed in pounds (negative is removed, positive is added)
            var weight: Double
            /// Any additional notes or comments about the set
            var notes: String
            
            init(side: Routine.Side, target: Int = 10, weight: Double = 0.0, notes: String = "") {
                self.side = side
                self.target = target
                self.weight = weight
                self.notes = notes
            }
        }
        
        struct Song: Codable, Hashable, Equatable {
            var name: String
            var artist: String
            
            init(name: String = "", artist: String = "") {
                self.name = name
                self.artist = artist
            }
        }
    }
}
