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
                .repeater(.init(tag: "10mm HC", sets: [
                    .init(numReps: 7),
                    .init(numReps: 5, weight: 20.0),
                ])),
                .repeater(.init(tag: "MR S Pocket", sets: [
                    .init(numReps: 7, weight: -40.0),
                    .init(numReps: 6, weight: -30.0),
                    .init(numReps: 5, weight: -20.0),
                ])),
                .repeater(.init(tag: "M L Pocket", timeOn: 5, timeOff: 5, sets: [
                    .init(numReps: 7, weight: -60.0),
                    .init(numReps: 6, weight: -50.0),
                    .init(numReps: 5, weight: -40.0),
                ])),
            ], restTime: 120, order: .dfs),
            .init(name: "Max Hang Block B", exercises: [
                .maxHang(.init(tag: "BM Middle", sets: [
                    .init(side: .left, target: 10, weight: 35.0),
                    .init(side: .right, target: 10, weight: 40.0),
                    .init(side: .left, target: 6, weight: 40.0),
                    .init(side: .right, target: 6, weight: 45.0),
                    .init(side: .left, target: 6, weight: 40.0),
                    .init(side: .right, target: 6, weight: 45.0),
                ]))
            ], order: .dfs),
            .init(name: "Warmup Set", exercises: [
                .generic(.init(name: "Dumbbell Bench Press", sets: [
                    .init(num: 10),
                    .init(num: 8),
                    .init(num: 6),
                ])),
                .generic(.init(name: "Curtsy Squat", sets: [
                    .init(min: 8, max: 12),
                    .init(min: 8, max: 12),
                    .init(min: 8, max: 12),
                ]))
            ], restTime: 15, order: .bfs)
        ])
        container.mainContext.insert(routine)
    }
    
    func body(content: Content, context: ModelContainer) -> some View {
        content.modelContainer(context)
    }
}
