//
//  ExerciseMultiDataEntryView.swift
//  Athena
//
//  Created by Zach Wassynger on 9/25/26.
//

import SwiftUI

/// Assumes all data is for the same exercise and session and position,
/// but for different athletes.
struct ExerciseMultiDataEntryView: View {
    let groupData: [ExerciseData]
    let headerType: HeaderType
    
    var header: String {
        switch headerType {
        case .date:
            groupData.first!.session.startTime.formatted(date: .abbreviated, time: .omitted)
        case .exerciseName:
            groupData.first!.exercise.name
        }
    }
    var header2: String? {
        switch headerType {
        case .date:
            groupData.first!.session.startTime.formatted(date: .omitted, time: .shortened)
        case .exerciseName:
            nil
        }
    }
    
    init(groupData: [ExerciseData], headerType: HeaderType = .date) {
        self.groupData = groupData.sorted(by: { $0.athlete.name < $1.athlete.name })
        self.headerType = headerType
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(header)
                Spacer()
                if let header2 {
                    Text(header2)
                }
            }.bold()
                .foregroundStyle(.secondary)
            ForEach(groupData) { data in
                if !data.notes.isEmpty {
                    Text(data.notes)
                        .font(.subheadline)
                        .italic()
                }
            }
            let numRows: Int = groupData.map { max($0.expectedData.count, $0.actualData.count) }.max() ?? 0
            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    // Header
                    GridRow {
                        // Top left - nothing
                        Text("")
                        // All athlete names
                        ForEach(groupData) { d in
                            Text(d.athlete.name)
                                .fontWeight(.semibold)
                        }
                    }
                    // Data
                    ForEach(0..<numRows, id: \.self) { index in
                        GridRow(alignment: .top) {
                            // Column Header
                            Text("Set \(index + 1)")
                                .fontWeight(.semibold)
                            // Data for each athlete
                            ForEach(groupData) { d in
                                if index < d.actualData.count {
                                    dataSetView(d.actualData[index])
                                } else if index < d.expectedData.count {
                                    dataSetView(d.expectedData[index])
                                        .italic()
                                } else {
                                    Text("")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    func dataSetView(_ dataSet: ExerciseData.DataSet) -> some View {
        VStack(alignment: .leading) {
            switch groupData.first!.exercise.category {
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
    
    enum HeaderType {
        case date
        case exerciseName
    }
}
