import Foundation
import SwiftData

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] = [
        PaperStyle.self, StructuralWidget.self, DayCustomization.self,
        PlacedSticker.self, TextObject.self, Sticker.self,
    ]
}

enum CustomizationMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] = [SchemaV1.self]
    static var stages: [MigrationStage] = []   // grows additively per future version
}

enum CustomizationContainer {
    static let cloudKitContainerID = "iCloud.com.weichart.hibi"

    static func make(inMemory: Bool = false, cloudKit: Bool = true) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: cloudKit ? .private(cloudKitContainerID) : .none
        )
        return try ModelContainer(for: schema, migrationPlan: CustomizationMigrationPlan.self, configurations: config)
    }
}
