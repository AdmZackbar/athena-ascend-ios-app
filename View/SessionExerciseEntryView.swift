//
//  SessionExerciseEntryView.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/19/26.
//

import SwiftUI

/// DIsplays the contents of a session exercise within a form/list
struct SessionExerciseEntryView: View {
    let exercise: Session.Exercise
    
    var body: some View {
        switch exercise {
        case .generic(let d):
            genericEntryView(d)
        case .repeater(let d):
            repeaterEntryView(d)
        case .maxHang(let d):
            maxHangEntryView(d)
        }
    }
    
    @ViewBuilder
    func genericEntryView(_ d: Session.GenericData) -> some View {
        VStack(alignment: .leading) {
            Text(d.expected.name)
                .bold()
            VStack(alignment: .leading) {
                ForEach(d.expected.sets.enumerated(), id: \.offset) { offset, expected in
                    if offset < d.actual.count {
                        let actual = d.actual[offset]
                        VStack(alignment: .leading) {
                            HStack {
                                Text(actual.text)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("[\(expected.text) \(d.expected.setDetailText)]")
                                    .font(.subheadline)
                                    .italic()
                                Spacer()
                            }
                            if !actual.notes.isEmpty {
                                Text(actual.notes)
                                    .lineLimit(1)
                                    .font(.caption)
                                    .padding(.leading, 4)
                            }
                        }
                    } else {
                        Text("\(expected.text) \(d.expected.setDetailText)")
                            .font(.subheadline)
                    }
                }
                if !d.notes.isEmpty {
                    Text(d.notes)
                        .lineLimit(3)
                        .font(.subheadline)
                        .fontWeight(.light)
                }
            }.padding(.leading, 4)
        }
    }
    
    @ViewBuilder
    func repeaterEntryView(_ d: Session.RepeaterData) -> some View {
        VStack(alignment: .leading) {
            Text("Repeater")
                .font(.subheadline)
                .italic()
            Text("\(d.expected.tag): \(d.expected.timeOn)s/\(d.expected.timeOff)s")
                .bold()
            ForEach(d.expected.sets.enumerated(), id: \.offset) { offset, expected in
                if offset >= d.actual.count {
                    Text(expected.text)
                        .font(.subheadline)
                        .italic()
                        .padding(.leading, 4)
                } else {
                    VStack(alignment: .leading) {
                        let actual = d.actual[offset]
                        HStack {
                            Text(actual.text)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            let diff: String? = {
                                if actual.numReps != expected.numReps && actual.weight != expected.weight {
                                    return expected.text
                                } else if actual.numReps != expected.numReps {
                                    return "\(expected.numReps) reps"
                                } else if actual.weight != expected.weight {
                                    return expected.weight.lbsFormat
                                } else {
                                    return nil
                                }
                            }()
                            if let diff {
                                Text("[\(diff)]")
                                    .font(.subheadline)
                                    .italic()
                            }
                            Spacer()
                        }
                        if !actual.notes.isEmpty {
                            Text(actual.notes)
                                .lineLimit(1)
                                .font(.caption)
                                .padding(.leading, 4)
                        }
                    }.padding(.leading, 4)
                }
            }
            if !d.notes.isEmpty {
                Text(d.notes)
                    .lineLimit(3)
                    .font(.subheadline)
                    .fontWeight(.light)
            }
        }
    }
    
    @ViewBuilder
    func maxHangEntryView(_ d: Session.MaxHangData) -> some View {
        VStack(alignment: .leading) {
            Text("Max Hang")
                .font(.subheadline)
                .italic()
            Text(d.expected.tag)
                .bold()
            ForEach(d.expected.sets.enumerated(), id: \.offset) { offset, expected in
                if offset >= d.actual.count {
                    Text(expected.text)
                        .font(.subheadline)
                        .italic()
                        .padding(.leading, 4)
                } else {
                    VStack(alignment: .leading) {
                        let actual = d.actual[offset]
                        HStack {
                            Text(actual.text)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            let diff: String? = {
                                if actual.side != expected.side {
                                    // TODO add granularity here too
                                    return expected.text
                                }
                                if actual.target != expected.target && actual.weight != expected.weight {
                                    return "\(expected.target)s @ \(expected.weight.lbsFormat)"
                                } else if actual.target != expected.target {
                                    return "\(expected.target)s"
                                } else if actual.weight != expected.weight {
                                    return expected.weight.lbsFormat
                                } else {
                                    return nil
                                }
                            }()
                            if let diff {
                                Text("[\(diff)]")
                                    .font(.subheadline)
                                    .italic()
                            }
                            Spacer()
                        }
                        if !actual.notes.isEmpty {
                            Text(actual.notes)
                                .lineLimit(1)
                                .font(.caption)
                                .padding(.leading, 4)
                        }
                    }.padding(.leading, 4)
                }
            }
            if !d.notes.isEmpty {
                Text(d.notes)
                    .lineLimit(3)
                    .font(.subheadline)
                    .fontWeight(.light)
            }
        }
    }
}

#Preview {
    Form {
        Section("Generic") {
            SessionExerciseEntryView(exercise: .generic(.init(expected: .init(name: "Barbell Bench Press", dataType: .repWeight, sets: [
                .init(num: 10),
                .init(num: 8),
                .init(num: 6),
                .init(min: 3, max: 5),
            ]), actual: [
                .init(numReps: 10, weight: 80),
                .init(numReps: 8, weight: 90),
                .init(numReps: 6, weight: 100, notes: "Test"),
                .init(numReps: 4, weight: 120, notes: "Test again"),
            ], notes: "Light work baybeeee")))
            SessionExerciseEntryView(exercise: .generic(.init(expected: .init(name: "Weighted Kettlebell Carries", dataType: .timeWeight, sets: [
                .init(num: 15),
                .init(num: 15),
                .init(num: 15),
            ]), actual: [
                .init(time: 10, weight: 80),
                .init(time: 8, weight: 90),
                .init(time: 6, weight: 100),
            ], notes: "rough")))
        }
        Section("Repeaters") {
            SessionExerciseEntryView(exercise: .repeater(.init(expected: .init(tag: "HC 15mm", sets: [
                .init(numReps: 7),
                .init(numReps: 6, weight: 10),
                .init(numReps: 5, weight: 20)
            ]), actual: [
                .init(numReps: 6, notes: "Tricky"),
                .init(numReps: 5, weight: 5),
                .init(numReps: 4, weight: 10)
            ], notes: "Test notes for these repeaters")))
        }
        Section("Max Hang") {
            SessionExerciseEntryView(exercise: .maxHang(.init(expected: .init(tag: "BM Middle", sets: [
                .init(side: .left, target: 10, weight: 35),
                .init(side: .right, target: 10, weight: 40),
                .init(side: .left, target: 8, weight: 40),
                .init(side: .right, target: 8, weight: 45),
            ]), actual: [
                .init(side: .left, target: 10, weight: 35),
                .init(side: .right, target: 9, weight: 40, notes: "Too much"),
                .init(side: .left, target: 6, weight: 40),
                .init(side: .right, target: 5, weight: 50, notes: "EZ"),
            ], notes: "Why am i doing this")))
        }
    }
}
