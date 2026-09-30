//
//  NavigationStore.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/14/26.
//

import SwiftUI
internal import Combine

@MainActor
final class NavigationStore: ObservableObject {
    @Published var path = NavigationPath()
    @Published var currentAthlete: Athlete? = nil
    
    func push(_ value: any Hashable) {
        path.append(value)
    }
    
    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
    
    func replace(_ value: any Hashable) {
        pop()
        push(value)
    }
    
    @ViewBuilder
    func handleView(_ view: ViewType) -> some View {
        switch view {
        case .athleteRoster:
            AthleteRosterView()
        case .athlete(let athlete):
            AthleteView(athlete: athlete)
        case .exercise(let exercise, let selectedAthlete):
            ExerciseView(exercise: exercise, selectedAthlete: selectedAthlete)
        case .exerciseAdd:
            ExerciseEditView()
        case .exerciseEdit(let exercise):
            ExerciseEditView(exercise: exercise)
        case .exerciseList:
            ExerciseListView()
        case .routineEdit(let routine):
            RoutineEditView(routine: routine)
        case .session(let session):
            SessionView(session: session)
        case .sessionLive(let session, let state):
            SessionLiveView(session: session, initialState: state)
        case .sessionGroupList:
            GroupSessionListView()
        }
    }
}

enum ViewType: Hashable {
    case athlete(athlete: Athlete)
    case athleteRoster
    case exercise(exercise: Exercise, selectedAthlete: Athlete?)
    case exerciseAdd
    case exerciseEdit(exercise: Exercise)
    case exerciseList
    case routineEdit(routine: Routine)
    case session(session: Session)
    case sessionLive(session: Session, state: SessionLiveView.ViewState? = nil)
    case sessionGroupList
}

extension View {
    func handleDestinations(_ navigationStore: NavigationStore) -> some View {
        self.navigationDestination(for: ViewType.self, destination: navigationStore.handleView)
    }
}
