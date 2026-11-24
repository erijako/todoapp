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

    /// TestFlight and sandbox installs report a non-production App Store environment.
    static func check() async -> Bool {
        if isDebug { return true }
        if case .verified(let transaction)? = try? await AppTransaction.shared {
            return transaction.environment != .production
        }
        return false
    }
}
