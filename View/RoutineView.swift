//
//  RoutineView.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/14/26.
//

import SwiftData
import SwiftUI

struct RoutineView: View {
    @EnvironmentObject private var navigationStore: NavigationStore
    
    let routine: Routine
    
    var body: some View {
        Form {
            ForEach(routine.sets, id: \.hashValue) { set in
                Section {
                    ForEach(set.exercises, id: \.hashValue) { exercise in
                        switch exercise {
                        case .repeater(let r):
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(r.tag)
                                    Text("\(r.numReps) reps")
                                    Text("\(r.timeOn)s/\(r.timeOff)s")
                                    Spacer()
                                }
                                Text("\(r.weight.formatted(.number.precision(.fractionLength(0...2)))) lbs")
                            }
                        case .maxHang(let m):
                            HStack {
                                Text(m.tag)
                                Text(m.side.abbreviation)
                                Text("\(m.target)s")
                                Text("\(m.weight.formatted(.number.precision(.fractionLength(0...2)))) lb")
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(set.name)
                        Spacer()
                        Text("Rest: \(set.restTime)s")
                    }
                }
            }
        }.navigationTitle(routine.name)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        navigationStore.push(ViewType.routineEdit(routine: routine))
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        navigationStore.push(ViewType.routineStart(routine: routine))
                    } label: {
                        Label("Session", systemImage: "plus")
                    }
                }
            }
    }
}

#Preview(traits: .modifier(TestDataModifier())) {
    @Previewable @Query var routines: [Routine]
    NavigationStack {
        RoutineView(routine: routines.first!)
    }
}
