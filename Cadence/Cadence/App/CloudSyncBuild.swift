import Foundation

/// Whether this build mirrors the store to iCloud. Debug builds signed with a
/// free personal team cannot hold the iCloud entitlement, so the Cadence
/// target's Debug configuration sets `LOCAL_ONLY_STORE` and the app keeps all
/// data on this device. Every CloudKit entry point checks this first, because
/// touching `CKContainer` without the entitlement terminates the app.
enum CloudSyncBuild {
    #if LOCAL_ONLY_STORE
    static let isEnabled = false
    #else
    static let isEnabled = true
    #endif

    static var disabledExplanation: String {
        String(localized: "iCloud sync is off in this build because it's signed with a personal developer team, which can't use iCloud. Your workouts are saved on this iPhone only. Use Backup & Restore to export a copy.")
    }
}
