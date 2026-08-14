//
//  AthenaAscendApp.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/14/26.
//

import SwiftUI
import SwiftData

@main
struct AthenaAscendApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema(CurrentSchema.models)
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .modelContainer(sharedModelContainer)
    }
}

struct TestDataModifier: PreviewModifier {
    static func makeSharedContext() throws -> ModelContainer {
        let container = try ModelContainer(
            for: Schema(CurrentSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        populateContainer(container)
        return container
    }
    
    static func populateContainer(_ container: ModelContainer) {
        let routine: Routine = .init(name: "Spring 2026 Monday", sets: [
            .init(name: "Hangboard Block A", exercises: [
                .repeater(.init(tag: "10mm HC", numReps: 7)),
                .repeater(.init(tag: "10mm HC", numReps: 5, weight: 20.0)),
                .repeater(.init(tag: "MR S Pocket", numReps: 7, weight: -40.0)),
                .repeater(.init(tag: "MR S Pocket", numReps: 6, weight: -30.0)),
                .repeater(.init(tag: "MR S Pocket", numReps: 5, weight: -20.0)),
                .repeater(.init(tag: "M L Pocket", numReps: 7, timeOn: 5, timeOff: 5, weight: -60.0)),
                .repeater(.init(tag: "M L Pocket", numReps: 6, timeOn: 5, timeOff: 5, weight: -50.0)),
                .repeater(.init(tag: "M L Pocket", numReps: 5, timeOn: 5, timeOff: 5, weight: -40.0))
            ], restTime: 120),
            .init(name: "Max Hang Block B", exercises: [
                .maxHang(.init(tag: "BM Middle", side: .right, target: 10, weight: 35.0)),
                .maxHang(.init(tag: "BM Middle", side: .left, target: 10, weight: 35.0)),
                .maxHang(.init(tag: "BM Middle", side: .right, target: 6, weight: 40.0)),
                .maxHang(.init(tag: "BM Middle", side: .left, target: 6, weight: 40.0)),
            ])
        ])
        container.mainContext.insert(routine)
    }
    
    func body(content: Content, context: ModelContainer) -> some View {
        content.modelContainer(context)
    }
}
