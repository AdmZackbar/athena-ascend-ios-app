//
//  ExerciseDataEntryView.swift
//  Athena
//
//  Created by Zach Wassynger on 9/25/26.
//

import SwiftUI

struct ExerciseDataEntryView: View {
    let data: ExerciseData
    let headerType: HeaderType?
    
    var header: String? {
        switch headerType {
        case .date:
            data.session.startTime.formatted(date: .abbreviated, time: .omitted)
        case .exerciseName:
            data.exercise.name
        case .athleteName:
            data.athlete.name
        case .none:
            nil
        }
    }
    var header2: String? {
        switch headerType {
        case .date:
            data.session.startTime.formatted(date: .omitted, time: .shortened)
        case .exerciseName, .athleteName, .none:
            nil
        }
    }
    
    init(data: ExerciseData, headerType: HeaderType? = nil) {
        self.data = data
        self.headerType = headerType
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let header, let header2 {
                HStack {
                    Text(header)
                    Spacer()
                    Text(header2)
                }.bold()
                    .foregroundStyle(.secondary)
            } else if let header {
                Text(header)
                    .bold()
                    .foregroundStyle(.secondary)
            } else if let header2 {
                Text(header2)
                    .bold()
                    .foregroundStyle(.secondary)
            }
            if !data.notes.isEmpty {
                Text(data.notes)
                    .font(.subheadline)
                    .italic()
            }
            if !data.actualData.isEmpty || !data.expectedData.isEmpty {
                let numRows: Int = max(data.actualData.count, data.expectedData.count)
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    ForEach(0..<numRows, id: \.self) { index in
                        GridRow(alignment: .top) {
                            Text("Set \(index + 1)")
                                .fontWeight(.semibold)
                            let expected: ExerciseData.DataSet? = index < data.expectedData.count ? data.expectedData[index] : nil
                            let actual: ExerciseData.DataSet? = index < data.actualData.count ? data.actualData[index] : nil
                            if let expected, let actual {
                                actualView(actual)
                                // Remove shared values from expected
                                let diff = expected ^ actual
                                // Only show if needed
                                if !diff.isEmpty {
                                    ExpectedDataSetView(exercise: data.exercise, dataSet: diff)
                                }
                            } else if let expected {
                                ExpectedDataSetView(exercise: data.exercise, dataSet: expected)
                            } else if let actual {
                                actualView(actual)
                            }
                        }
                    }
                }
            } else {
                Text("No Data")
                    .italic()
            }
        }
    }
    
    @ViewBuilder
    func actualView(_ dataSet: ExerciseData.DataSet) -> some View {
        VStack(alignment: .leading) {
            switch data.exercise.category {
            case .generic(_, let dataTypes, let sideType):
                if sideType == .independent && dataSet.hasAlt {
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
                if mirrorSets {
                    Text(dataSet[.campus]?.text ?? "N/A")
                    Text(dataSet[.campusAlt]?.text ?? dataSet[.campus]?.alt.text ?? "N/A")
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
    
    enum HeaderType {
        case date
        case exerciseName
        case athleteName
    }
}
