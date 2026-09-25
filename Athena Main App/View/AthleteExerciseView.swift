//
//  AthleteExerciseView.swift
//  Athena
//
//  Created by Zach Wassynger on 9/25/26.
//

import SwiftUI

struct AthleteExerciseView: View {
    @EnvironmentObject private var navigationStore: NavigationStore
    
    let exercise: Exercise
    let athlete: Athlete
    
    var categoryName: String {
        switch exercise.category {
        case .generic(_, _, _): return "Exercise"
        case .repeater(_, _, _): return "Repeaters"
        case .maxHang(_, _): return "Max Hangs"
        case .campus(_, _): return "Campus Sets"
        }
    }
    
    var body: some View {
        Form {
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
            }
            Section("Data") {
                let data = athlete.data.filter { $0.exercise == exercise }
                if data.isEmpty {
                    ContentUnavailableView("No data for athlete", systemImage: "tablecells")
                } else {
                    ForEach(data.sorted(by: { $0.session.startTime > $1.session.startTime })) { d in
                        ExerciseDataEntryView(exercise: exercise, data: d)
                    }
                }
            }
        }.navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
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
