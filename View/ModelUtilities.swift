//
//  ModelUtilities.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/16/26.
//

import Foundation

extension Routine.Side {
    var abbreviation: String {
        switch self {
        case .left: return "L"
        case .right: return "R"
        case .both: return "B"
        }
    }
    
    var name: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        case .both: return "Both"
        }
    }
}

extension Routine.Exercise {
    var description: String {
        switch self {
        case .repeater(let r):
            if r.weight != 0 {
                return "\(r.tag) \(r.timeOn)s/\(r.timeOff)s x\(r.numReps) \(r.weight > 0 ? "+" : "")\(r.weight.formatted(.number.precision(.fractionLength(0...2))))lb"
            }
            return "\(r.tag) \(r.timeOn)s/\(r.timeOff)s x\(r.numReps)"
        case .maxHang(let m):
            if m.weight != 0 {
                return "\(m.tag) \(m.side.abbreviation) \(m.target)s \(m.weight > 0 ? "+" : "")\(m.weight.formatted(.number.precision(.fractionLength(0...2))))lb"
            }
            return "\(m.tag) \(m.side.abbreviation) \(m.target)s"
        }
    }
}
