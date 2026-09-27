//
//  ExerciseView.swift
//  Athena
//
//  Created by Zach Wassynger on 9/23/26.
//

import SwiftData
import SwiftUI

struct ExerciseView: View {
    @EnvironmentObject private var navigationStore: NavigationStore
    
    @Query(sort: \Athlete.name) private var athletes: [Athlete]
    
    @State var exercise: Exercise
    @State private var selectedAthlete: Athlete? = nil
    
    var body: some View {
        Form {
            ExerciseInfoSection(exercise: exercise)
            Section {
                if let selectedAthlete {
                    let data = selectedAthlete.data.filter { $0.exercise == exercise }
                    if data.isEmpty {
                        ContentUnavailableView("No data for athlete", systemImage: "tablecells")
                    } else {
                        ForEach(data.sorted(by: { $0.session.startTime > $1.session.startTime })) { d in
                            ExerciseDataEntryView(data: d)
                        }
                    }
                } else {
                    ContentUnavailableView("No athlete selected", systemImage: "person")
                }
            } header: {
                HStack {
                    Text("Data")
                    Spacer()
                    Picker("Athlete:", selection: $selectedAthlete) {
                        Text("None").tag(nil as Athlete?)
                        ForEach(athletes, id: \.uuid) { athlete in
                            Text(athlete.name)
                                .tag(athlete as Athlete?)
                        }
                    }
                }
            }
        }.navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        navigationStore.push(ViewType.exerciseEdit(exercise: exercise))
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                }
            }
    }
}

struct ExerciseInfoSection: View {
    let exercise: Exercise
    
    var categoryName: String {
        switch exercise.category {
        case .generic(_, _, _): return "Exercise"
        case .repeater(_, _, _): return "Repeaters"
        case .maxHang(_, _): return "Max Hangs"
        case .campus(_, _): return "Campus Sets"
        }
    }
    
    var body: some View {
        Section(categoryName) {
            switch exercise.category {
            case .generic(let name, let dataTypes, let sideType):
                genericInfoView(name: name, dataTypes: dataTypes, sideType: sideType)
            case .repeater(let tag, let timeOn, let timeOff):
                repeaterInfoView(tag: tag, timeOn: timeOn, timeOff: timeOff)
            case .maxHang(let tag, let sideType):
                maxHangInfoView(tag: tag, sideType: sideType)
            case .campus(let name, let mirrorSets):
                campusInfoView(name: name, mirrorSets: mirrorSets)
            }
            if !exercise.notes.isEmpty {
                VStack(alignment: .leading) {
                    Text("Notes")
                        .font(.subheadline)
                        .italic()
                    Text(exercise.notes)
                        .fontWeight(.semibold)
                }
            }
        }
    }
    
    @ViewBuilder
    func genericInfoView(name: String, dataTypes: [Exercise.DataType], sideType: Exercise.SideType) -> some View {
        VStack(alignment: .leading) {
            Text("Name")
                .font(.subheadline)
                .italic()
            Text(name)
                .fontWeight(.semibold)
        }
        VStack(alignment: .leading) {
            Text("Data Types")
                .font(.subheadline)
                .italic()
            Text(dataTypes.map(text).joined(separator: ", "))
                .fontWeight(.semibold)
        }
        VStack(alignment: .leading) {
            Text("Side Type")
                .font(.subheadline)
                .italic()
            Text(text(sideType))
                .fontWeight(.semibold)
        }
    }
    
    private func text(_ dataType: Exercise.DataType) -> String {
        switch dataType {
        case .reps: "Reps"
        case .time: "Time"
        case .weight: "Weight"
        case .distance: "Height"
        }
    }
    
    private func text(_ sideType: Exercise.SideType) -> String {
        switch sideType {
        case .none: "N/A"
        case .dependent: "Dependent"
        case .independent: "Independent"
        }
    }
    
    @ViewBuilder
    func repeaterInfoView(tag: String, timeOn: Int, timeOff: Int) -> some View {
        VStack(alignment: .leading) {
            Text("Hold/Grip")
                .font(.subheadline)
                .italic()
            Text(tag)
                .fontWeight(.semibold)
        }
        VStack(alignment: .leading) {
            Text("Period")
                .font(.subheadline)
                .italic()
            Text("\(timeOn)s / \(timeOff)s")
                .fontWeight(.semibold)
        }
    }
    
    @ViewBuilder
    func maxHangInfoView(tag: String, sideType: Exercise.SideType) -> some View {
        VStack(alignment: .leading) {
            Text("Hold/Grip")
                .font(.subheadline)
                .italic()
            Text(tag)
                .fontWeight(.semibold)
        }
        VStack(alignment: .leading) {
            Text("Type")
                .font(.subheadline)
                .italic()
            Text(sideType == .independent ? "Single Arm" : "Both Arm")
                .fontWeight(.semibold)
        }
    }
    
    @ViewBuilder
    func campusInfoView(name: String, mirrorSets: Bool) -> some View {
        VStack(alignment: .leading) {
            Text("Type")
                .font(.subheadline)
                .italic()
            Text(name)
                .fontWeight(.semibold)
        }
        VStack(alignment: .leading) {
            Text("Mirror Sets")
                .font(.subheadline)
                .italic()
            Text(mirrorSets ? "Yes" : "No")
                .fontWeight(.semibold)
        }
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query var exercises: [Exercise]
    NavigationStack {
        ExerciseView(exercise: exercises.first!)
    }
}
