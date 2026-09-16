//
//  AthenaAscendWatchApp.swift
//  AthenaAscendWatch Watch App
//
//  Created by Zach Wassynger on 9/16/26.
//

import SwiftUI

@main
struct AthenaAscendWatch_Watch_AppApp: App {
    init() {
        // Start the WCSession handshake as early as possible, rather than waiting for
        // ContentView to appear.
        _ = SessionConnectivity.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
