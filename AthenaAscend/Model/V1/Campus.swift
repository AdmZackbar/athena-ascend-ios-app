//
//  Campus.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/25/26.
//

typealias CampusSet = SchemaV1.CampusSet
typealias CampusBoard = CampusSet.Board
typealias CampusMove = CampusSet.Move
typealias CampusRung = CampusSet.Rung

extension SchemaV1 {
    /// A set of moves on a campus board
    struct CampusSet: Codable, Hashable, Equatable {
        var board: Board
        /// All moves in the set
        var moves: [Move]
        /// If nil, regular tempo assumed. Otherwise, the set tempo should be used
        var tempo: Tempo?
        /// Any additional details about this set
        var notes: String
        
        init(board: Board = .largeEdges, moves: [Move] = [], tempo: Tempo? = nil, notes: String = "") {
            self.board = board
            self.moves = moves
            self.tempo = tempo
            self.notes = notes
        }
        
        struct Board: Codable, Hashable, Equatable {
            /// The name of the holds/board setup
            /// e.g. large edges, sloper rungs, sloper balls, small edges
            var name: String
            /// The lowest rung of the board
            var startRung: CampusRung
            /// The highest rung of the board
            var endRung: CampusRung
            /// If the board has 'half' rungs
            var hasHalf: Bool
            
            init(name: String, startRung: CampusRung = .full(1), endRung: CampusRung = .full(10), hasHalf: Bool = true) {
                self.name = name
                self.startRung = startRung
                self.endRung = endRung
                self.hasHalf = hasHalf
            }
        }
        
        /// Describes a campus rung with an 'index'/number and if it is a 'half' rung or not
        struct Rung: Codable, Hashable, Equatable {
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
        struct Move: Codable, Hashable, Equatable {
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
        
        enum Side: CaseIterable, Codable, Hashable, Equatable {
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
        
        enum Tempo: Codable, Hashable, Equatable {
            case bpm(value: Int)
        }
    }
}
