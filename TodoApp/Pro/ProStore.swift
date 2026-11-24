import Foundation
import Observation
import StoreKit

/// Product IDs. These must match App Store Connect and StoreKit/Products.storekit exactly.
enum ProProduct {
    static let yearly = "com.erijako.onestep.pro.yearly"
    static let monthly = "com.erijako.onestep.pro.monthly"
    static let lifetime = "com.erijako.onestep.pro.lifetime"

    /// Display order on the paywall.
    static let all = [yearly, monthly, lifetime]
}

/// Links required on the paywall by App Review.
enum Legal {
    /// Apple's standard EULA. Replace if you publish your own terms.
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    /// docs/privacy.html, served by GitHub Pages (Settings > Pages > branch main, folder /docs).
    static let privacy = URL(string: "https://erijako.github.io/todoapp/privacy.html")!
}

/// Loads Pro products, buys and restores them, and knows whether Pro is active.
///
/// StoreKit 2 verifies transactions on device, so no server is needed.
@MainActor
@Observable
final class ProStore {
    enum LoadState: Equatable {
        case idle, loading, loaded, failed
    }

    private(set) var products: [Product] = []
    private(set) var loadState: LoadState = .idle
    private(set) var isPro: Bool
    /// The product that grants Pro right now, if any.
    private(set) var activeProductID: String?
    /// Products whose free trial this person can still use.
    private(set) var trialEligible: Set<String> = []

    private static let cacheKey = "proActive"

    // MARK: Simulated purchase (test builds only)

    /// True in Debug builds and in TestFlight / Xcode / sandbox installs. Never in the App Store
    /// version, so the simulated purchase can't unlock Pro for real customers.
    private(set) var canSimulate = TestBuild.isDebug
    /// Pro unlocked by the "Simulate purchase" button instead of a real purchase.
    private(set) var isSimulated = false
    private static let simulatedKey = "proSimulated"
    private var simulatedFlag: Bool { AppGroup.defaults.bool(forKey: Self.simulatedKey) }

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {
        // Start from the cached value so the UI doesn't flash "locked" on launch.
        isPro = AppGroup.defaults.bool(forKey: Self.cacheKey)

        updatesTask = Task { [weak self] in
            // Purchases made elsewhere: renewals, Ask to Buy, refunds, other devices.
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }

        Task {
            await checkTestEnvironment()
            await refreshEntitlements()
            await loadProducts()
        }
    }

    /// TestFlight and sandbox installs report a non-production App Store environment.
    private func checkTestEnvironment() async {
        canSimulate = await TestBuild.check()
    }

    /// Unlocks Pro without the App Store, to test Pro features before real purchases work.
    func simulatePurchase() {
        guard canSimulate else { return }
        AppGroup.defaults.set(true, forKey: Self.simulatedKey)
        Task { await refreshEntitlements() }
    }

    /// Turns the simulated Pro off again (Settings).
    func endSimulation() {
        AppGroup.defaults.set(false, forKey: Self.simulatedKey)
        Task { await refreshEntitlements() }
    }

    // MARK: Products

    func loadProducts() async {
        guard loadState != .loading else { return }
        loadState = .loading
        do {
            let loaded = try await Product.products(for: ProProduct.all)
            products = loaded.sorted {
                (ProProduct.all.firstIndex(of: $0.id) ?? 0) < (ProProduct.all.firstIndex(of: $1.id) ?? 0)
            }
            var eligible: Set<String> = []
            for product in products {
                if let subscription = product.subscription,
                   subscription.introductoryOffer?.paymentMode == .freeTrial,
                   await subscription.isEligibleForIntroOffer {
                    eligible.insert(product.id)
                }
            }
            trialEligible = eligible
            loadState = products.isEmpty ? .failed : .loaded
        } catch {
            loadState = .failed
        }
    }

    func product(_ id: String) -> Product? {
        products.first { $0.id == id }
    }

    // MARK: Buying

    enum PurchaseOutcome {
        case purchased, pending, cancelled
    }

    func purchase(_ product: Product) async throws -> PurchaseOutcome {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                throw StoreError.unverified
            }
            await transaction.finish()
            await refreshEntitlements()
            return .purchased
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    /// Asks the App Store for the latest purchases. Shows a sign-in prompt if needed.
    func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    // MARK: Entitlements

    func refreshEntitlements() async {
        var active: String?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  ProProduct.all.contains(transaction.productID),
                  transaction.revocationDate == nil
            else { continue }
            // Prefer lifetime if someone has both.
            if active == nil || transaction.productID == ProProduct.lifetime {
                active = transaction.productID
            }
        }
        activeProductID = active
        isSimulated = active == nil && canSimulate && simulatedFlag
        isPro = active != nil || isSimulated
        AppGroup.defaults.set(isPro, forKey: Self.cacheKey)
    }

    enum StoreError: LocalizedError {
        case unverified

        var errorDescription: String? {
            String(localized: "The App Store couldn't confirm this purchase. Try Restore purchases in a moment.")
        }
    }
}
