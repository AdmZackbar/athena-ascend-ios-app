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
}
