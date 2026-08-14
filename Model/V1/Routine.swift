//
//  Routine.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/14/26.
//

import Foundation
import SwiftData

typealias Routine = SchemaV1.Routine

extension SchemaV1 {
    @Model
    final class Routine {
        /// The name of the routine
        var name: String = ""
        /// The list of sets to execute for the routine
        var sets: [ExerciseSet] = []
        
        init(name: String = "", sets: [ExerciseSet] = []) {
            self.name = name
            self.sets = sets
        }
        
        struct ExerciseSet: Codable, Hashable, Equatable {
            /// The name of the set
            var name: String
            /// The list of exercises to execute for the set
            var exercises: [Exercise]
            /// The amount of rest time between exercises in seconds
            var restTime: Int
            
            init(name: String = "", exercises: [Exercise] = [], restTime: Int = 180) {
                self.name = name
                self.exercises = exercises
                self.restTime = restTime
            }
        }
        
        enum Exercise: Codable, Equatable, Hashable {
            case repeater(_ details: Repeater)
            case maxHang(_ details: MaxHang)
        }
        
        struct Repeater: Codable, Hashable, Equatable {
            /// The name of the hold, grip type, etc.
            var tag: String
            /// The number of times on the hold
            var numReps: Int
            /// The amount of time per rep on the hold in seconds
            var timeOn: Int
            /// The amount of rest time between reps in seconds
            var timeOff: Int
            /// The amount of weight added or removed in pounds (negative is removed, positive is added)
            var weight: Double
            
            init(tag: String = "", numReps: Int = 6, timeOn: Int = 7, timeOff: Int = 3, weight: Double = 0.0) {
                self.tag = tag
                self.numReps = numReps
                self.timeOn = timeOn
                self.timeOff = timeOff
                self.weight = weight
            }
        }
        
        enum Side: Codable, Hashable, Equatable, CaseIterable {
            case left
            case right
            case both
        }
        
        struct MaxHang: Codable, Hashable, Equatable {
            /// The name of the hold, grip type, etc.
            var tag: String
            /// Which arm to hang from
            var side: Side
            /// The expected time on the hold in seconds
            var target: Int
            /// The amount of weight added or removed in pounds (negative is removed, positive is added)
            var weight: Double
            
            init(tag: String = "", side: Side = .both, target: Int = 10, weight: Double = 0.0) {
                self.tag = tag
                self.side = side
                self.target = target
                self.weight = weight
            }
        }
    }
}
