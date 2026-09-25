//
//  ExerciseDataEntryView.swift
//  Athena
//
//  Created by Zach Wassynger on 9/25/26.
//

import SwiftUI

struct ExerciseDataEntryView: View {
    let exercise: Exercise
    let data: ExerciseData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(data.session.startTime.formatted(date: .abbreviated, time: .shortened))
                .foregroundStyle(.secondary)
            if !data.notes.isEmpty {
                Text(data.notes)
                    .font(.subheadline)
                    .italic()
            }
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                ForEach(data.actualData.enumerated(), id: \.offset) { offset, d in
                    GridRow(alignment: .top) {
                        Text("Set \(offset + 1)")
                            .fontWeight(.semibold)
                        dataSetView(d)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    func dataSetView(_ dataSet: ExerciseData.DataSet) -> some View {
        VStack(alignment: .leading) {
            switch exercise.category {
            case .generic(_, let dataTypes, let sideType):
                if sideType == .independent && !dataTypes.allSatisfy({ getText(dataSet: dataSet, dataType: $0, useAlt: false) == getText(dataSet: dataSet, dataType: $0, useAlt: true) }) {
                    Text("L: \(dataTypes.map { getText(dataSet: dataSet, dataType: $0, useAlt: false) }.joined(separator: ", "))")
                    Text("R: \(dataTypes.map { getText(dataSet: dataSet, dataType: $0, useAlt: true) }.joined(separator: ", "))")
                } else {
                    Text(dataTypes.map { getText(dataSet: dataSet, dataType: $0, useAlt: false) }.joined(separator: ", "))
                }
            case .repeater(_, _, _):
                let dataTypes: [Exercise.DataType] = [.reps, .weight]
                Text(dataTypes.map { getText(dataSet: dataSet, dataType: $0, useAlt: false) }.joined(separator: " @ "))
            case .maxHang(_, _):
                let dataTypes: [Exercise.DataType] = [.time, .weight]
                Text(dataTypes.map { getText(dataSet: dataSet, dataType: $0, useAlt: false) }.joined(separator: " @ "))
            case .campus(_, let mirrorSets):
                // TODO handle mirroring properly
                if mirrorSets {
                    Text(dataSet[.campus]?.text ?? "N/A")
                    Text(dataSet[.campusAlt]?.text ?? "N/A")
                } else {
                    Text(dataSet[.campus]?.text ?? "N/A")
                }
            }
            if let notes = dataSet[.notes]?.text {
                Text(notes)
                    .font(.caption)
            }
        }
    }
    
    private func getText(dataSet: ExerciseData.DataSet, dataType: Exercise.DataType, useAlt: Bool) -> String {
        return dataSet.getText(dataType, useAlt: useAlt) ?? "N/A"
    }
}
