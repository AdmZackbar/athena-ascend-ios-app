//
//  MainView.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/14/26.
//

import SwiftUI
import SwiftData

struct MainView: View {
    @StateObject private var navigationStore = NavigationStore()
    @Environment(\.modelContext) private var modelContext
    @Query private var routines: [Routine]

    var body: some View {
        NavigationStack(path: $navigationStore.path) {
            List {
                ForEach(routines) { routine in
                    Button {
                        navigationStore.push(ViewType.routineView(routine: routine))
                    } label: {
                        HStack {
                            Text(routine.name)
                            Spacer()
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                navigationStore.push(ViewType.routineEdit(routine: routine))
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                withAnimation {
                                    modelContext.delete(routine)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
                .onDelete(perform: deleteRoutines)
            }
            .toolbar {
                ToolbarItem {
                    Button {
                        navigationStore.push(ViewType.routineAdd)
                    } label: {
                        Label("Add Routine", systemImage: "plus")
                    }
                }
            }.navigationDestination(for: ViewType.self, destination: Self.handleView)
        }.environmentObject(navigationStore)
    }

    private func deleteRoutines(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(routines[index])
            }
        }
    }
    
    @MainActor
    @ViewBuilder
    static func handleView(_ view: ViewType) -> some View {
        switch view {
        case .routineView(let routine):
            RoutineView(routine: routine)
        case .routineAdd:
            RoutineEditView()
        case .routineEdit(let routine):
            RoutineEditView(routine: routine)
        }
    }
}

enum ViewType: Hashable {
    case routineView(routine: Routine)
    case routineAdd
    case routineEdit(routine: Routine)
}

#Preview(traits: .modifier(TestDataModifier())) {
    MainView()
}
