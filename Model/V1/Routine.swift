//
//  Routine.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/14/26.
//

import Foundation
import SwiftData

typealias Routine = SchemaV1.Routine
typealias CampusExercise = Routine.CampusSets.Exercise

extension SchemaV1 {
    @Model
    final class Routine {
        /// The name of the routine
        var name: String = ""
        /// The list of sets to execute for the routine
        var sets: [ExerciseSet] = []
        @Relationship(deleteRule: .nullify, inverse: \Session.routine)
        var sessions: [Session]! = []
        
        init(name: String = "", sets: [ExerciseSet] = [], sessions: [Session] = []) {
            self.name = name
            self.sets = sets
            self.sessions = sessions
        }
        
        enum Order: CaseIterable, Codable, Hashable, Equatable {
            case bfs, dfs
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
            var order: Order
            
            init(name: String = "", exercises: [Exercise] = [], restTime: Int = 0, order: Order = .bfs) {
                self.name = name
                self.exercises = exercises
                self.restTime = restTime
                self.order = order
            }
        }
        
        enum Exercise: Codable, Equatable, Hashable {
            case generic(_ data: GenericSets)
            case repeater(_ data: RepeaterSets)
            case maxHang(_ data: MaxHangSets)
            case campus(_ data: CampusSets)
        }
        
        struct GenericSets: Codable, Hashable, Equatable {
            /// The name of the exercise
            var name: String
            /// The data type(s) contained in the sets
            var dataType: DataType
            /// If nil, there is no sided-ness to the exercise: e.g. plank, barbell bench press
            var sideType: SideType?
            /// The sets of the exercise in order
            var sets: [GenericSet]
            
            init(name: String = "", dataType: DataType = .repWeight, sideType: SideType? = nil, sets: [GenericSet] = []) {
                self.name = name
                self.dataType = dataType
                self.sideType = sideType
                self.sets = sets
            }
            
            /// Denotes what data types are stored in the data sets
            enum DataType: CaseIterable, Codable, Hashable, Equatable {
                case rep
                case repWeight
                case time
                case timeWeight
            }
        }
        
        struct GenericSet: Codable, Hashable, Equatable {
            /// The lower value of the rep/time range, inclusive
            var min: Int
            /// The upper value of the rep/time range, inclusive
            var max: Int
            
            init(num: Int = 1) {
                self.min = num
                self.max = num
            }
            
            init(min: Int, max: Int) {
                self.min = min
                self.max = max
            }
        }
        
        struct RepeaterSets: Codable, Hashable, Equatable {
            /// The name of the hold, grip type, etc.
            var tag: String
            /// The amount of time per rep on the hold in seconds
            var timeOn: Int
            /// The amount of rest time between reps in seconds
            var timeOff: Int
            /// The repeater sets in order
            var sets: [RepeaterSet] = []
            
            init(tag: String = "", timeOn: Int = 7, timeOff: Int = 3, sets: [RepeaterSet] = []) {
                self.tag = tag
                self.timeOn = timeOn
                self.timeOff = timeOff
                self.sets = sets
            }
        }
        
        struct RepeaterSet: Codable, Hashable, Equatable {
            /// The number of times on the hold
            var numReps: Int
            /// The amount of weight added or removed in pounds (negative is removed, positive is added)
            var weight: Double
            
            init(numReps: Int = 6, weight: Double = 0.0) {
                self.numReps = numReps
                self.weight = weight
            }
        }
        
        /// Denotes usage of weight/time/reps w/r left/right side
        enum SideType: CaseIterable, Codable, Hashable, Equatable {
            /// Two weights/reps/time are used for both sides, but always are the same anount
            /// e.g. dumbbell bench press, lateral-to-front raise
            case dependent
            /// Two weights/reps/time are used, and the amounts can differ
            /// e.g. 1-arm row, ninja kick hold, hip abductor
            case independent
        }
        
        struct MaxHangSets: Codable, Hashable, Equatable {
            /// The name of the hold, grip type, etc.
            var tag: String
            /// The arm usage for each set
            /// If true, different weights/reps can be used for each side
            /// If false, both arms are used for a single set with a single pair of time/weight
            var isSingleArm: Bool
            /// The sets for each side in order
            var sets: [MaxHangSet]
            
            init(tag: String = "", isSingleArm: Bool = true, sets: [MaxHangSet] = []) {
                self.tag = tag
                self.isSingleArm = isSingleArm
                self.sets = sets
            }
        }
        
        struct MaxHangSet: Codable, Hashable, Equatable {
            /// The expected time on the hold in seconds
            /// If not single arm, this is the sole value used. Otherwise, this is used for the left arm
            var target: Int
            /// Same as above but for the right arm (if present)
            var targetAlt: Int?
            /// The amount of weight added or removed in pounds (negative is removed, positive is added)
            var weight: Double
            /// See explanation for targetAlt
            var weightAlt: Double?
            
            init(target: Int = 10, targetAlt: Int? = nil, weight: Double = 0.0, weightAlt: Double? = nil) {
                self.target = target
                self.targetAlt = targetAlt
                self.weight = weight
                self.weightAlt = weightAlt
            }
        }
        
        struct CampusSets: Codable, Hashable, Equatable {
            /// The types of sets contained here
            var type: Exercise
            /// All the planned sets
            var sets: [PlannedSet]
            
            init(type: Exercise = .maxLadder, sets: [PlannedSet] = []) {
                self.type = type
                self.sets = sets
            }
            
            /// Describes the type of campus exercise
            enum Exercise: CaseIterable, Codable, Hashable, Equatable {
                /// Starting from a match, move up 1 rung at a time, alternating hands, matching only at the finish
                /// e.g. B1-L3-R5-L7-R9-B9
                case basicLadder
                /// Starting from a match, move up 1 rung as far as possible, repeat on the other hand, then match the same rung
                /// e.g. B1-R5-L9-B9
                case maxLadder
                /// Single move of the max ladder, then match the rung (or pull slightly higher)
                /// e.g. B1-R6-B6
                case maxFirst
                /// Same first move of the max first, then continue to bump the same hand
                /// e.g. B1-R6-R6.5-R7
                case bumps
                /// Starting from match, move up as if to latch, but only touch before slowly dropping back to the match.
                /// e.g. B1-R4-B1-L4-B1
                case touches
                /// Only double dynos, usually going up. Both hands go/grab at the same time.
                /// e.g. B1-B3-B5-B7
                case doubles
                /// Same as doubles, but the initial move is down followed up by an explosive upward move.
                /// e.g. B3-B2-B4
                case downUps
                
                /// If true, the set should be done twice - one for each side (with mirrored grip positions on each rung)
                var shouldMirror: Bool {
                    switch self {
                    case .basicLadder, .maxLadder, .maxFirst, .bumps, .touches:
                        return true
                    case .doubles, .downUps:
                        return false
                    }
                }
            }
            
            struct PlannedSet: Codable, Hashable, Equatable {
                var board: CampusBoard
                var moves: Moves
                var doMirror: Bool
                
                init(board: CampusBoard = .largeEdges, moves: Moves, doMirror: Bool = true) {
                    self.board = board
                    self.moves = moves
                    self.doMirror = doMirror
                }
                
                enum Moves: Codable, Hashable, Equatable {
                    case defined(_ moves: [CampusMove])
                    case baseline(_ offsets: [Int])
                    case progressive
                }
            }
        }
    }
}
