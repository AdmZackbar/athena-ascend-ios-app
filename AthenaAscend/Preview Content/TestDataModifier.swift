//
//  TestDataModifier.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/14/26.
//

import SwiftData
import SwiftUI

/// Collection of sample data for use in previews
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
            .init(name: "Warmup Set", exercises: [
                .generic(.init(name: "Pancake Fold", dataType: .time, sets: [
                    .init(num: 5),
                ])),
                .generic(.init(name: "Ninja Kick", dataType: .time, sideType: .independent, sets: [
                    .init(num: 3),
                ])),
                .generic(.init(name: "Cossack Squats", dataType: .rep, sideType: .independent, sets: [
                    .init(num: 10),
                    .init(num: 10),
                    .init(num: 10),
                ])),
                .generic(.init(name: "Dumbbell Bench Press", sideType: .dependent, sets: [
                    .init(num: 10),
                    .init(num: 8),
                    .init(num: 6),
                ])),
                .generic(.init(name: "Curtsy Squat", sideType: .independent, sets: [
                    .init(min: 8, max: 12),
                    .init(min: 8, max: 12),
                    .init(min: 8, max: 12),
                ]))
            ], restTime: 10, order: .dfs),
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
                    .init(target: 10, targetAlt: 10, weight: 35.0, weightAlt: 40.0),
                    .init(target: 6, targetAlt: 6, weight: 40.0, weightAlt: 45.0),
                    .init(target: 6, targetAlt: 6, weight: 40.0, weightAlt: 45.0),
                ]))
            ], restTime: 180, order: .dfs),
            .init(name: "Warmup Campus", exercises: [
                .campus(.init(type: .basicLadder, sets: [
                    .init(moves: .defined([
                        .init(rung: .full(1), side: .both),
                        .init(rung: .full(3), side: .right),
                        .init(rung: .full(5), side: .left),
                        .init(rung: .full(7), side: .right),
                        .init(rung: .full(9), side: .left),
                        .init(rung: .full(9), side: .both),
                    ]))
                ]))
            ], restTime: 100, order: .dfs)
        ])
        let session = Session(startTime: .now.addingTimeInterval(-3600), endTime: .now, sets: routine.sets.map({ .init(base: $0) }), bodyWeight: 155, standoutSong: .init(name: "Permanent", artist: "A Day to Remember"))
        session.sets.indices.forEach({ setIndex in
            session.sets[setIndex].exercises.indices.forEach { exIndex in
                let newExercise: Session.Exercise = {
                    switch session.sets[setIndex].exercises[exIndex] {
                    case .generic(let d):
                        var actual: [Session.GenericDataSet] = []
                        for exSet in d.expected.sets {
                            actual.append(.init(numReps: Int.random(in: exSet.min...exSet.max), weight: Double(Int.random(in: 0...12) * 5)))
                        }
                        return .generic(.init(expected: d.expected, actual: actual))
                    case .repeater(let d):
                        var actual: [Session.RepeaterSet] = []
                        for exSet in d.expected.sets {
                            actual.append(.init(numReps: Int.random(in: (exSet.numReps - 2)...exSet.numReps), weight: Double(Int.random(in: -8...8) * 5)))
                        }
                        return .repeater(.init(expected: d.expected, actual: actual))
                    case .maxHang(let d):
                        var actual: [Session.MaxHangSet] = []
                        for exSet in d.expected.sets {
                            actual.append(.init(time: Int.random(in: exSet.target - 5...exSet.target), weight: Double(Int.random(in: 0...6) * 5)))
                        }
                        return .maxHang(.init(expected: d.expected, actual: actual))
                    case .campus(let d):
                        var actual: [Session.CampusSetPair] = []
                        // TODO
//                        for exSet in d.expected.sets {
//                            actual.append(.init(main: .init(moves: [.init(rung: .full(1), side: .both)])))
//                        }
                        return .campus(.init(expected: d.expected, actual: actual))
                    }
                }()
                session.sets[setIndex].exercises[exIndex] = newExercise
            }
        })
        routine.sessions.append(session)
        container.mainContext.insert(routine)
    }
    
    func body(content: Content, context: ModelContainer) -> some View {
        content.modelContainer(context)
    }
}

extension PreviewTrait where T == Preview.ViewTraits {
    static var sampleData: Self { .modifier(TestDataModifier()) }
}
