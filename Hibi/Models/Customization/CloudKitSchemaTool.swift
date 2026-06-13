#if DEBUG
import CoreData
import Foundation
import SwiftData

// MARK: - CloudKitSchemaTool
//
// PATH CHOSEN: NSManagedObjectModel.makeManagedObjectModel(for:) bridge (preferred).
//
// The API exists and compiles (confirmed: it returns NSManagedObjectModel?, not
// NSManagedObjectModel — unwrapped below with a guard+throw). It builds an
// NSManagedObjectModel directly from the VersionedSchema model types and passes it
// to NSPersistentCloudKitContainer.initializeCloudKitSchema(), which guarantees the
// FULL schema is materialized in the Development environment regardless of what test
// data is present. The JIT-seed fallback (insert one fully-populated record of every
// type) is only needed when this bridge is unavailable — it is NOT needed here.

enum SchemaToolError: Error, LocalizedError {
    case modelBuildFailed
    var errorDescription: String? {
        switch self {
        case .modelBuildFailed:
            return "NSManagedObjectModel.makeManagedObjectModel(for:) returned nil — check that all @Model types are valid."
        }
    }
}

enum CloudKitSchemaTool {

    /// DEBUG-ONLY. Materializes the full schema in the Development CloudKit environment.
    ///
    /// Run once on a real device signed into iCloud (Settings → DEBUG → Initialize
    /// CloudKit Schema), then run `make ck-export`, inspect the output, and deploy
    /// via CloudKit Console "Deploy Schema Changes".
    ///
    /// Never called from production startup.
    @MainActor
    static func initializeSchema() throws {
        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: SchemaV1.models) else {
            throw SchemaToolError.modelBuildFailed
        }
        // Use a real on-disk temp store: CloudKit mirroring requires persistent-history
        // tracking, which an in-memory ("/dev/null") store can reject at loadPersistentStores.
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("HibiCustomizationSchema.sqlite")
        // Clear any leftover store from a prior run (its options/config may differ) so each
        // bring-up starts clean. SQLite leaves -wal/-shm sidecars too.
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + suffix))
        }
        let desc = NSPersistentStoreDescription(url: storeURL)
        // REQUIRED for NSPersistentCloudKitContainer — without history tracking the CloudKit
        // mirror never initializes and initializeCloudKitSchema() silently does nothing.
        desc.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        desc.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        desc.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: CustomizationContainer.cloudKitContainerID
        )
        let container = NSPersistentCloudKitContainer(
            name: "HibiCustomization",
            managedObjectModel: model
        )
        container.persistentStoreDescriptions = [desc]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
        try container.initializeCloudKitSchema(options: [])
    }
}
#endif
