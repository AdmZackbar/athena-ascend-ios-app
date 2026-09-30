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
    
    @Query(sort: \Athlete.name) private var athletes: [Athlete]
    @AppStorage(CurrentAthlete.storageKey) private var currentAthleteID: String = ""
    
    @State private var viewType: MainViewType = .session
    @State private var exportAlert: ExportAlert?

    var body: some View {
        NavigationStack(path: $navigationStore.path) {
            TabView(selection: $viewType) {
                ForEach(MainViewType.allCases, id: \.name) { type in
                    getView(type)
                        .tag(type)
                        .tabItem {
                            Label(type.name, systemImage: type.icon)
                        }
                }
            }.navigationTitle(navigationStore.currentAthlete?.fullName ?? navigationStore.currentAthlete?.name ?? "Select Athlete")
                .navigationBarTitleDisplayMode(.inline)
                .handleDestinations(navigationStore)
                .toolbar(content: toolbarContent)
                .task {
                    resolveCurrentAthlete()
                }
                .onChange(of: athletes) { _, _ in
                    resolveCurrentAthlete()
                }
                .onChange(of: navigationStore.currentAthlete) { _, newValue in
                    currentAthleteID = newValue?.uuid.uuidString ?? ""
                }
                .alert(item: $exportAlert) { alert in
                    Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
                }
        }.environmentObject(navigationStore)
    }
    
    @ToolbarContentBuilder
    func toolbarContent() -> some ToolbarContent {
        ToolbarTitleMenu {
            ForEach(athletes) { athlete in
                Button {
                    navigationStore.currentAthlete = athlete
                } label: {
                    if athlete.uuid == navigationStore.currentAthlete?.uuid {
                        Label(athlete.name, systemImage: "checkmark")
                    } else {
                        Text(athlete.name)
                    }
                }
            }
        }
        ToolbarItemGroup(placement: .topBarLeading) {
            Menu {
                Button {
                    navigationStore.push(ViewType.exerciseList)
                } label: {
                    Label("View Exercises", systemImage: "tablecells")
                }
                Button {
                    navigationStore.push(ViewType.sessionGroupList)
                } label: {
                    Label("View Group Sessions", systemImage: "person.3")
                }
                Button {
                    navigationStore.push(ViewType.athleteRoster)
                } label: {
                    Label("Manage Athletes", systemImage: "person.text.rectangle")
                }
                Button {
                    exportAllData()
                } label: {
                    Label("Export Data", systemImage: "square.and.arrow.up")
                }
            } label: {
                Label("Options", systemImage: "ellipsis")
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Menu {
                Button {
                    let session = Session()
                    if let athlete = navigationStore.currentAthlete {
                        session.athletes.append(athlete)
                    }
                    modelContext.insert(session)
                    navigationStore.push(ViewType.session(session: session))
                } label: {
                    Label("Start New Session", systemImage: "clock")
                }
                Button {
                    let routine = Routine(superSets: [.init(name: "")])
                    modelContext.insert(routine)
                    navigationStore.push(ViewType.routineEdit(routine: routine))
                } label: {
                    Label("Create New Routine", systemImage: "map")
                }
                Button {
                    navigationStore.push(ViewType.exerciseAdd)
                } label: {
                    Label("Create New Exercise", systemImage: "scalemass")
                }
            } label: {
                Label("Add", systemImage: "plus")
            }
        }
    }
    
    private func resolveCurrentAthlete() {
        guard navigationStore.currentAthlete == nil else { return }
        let resolved = CurrentAthlete.resolve(storedID: currentAthleteID, athletes: athletes, context: modelContext)
        navigationStore.currentAthlete = resolved
    }

    private func exportAllData() {
        do {
            let directory = try DataExporter.exportAllModels(context: modelContext)
            exportAlert = ExportAlert(title: "Export Complete", message: "Data exported to:\n\(directory.lastPathComponent)")
        } catch {
            exportAlert = ExportAlert(title: "Export Failed", message: error.localizedDescription)
        }
    }
    
    @ViewBuilder
    private func getView(_ type: MainViewType) -> some View {
        if let currentAthlete = navigationStore.currentAthlete {
            switch type {
            case .exercise:
                AthleteExerciseListView(athlete: currentAthlete)
            case .routine:
                RoutineListView(athlete: currentAthlete)
            case .session:
                SessionListView(athlete: currentAthlete)
            }
        } else {
            ProgressView()
        }
    }
    
    private enum MainViewType: CaseIterable, Hashable {
        case session, routine, exercise
        
        var name: String {
            switch self {
            case .exercise:
                return "Exercises"
            case .routine:
                return "Routines"
            case .session:
                return "Sessions"
            }
        }
        
        var icon: String {
            switch self {
            case .exercise:
                return "tablecells"
            case .routine:
                return "book"
            case .session:
                return "calendar"
            }
        }
    }

    private struct ExportAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }
}

#Preview(traits: .sampleData) {
    MainView()
}
