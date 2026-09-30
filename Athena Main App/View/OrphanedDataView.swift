//
//  OrphanedDataView.swift
//  Athena
//
//  Created by Zach Wassynger on 9/30/26.
//

import SwiftData
import SwiftUI

/// Utility view to view and delete `ExerciseData` that is not attached to a session.
struct OrphanedDataView: View {
    @Environment(\.modelContext) var modelContext
    
    @Query(filter: #Predicate<ExerciseData> { d in
        d.session == nil
    }) var orphanedData: [ExerciseData]
    
    var body: some View {
        Form {
            if !orphanedData.isEmpty {
                Section("Data") {
                    ForEach(orphanedData) { d in
                        VStack(alignment: .leading) {
                            Text(d.athlete.name)
                            Text("[\(d.position.superSetIndex), \(d.position.setIndex)]")
                            ExerciseDataEntryView(data: d, headerType: .exerciseName)
                        }
                    }
                }
            } else {
                ContentUnavailableView("No orphaned exercise data.", image: "checkmark")
            }
        }.navigationTitle("Orphaned Exercise Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        orphanedData.forEach { modelContext.delete($0) }
                    } label: {
                        Label("Delete All", systemImage: "trash")
                    }
                }
            }
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        OrphanedDataView()
    }
}
