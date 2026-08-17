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
        var exercises: [Exercise] = []
        var notes: String = ""
        
        init(startTime: Date = .now, endTime: Date? = nil, exercises: [Exercise] = [], notes: String = "") {
            self.startTime = startTime
            self.endTime = endTime
            self.exercises = exercises
            self.notes = notes
        }
        
        enum Exercise: Codable, Hashable, Equatable {
            case repeater(details: Repeater)
            case maxHang(details: MaxHang)
        }
        
        struct Repeater: Codable, Hashable, Equatable {
            var expected: Routine.Repeater
            var actual: Routine.Repeater
            var notes: String
            
            init(expected: Routine.Repeater, actual: Routine.Repeater, notes: String = "") {
                self.expected = expected
                self.actual = actual
                self.notes = notes
            }
        }
        
        struct MaxHang: Codable, Hashable, Equatable {
            var expected: Routine.MaxHang
            var actual: Routine.MaxHang
            var notes: String
            
            init(expected: Routine.MaxHang, actual: Routine.MaxHang, notes: String = "") {
                self.expected = expected
                self.actual = actual
                self.notes = notes
            }
        }
    }
}
