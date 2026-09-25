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
        let context = container.mainContext
        let date = Date.now.addingTimeInterval(-7200)
        // Routine
        let routine = Routine(name: "Spring 2026 Monday", superSets: [
            .init(name: "Warmup Set", restTime: 0, order: .bfs),
            .init(name: "Hangboard Block A", restTime: 120, order: .dfs),
            .init(name: "Max Hang Block B", restTime: 180, order: .dfs),
            .init(name: "Warmup Campus", restTime: 100, order: .dfs),
        ], createdAt: date)
        routine.data = [
            .init(exercise: .init(category: .generic(name: "Pancake Fold", dataTypes: [.time], sideType: .none)),
                  routine: routine,
                  position: .init(setIndex: 0),
                  expectedData: [[.time: .discrete(45)]]),
            .init(exercise: .init(category: .generic(name: "Ninja Kick", dataTypes: [.time], sideType: .independent)),
                  routine: routine,
                  position: .init(setIndex: 1),
                  expectedData: [[.time: .discrete(30)]]),
            .init(exercise: .init(category: .generic(name: "Cossack Squats", dataTypes: [.reps], sideType: .none)),
                  routine: routine,
                  position: .init(setIndex: 2),
                  expectedData: [
                    [.reps: .discrete(10)],
                    [.reps: .discrete(10)],
                    [.reps: .discrete(10)],
                  ]),
            .init(exercise: .init(category: .generic(name: "Dumbbell Bench Press", dataTypes: [.reps, .weight], sideType: .dependent)),
                  routine: routine,
                  position: .init(setIndex: 3),
                  expectedData: [
                    [.reps: .discrete(10), .weight: .number(35)],
                    [.reps: .discrete(8), .weight: .number(40)],
                    [.reps: .discrete(6), .weight: .number(45)],
                  ]),
            .init(exercise: .init(category: .generic(name: "Curtsy Squat", dataTypes: [.reps, .weight], sideType: .independent)),
                  routine: routine,
                  position: .init(setIndex: 4),
                  expectedData: [
                    [.reps: .range(min: 8, max: 12)],
                    [.reps: .range(min: 8, max: 12)],
                    [.reps: .range(min: 8, max: 12)],
                  ]),
            .init(exercise: .init(category: .repeater(tag: "10mm HC", timeOn: 7, timeOff: 3)),
                  routine: routine,
                  position: .init(superSetIndex: 1, setIndex: 0),
                  expectedData: [
                    [.reps: .discrete(7), .weight: .number(0)],
                    [.reps: .discrete(5), .weight: .number(20)],
                  ]),
            .init(exercise: .init(category: .repeater(tag: "MR S Pocket", timeOn: 7, timeOff: 3)),
                  routine: routine,
                  position: .init(superSetIndex: 1, setIndex: 1),
                  expectedData: [
                    [.reps: .discrete(7), .weight: .number(-40)],
                    [.reps: .discrete(6), .weight: .number(-30)],
                    [.reps: .discrete(5), .weight: .number(-20)],
                  ]),
            .init(exercise: .init(category: .repeater(tag: "M L Pocket", timeOn: 5, timeOff: 5)),
                  routine: routine,
                  position: .init(superSetIndex: 1, setIndex: 2),
                  expectedData: [
                    [.reps: .discrete(7), .weight: .number(-60)],
                    [.reps: .discrete(6), .weight: .number(-50)],
                    [.reps: .discrete(5), .weight: .number(-40)],
                  ]),
            .init(exercise: .init(category: .maxHang(tag: "BM Middle", sideType: .independent)),
                  routine: routine,
                  position: .init(superSetIndex: 2, setIndex: 0),
                  expectedData: [
                    [.time: .discrete(10), .weight: .number(35), .weightAlt: .number(40)],
                    [.time: .discrete(6), .weight: .number(40), .weightAlt: .number(45)],
                    [.time: .discrete(6), .weight: .number(45)],
                  ]),
            .init(exercise: .init(category: .campus(name: "Basic Ladder", mirrorSets: true)),
                  routine: routine,
                  position: .init(superSetIndex: 3, setIndex: 0),
                  expectedData: [
                    [.campus: .campus(.init(board: .largeEdges, moves: [
                        .init(rung: .full(1), side: .both),
                        .init(rung: .full(3), side: .right),
                        .init(rung: .full(5), side: .left),
                        .init(rung: .full(7), side: .right),
                        .init(rung: .full(9), side: .left),
                        .init(rung: .full(9), side: .both),
                    ]))]
                  ])
        ]
        context.insert(routine)

        // Solo session
        let zach = Athlete(name: "Zach", firstName: "Zach", lastName: "Wassynger", createdAt: date)
        let session = Session(routine: routine,
                              startTime: date.addingTimeInterval(3600),
                              endTime: .now,
                              superSets: routine.superSets,
                              standoutSong: .init(name: "Permanent", artist: "A Day to Remember"))
        session.data = routine.data.map { createActualData(session: session, athlete: zach, routineData: $0) }
        context.insert(session)
        
        // Team session
        let linsay = Athlete(name: "Linsay", createdAt: date.addingTimeInterval(60))
        let allie = Athlete(name: "Allie", createdAt: date.addingTimeInterval(120))
        // TODO
    }
    
    static func createActualData(session: Session, athlete: Athlete, routineData: RoutineData) -> ExerciseData {
        .init(exercise: routineData.exercise,
              session: session,
              athlete: athlete,
              position: routineData.position,
              expectedData: routineData.expectedData,
              actualData: routineData.expectedData.map { createActualData(exercise: routineData.exercise, expected: $0) }
        )
    }
    
    static func createActualData(exercise: Exercise, expected: ExerciseData.DataSet) -> ExerciseData.DataSet {
        var actual: ExerciseData.DataSet = .init()
        switch exercise.category {
        case .generic(_, let dataTypes, _):
            for dataType in dataTypes {
                switch dataType {
                case .reps:
                    actual[.reps] = expected[.reps, default: .discrete(8)] + Int.random(in: -3...3)
                case .time:
                    actual[.time] = expected[.time, default: .discrete(30)] + Int.random(in: -10...10)
                case .weight:
                    actual[.weight] = expected[.weight, default: .number(40)] + (Int.random(in: -3...3) * 5)
                case .distance:
                    actual[.distance] = expected[.distance, default: .discrete(24)]
                }
                // TODO use side type to fill in alt sometimes
            }
        case .repeater(_, _, _):
            actual[.reps] = expected[.reps, default: .discrete(7)]
            actual[.weight] = expected[.weight, default: .number(0)]
        case .maxHang(_, _):
            actual[.time] = expected[.time, default: .discrete(10)] + Int.random(in: -5...1)
            actual[.weight] = expected[.weight, default: .number(30)]
        case .campus(_, _):
            // TODO add variance
            actual[.campus] = expected[.campus]
        }
        return actual
    }

    func body(content: Content, context: ModelContainer) -> some View {
        content.modelContainer(context)
    }
}

extension ExerciseData.Value {
    static func + (lhs: ExerciseData.Value, rhs: Int) -> ExerciseData.Value {
        switch lhs {
        case .discrete(let v):
            return .discrete(v + rhs)
        case .number(let v):
            return .number(v + Double(rhs))
        case .range(let min, let max):
            return .discrete(min + ((max - min) / 2) + rhs)
        default:
            // TODO
            return lhs
        }
    }
}

extension PreviewTrait where T == Preview.ViewTraits {
    static var sampleData: Self { .modifier(TestDataModifier()) }
}
