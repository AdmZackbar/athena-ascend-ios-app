//
//  AthleteView.swift
//  Athena
//
//  Created by Zach Wassynger on 9/23/26.
//

import SwiftData
import SwiftUI

/// One athlete's history: every solo session plus every team-session entry they
/// took part in, newest first.
struct AthleteView: View {
    @State var athlete: Athlete

    var body: some View {
        Form {
            Section("Info") {
                TextField("Nickname", text: $athlete.name)
                TextField("First Name", text: .init(get: {
                    athlete.firstName ?? ""
                }, set: { newValue in
                    athlete.firstName = newValue.isEmpty ? nil : newValue
                }))
                TextField("Last Name", text: .init(get: {
                    athlete.lastName ?? ""
                }, set: { newValue in
                    athlete.lastName = newValue.isEmpty ? nil : newValue
                }))
                HStack {
                    Toggle("Set Birthday", isOn: .init(get: {
                        athlete.birthDate != nil
                    }, set: { newValue in
                        if !newValue {
                            athlete.birthDate = nil
                        }
                    }))
                    if athlete.birthDate != nil {
                        DatePicker("Birthday", selection: .init(get: {
                            athlete.birthDate ?? .now
                        }, set: { newValue in
                            athlete.birthDate = newValue
                        }))
                    }
                }
            }
            // TODO show sessions and data
        }.navigationTitle(athlete.name)
            .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func historyRow(date: Date, label: String?) -> some View {
        VStack(alignment: .leading) {
            if let label {
                Text(label)
                    .italic()
                    .font(.subheadline)
            }
            Text(date.formatted(date: .abbreviated, time: .shortened))
                .fontWeight(.semibold)
        }
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query var athletes: [Athlete]
    AthleteView(athlete: athletes.first!)
}
