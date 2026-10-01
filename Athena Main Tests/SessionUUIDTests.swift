//
//  SessionUUIDTests.swift
//  AthenaAscendTests
//
//  Created by Zach Wassynger on 10/1/26.
//

import Foundation
import SwiftData
import Testing
@testable import Athena

@MainActor
struct SessionUUIDTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(SchemaV3.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test func newSessionsGetUniqueUUIDs() throws {
        let a = Session()
        let b = Session()
        #expect(a.uuid != b.uuid)
    }

    @Test func uuidSurvivesInsertAndSave() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = Session()
        let before = session.uuid
        context.insert(session)
        try context.save()

        let fetched = try #require(try context.fetch(FetchDescriptor<Session>()).first)
        #expect(fetched.uuid == before)
    }
}
