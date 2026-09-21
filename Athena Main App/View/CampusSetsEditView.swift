//
//  CampusSetsEditView.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 9/21/26.
//

import SwiftUI

enum CampusMoveType: CaseIterable, Hashable, Equatable {
    case defined

    var name: String {
        switch self {
        case .defined:
            return "Defined"
        }
    }
}

/// Lists the planned sets of a campus exercise, with add/remove and a callback to open the editor for a set
struct CampusPlannedSetsList: View {
    @Binding var item: Routine.CampusSets
    let onEdit: (Int) -> Void

    var body: some View {
        Section {
            Picker("Type:", selection: $item.type) {
                ForEach(Routine.CampusSets.Exercise.allCases, id: \.text) {
                    Text($0.text).tag($0)
                }
            }
        }
        Section {
            ForEach(item.sets.enumerated(), id: \.offset) { offset, set in
                Button {
                    onEdit(offset)
                } label: {
                    VStack(alignment: .leading) {
                        Text(set.board.name)
                            .font(.subheadline)
                            .fontWeight(.regular)
                            .italic()
                        if let moves = set.moves.moves {
                            Text(moves.text)
                            if set.doMirror {
                                Text(moves.flipped.text)
                            }
                        } else {
                            Text(set.doMirror ? "\(set.moves.text) x2" : set.moves.text)
                        }
                    }.contentShape(Rectangle())
                        .fontWeight(.semibold)
                }.buttonStyle(.plain)
            }
        } header: {
            VStack(alignment: .leading) {
                HStack(spacing: 16) {
                    Text("Sets")
                    Spacer()
                    Button {
                        item.sets.append(.init(moves: .defined([item.type.start])))
                    } label: {
                        Image(systemName: "plus")
                    }
                    Button {
                        item.sets.removeLast()
                    } label: {
                        Image(systemName: "minus")
                    }.disabled(item.sets.isEmpty)
                }.buttonStyle(.plain)
            }
        }
    }
}

/// Edits a single planned campus set (board, mirroring, and moves)
struct CampusPlannedSetEditor: View {
    @Binding var item: Routine.CampusSets
    let index: Int
    @Binding var moves: [CampusMove]
    @Binding var moveType: CampusMoveType

    var body: some View {
        // TODO handle non-defined move set for base
        Section("Set \(index + 1)") {
            Picker("Board/Edges:", selection: $item.sets[index].board) {
                ForEach(CampusBoard.allCases, id: \.name) { board in
                    Text(board.name).tag(board)
                }
            }
            if item.type.canMirror {
                Toggle("Mirror Set:", isOn: $item.sets[index].doMirror)
            }
            if CampusMoveType.allCases.count > 1 {
                Picker("Moves:", selection: $moveType) {
                    ForEach(CampusMoveType.allCases, id: \.name) { moveType in
                        Text(moveType.name).tag(moveType)
                    }
                }
            }
            switch moveType {
            case .defined:
                CampusBoardView(board: item.sets[index].board, exercise: item.type, moves: $moves)
            }
        }
    }
}
