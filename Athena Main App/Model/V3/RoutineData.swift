//
//  ExerciseData.swift
//  Athena
//
//  Created by Zach Wassynger on 9/24/26.
//

import SwiftData

extension SchemaV3 {
    @Model
    final class RoutineData {
        var exercise: Exercise! = nil
        var routine: Routine! = nil
        var position: ExerciseData.Position = ExerciseData.Position(setIndex: 0)
        var expectedData: [ExerciseData.DataSet] = []
        
        init(exercise: Exercise,
             routine: Routine,
             position: ExerciseData.Position,
             expectedData: [ExerciseData.DataSet] = []) {
            self.exercise = exercise
            self.routine = routine
            self.position = position
            self.expectedData = expectedData
        }
    }
}
