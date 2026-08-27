//
//  RepWeightChart.swift
//  AthenaAscend
//
//  Created by Zach Wassynger on 8/26/26.
//

import Charts
import SwiftUI

struct RepWeightChart: View {
    let data: [Data]
    
    var body: some View {
        Chart(data) { d in
            PointMark(x: .value("Reps", d.reps), y: .value("Weight", d.weight))
                .foregroundStyle(by: .value("Date", d.date.formatted(date: .abbreviated, time: .omitted)))
                .opacity(0.4)
        }.frame(height: 170)
    }
    
    struct Data: Identifiable, Hashable, Equatable {
        var id: UUID
        var date: Date
        var reps: Int
        var weight: Double
        
        init(date: Date, reps: Int, weight: Double) {
            self.id = .init()
            self.date = date
            self.reps = reps
            self.weight = weight
        }
    }
}

#Preview {
    RepWeightChart(data: [])
}
