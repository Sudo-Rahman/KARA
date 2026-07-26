# CloudKit production setup

KARA uses SwiftData with the private CloudKit database in `iCloud.kara`. The app does not expose a switch that disables synchronization.

Before running on a signed device or shipping:

1. In Certificates, Identifiers & Profiles, attach `iCloud.kara` to `com.karaprivate.KARA` and enable CloudKit.
2. Run a Debug build signed by the development team to create the local SwiftData store.
3. Initialize the development schema using Apple’s SwiftData/Core Data CloudKit schema workflow.
4. In CloudKit Console, verify the `Asset`, `AssetAttachment`, `SavedSeller`, and `StorageLocation` record types and enable any indexes needed by the console.
5. Promote the development schema to production before submitting the first build that writes asset data.

CloudKit schema changes are additive after promotion. Do not rename or remove persisted properties without a versioned migration and a compatible additive schema change.
