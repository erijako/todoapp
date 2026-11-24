import StoreKit

/// Knows whether this install is a test build (Debug, TestFlight, Xcode or sandbox), so test-only
/// things (simulated Pro, unfinished Sharing) never reach App Store customers.
enum TestBuild {
    /// Known without waiting: Debug builds are always test builds.
    static var isDebug: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    /// Known without waiting: Debug builds, and TestFlight installs (they carry a sandbox receipt).
    static var isKnownTestInstall: Bool {
        isDebug || Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }

    /// Also asks StoreKit: TestFlight and sandbox installs report a non-production environment.
    static func check() async -> Bool {
        if isKnownTestInstall { return true }
        if case .verified(let transaction)? = try? await AppTransaction.shared {
            return transaction.environment != .production
        }
        return false
    }
}
