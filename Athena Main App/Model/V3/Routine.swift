//
//  Routine.swift
//  Athena
//
//  Created by Zach Wassynger on 9/24/26.
//

import Foundation
import SwiftData

typealias Routine = SchemaV3.Routine

extension SchemaV3 {
    @Model
    final class Routine: Hashable {
        /// The name of the routine
        var name: String = ""
        /// All super sets details (links to data)
        var superSets: [SuperSet] = []
        /// No point in keeping expected data if the routine is deleted
        @Relationship(deleteRule: .cascade, inverse: \RoutineData.routine)
        var data: [RoutineData]! = []
        /// We do want to keep sessions if the routine is deleted
        @Relationship(deleteRule: .nullify, inverse: \Session.routine)
        var sessions: [Session]! = []
        var createdAt: Date = Date()

        init(name: String = "",
             superSets: [SuperSet] = [],
             sessions: [Session] = [],
             createdAt: Date = .now) {
            self.name = name
            self.superSets = superSets
            self.sessions = sessions
            self.createdAt = createdAt
        }
        
        struct SuperSet: Codable, Hashable {
            /// The name of the super set
            var name: String
            /// The amount of rest time between sets within this super set
            var restTime: Int
            /// How to traverse between exercises and sets of the exercises
            var order: Order
            
            init(name: String, restTime: Int = 0, order: Order = .bfs) {
                self.name = name
                self.restTime = restTime
                self.order = order
            }
            
            enum Order: CaseIterable, Codable, Hashable, Equatable {
                case bfs, dfs
            }
        }
    }
}
