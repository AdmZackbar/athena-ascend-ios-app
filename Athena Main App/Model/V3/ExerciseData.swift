//
//  ExerciseData.swift
//  Athena
//
//  Created by Zach Wassynger on 9/24/26.
//

import SwiftData

typealias ExerciseData = SchemaV3.ExerciseData
typealias CampusSet = SchemaV3.ExerciseData.CampusSet
typealias CampusBoard = CampusSet.Board
typealias CampusMove = CampusSet.Move
typealias CampusRung = CampusSet.Rung

extension SchemaV3 {
    @Model
    final class ExerciseData {
        var exercise: Exercise! = nil
        var session: Session! = nil
        var athlete: Athlete! = nil
        var position: Position = Position(setIndex: 0)
        var expectedData: [DataSet] = []
        var actualData: [DataSet] = []
        var notes: String = ""
        
        init(exercise: Exercise,
             session: Session,
             athlete: Athlete,
             position: Position,
             expectedData: [DataSet] = [],
             actualData: [DataSet] = [],
             notes: String = "") {
            self.exercise = exercise
            self.session = session
            self.athlete = athlete
            self.position = position
            self.expectedData = expectedData
            self.actualData = actualData
            self.notes = notes
        }
        
        struct Position: Codable, Hashable {
            var superSetIndex: Int
            var setIndex: Int
            
            init(superSetIndex: Int = 0, setIndex: Int) {
                self.superSetIndex = superSetIndex
                self.setIndex = setIndex
            }
        }
        
        typealias DataSet = [Field : Value]
        
        enum Field: Codable, Hashable {
            case reps
            case repsAlt
            case time
            case timeAlt
            case weight
            case weightAlt
            case distance
            case distanceAlt
            case campus
            case campusAlt
            case notes
        }
        
        enum Value: Codable, Hashable {
            case number(_ v: Double)
            case discrete(_ v: Int)
            /// An inclusive rep/time range, e.g. an expected "8-12" prescription.
            /// `min == max` is represented as `.discrete` instead; this case is only
            /// used when the bounds actually differ.
            case range(min: Int, max: Int)
            case text(_ str: String)
            case campus(_ set: CampusSet)
        }
        
        struct CampusSet: Codable, Hashable {
            var board: Board
            /// All moves in the set
            var moves: [Move]
            /// If nil, regular tempo assumed. Otherwise, the set tempo should be used
            var tempo: Tempo?
            
            init(board: Board,
                 moves: [Move],
                 tempo: Tempo? = nil) {
                self.board = board
                self.moves = moves
                self.tempo = tempo
            }
            
            /// This struct's nested `Rung`/`Move`/`Side` must always be used here — never
            /// the global `Campus*` typealiases (lines 11-14). They point at these same
            /// `SchemaV3` types today, but a future schema version could repoint them —
            /// using the nested spelling here is what keeps this struct's own persisted
            /// shape from silently changing out from under it if that happens.
            struct Board: Codable, Hashable {
                /// The name of the holds/board setup
                /// e.g. large edges, sloper rungs, sloper balls, small edges
                var name: String
                /// The lowest rung of the board
                var startRung: Rung
                /// The highest rung of the board
                var endRung: Rung
                /// If the board has 'half' rungs
                var hasHalf: Bool
                
                init(name: String, startRung: Rung = .full(1), endRung: Rung = .full(10), hasHalf: Bool = true) {
                    self.name = name
                    self.startRung = startRung
                    self.endRung = endRung
                    self.hasHalf = hasHalf
                }
            }
            
            /// Describes a campus rung with an 'index'/number and if it is a 'half' rung or not
            struct Rung: Codable, Hashable {
                /// Creates a new rung at the specific number
                static func full(_ num: Int) -> Rung {
                    return .init(num: num)
                }
                
                /// Creates a new half rung at the specific number
                static func half(_ num: Int) -> Rung {
                    return .init(num: num, isHalf: true)
                }
                
                var num: Int
                var isHalf: Bool
                
                init(num: Int, isHalf: Bool = false) {
                    self.num = num
                    self.isHalf = isHalf
                }
                
                var text: String {
                    return isHalf ? "\(num)½" : "\(num)"
                }
            }
            
            /// Describes a move in a campus set
            /// e.g. B1 -> match on rung 1; R7 -> right hand to rung 7; L3.5 -> left hand to rung 3.5
            struct Move: Codable, Hashable {
                /// The rung of this move
                var rung: Rung
                /// The hand(s) to put on the rung
                var side: Side
                
                init(rung: Rung, side: Side) {
                    self.rung = rung
                    self.side = side
                }
                
                var text: String {
                    "\(side.abbreviation)\(rung.text)"
                }
            }
            
            enum Side: CaseIterable, Codable, Hashable {
                case both
                case left
                case right
                
                var abbreviation: String {
                    switch self {
                    case .both:
                        return "B"
                    case .left:
                        return "L"
                    case .right:
                        return "R"
                    }
                }
                
                var flipped: Side {
                    switch self {
                    case .both:
                        return .both
                    case .left:
                        return .right
                    case .right:
                        return .left
                    }
                }
            }
            
            enum Tempo: Codable, Hashable {
                case bpm(value: Int)
            }
        }
    }
}
