//
//  RoutineEditView.swift
//  Athena
//
//  Created by Zach Wassynger on 9/25/26.
//

import SwiftData
import SwiftUI

struct RoutineEditView: View {
    @State private var routine: Routine
    @State private var isNew: Bool
    @State private var editData: RoutineData? = nil
    
    init(routine: Routine? = nil) {
        self.routine = routine ?? .init(superSets: [.init(name: "")])
        self.isNew = routine == nil
    }
    
    var body: some View {
        Form {
            Section {
                TextField("Name", text: $routine.name)
            }
            ForEach($routine.superSets.enumerated(), id: \.offset) { offset, $superSet in
                Section {
                    ForEach(routine.data
                        .filter { $0.position.superSetIndex == offset }
                        .sorted(by: { $0.position.setIndex < $1.position.setIndex })) { data in
                        Button {
                            editData = data
                        } label: {
                            HStack {
                                RoutineDataEntryView(data: data)
                                Spacer()
                            }.contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                    Button {
                        // TODO open sheet to link or create exercise
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                    }
                } header: {
                    HStack {
                        TextField("Name", text: $superSet.name, prompt: Text("Set \(routine.superSets.count + 1)"))
                        Spacer()
                        Picker("Order", selection: $superSet.order) {
                            ForEach(Routine.SuperSet.Order.allCases, id: \.name) { order in
                                Text(order.name).tag(order)
                            }
                        }.pickerStyle(.segmented)
                    }
                } footer: {
                    Stepper(superSet.restTime > 0 ? "Rest: \(superSet.restTime)s" : "No Rest", value: $superSet.restTime)
                }
                // TODO delete in footer with confirm message
            }
            Button("Add New Super Set") {
                routine.superSets.append(.init(name: ""))
            }
        }.navigationTitle("Edit Routine")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: .init(get: {
                editData != nil
            }, set: { newValue in
                if !newValue {
                    editData = nil
                }
            })) {
                if let editData {
                    RoutineDataEditSheet(data: editData)
                }
            }
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query var routines: [Routine]
    NavigationStack {
        RoutineEditView(routine: routines.first!)
    }
}
