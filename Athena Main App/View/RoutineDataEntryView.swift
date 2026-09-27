//
//  RoutineDataEntryView.swift
//  Athena
//
//  Created by Zach Wassynger on 9/26/26.
//

import SwiftData
import SwiftUI

struct RoutineDataEntryView: View {
    let data: RoutineData
    
    var header: String {
        data.exercise.name
    }
    var header2: String? {
        nil
    }
    
    init(data: RoutineData) {
        self.data = data
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
            if !data.expectedData.isEmpty {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    ForEach(0..<data.expectedData.count, id: \.self) { index in
                        GridRow(alignment: .top) {
                            Text("Set \(index + 1)")
                                .fontWeight(.semibold)
                            expectedView(data.expectedData[index])
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
    func expectedView(_ dataSet: ExerciseData.DataSet) -> some View {
        VStack(alignment: .leading) {
            switch data.exercise.category {
            case .generic(_, let dataTypes, let sideType):
                if sideType == .independent && !dataTypes.allSatisfy({ getText(dataSet: dataSet, dataType: $0, useAlt: false) == getText(dataSet: dataSet, dataType: $0, useAlt: true) }) {
                    Text("[L: \(dataTypes.compactMap { dataSet.getText($0, useAlt: false) }.joined(separator: ", "))]")
                    Text("[R: \(dataTypes.compactMap { dataSet.getText($0, useAlt: true) }.joined(separator: ", "))]")
                } else {
                    Text("[\(dataTypes.compactMap { dataSet.getText($0, useAlt: false) }.joined(separator: ", "))]")
                }
            case .repeater(_, _, _):
                let dataTypes: [Exercise.DataType] = [.reps, .weight]
                Text("[\(dataTypes.compactMap { dataSet.getText($0, useAlt: false) }.joined(separator: " @ "))]")
            case .maxHang(_, _):
                let dataTypes: [Exercise.DataType] = [.time, .weight]
                Text("[\(dataTypes.compactMap { dataSet.getText($0, useAlt: false) }.joined(separator: " @ "))]")
            case .campus(_, let mirrorSets):
                // TODO handle mirroring properly
                if mirrorSets {
                    Text(dataSet[.campus]?.text ?? "N/A")
                    Text(dataSet[.campusAlt]?.text ?? "N/A")
                } else {
                    Text(dataSet[.campus]?.text ?? "N/A")
                }
            }
        }.italic()
    }
    
    private func getText(dataSet: ExerciseData.DataSet, dataType: Exercise.DataType, useAlt: Bool) -> String {
        return dataSet.getText(dataType, useAlt: useAlt) ?? "N/A"
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query var routines: [Routine]
    Form {
        RoutineDataEntryView(data: routines.first!.data.first!)
    }
}
