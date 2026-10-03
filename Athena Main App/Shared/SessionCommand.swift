//
//  SessionCommand.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/16/26.
//

import Foundation

/// A watch -> phone control command, applied to whichever SessionLiveView is on screen.
/// Equatable so SessionLiveView can observe SessionCommandCenter.pendingCommand via onChange.
nonisolated enum SessionCommand: Codable, Equatable {
    case toggleTimer
    case prev
    case next
    /// Sets a record-phase field to an absolute value (not a delta), so a dropped or
    /// coalesced message is harmless - whatever arrives last simply wins.
    case setRecordValue(key: ActiveSessionSnapshot.RecordField.Key, value: Double)
}
