//
//  ModelUtilities.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/16/26.
//

extension Routine.Order {
    var name: String {
        switch self {
        case .series: return "Series"
        case .parallel: return "Parallel"
        }
    }
}

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
