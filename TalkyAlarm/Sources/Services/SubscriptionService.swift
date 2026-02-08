import Foundation
import StoreKit

@MainActor
final class SubscriptionService: ObservableObject {
    enum PurchaseOutcome {
        case success
        case pending
        case cancelled
        case failed(String)
    }

    let monthlyProductID = "com.barmanstu.talkyalarm.pro.monthly"
    let yearlyProductID = "com.barmanstu.talkyalarm.pro.yearly"

    @Published private(set) var tier: SubscriptionTier = .free
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoadingProducts = false

    private var updatesTask: Task<Void, Never>?
    private let defaults = UserDefaults.standard
    private let localTestingKey = "subscription.localTestingPro"

    init() {
        updatesTask = observeTransactionUpdates()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    var orderedProducts: [Product] {
        let order = [monthlyProductID, yearlyProductID]
        return order.compactMap { productID in
            products.first(where: { $0.id == productID })
        }
    }

    func productTitle(_ product: Product) -> String {
        switch product.id {
        case monthlyProductID:
            return L10n.tr("paywall.product.monthly")
        case yearlyProductID:
            return L10n.tr("paywall.product.yearly")
        default:
            return product.displayName
        }
    }

    func isRecommended(_ product: Product) -> Bool {
        product.id == yearlyProductID
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let fetched = try await Product.products(for: [monthlyProductID, yearlyProductID])
            products = fetched
        } catch {
            products = []
        }
    }

    func refreshEntitlements() async {
        let validProductIDs: Set<String> = [monthlyProductID, yearlyProductID]
        var hasPro = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard validProductIDs.contains(transaction.productID) else { continue }
            guard transaction.revocationDate == nil else { continue }

            if let expirationDate = transaction.expirationDate, expirationDate < Date() {
                continue
            }

            hasPro = true
            break
        }

#if DEBUG
        if !hasPro, defaults.bool(forKey: localTestingKey) {
            hasPro = true
        }
#endif
        tier = hasPro ? .pro : .free
    }

    func purchase(_ product: Product) async -> PurchaseOutcome {
        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verificationResult):
                guard case .verified(let transaction) = verificationResult else {
                    return .failed(L10n.tr("paywall.purchase.error.verification"))
                }
                await transaction.finish()
                await refreshEntitlements()
                return .success

            case .pending:
                return .pending

            case .userCancelled:
                return .cancelled

            @unknown default:
                return .failed(L10n.tr("paywall.purchase.error.unknown"))
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func restorePurchases() async -> String? {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task {
            for await update in Transaction.updates {
                guard case .verified(let transaction) = update else { continue }
                await transaction.finish()
                await refreshEntitlements()
            }
        }
    }

#if DEBUG
    var isLocalTestModeAvailable: Bool {
        products.isEmpty
    }

    func enableLocalTestingPro() {
        defaults.set(true, forKey: localTestingKey)
        tier = .pro
    }

    func disableLocalTestingPro() {
        defaults.set(false, forKey: localTestingKey)
        tier = .free
    }
#else
    var isLocalTestModeAvailable: Bool {
        false
    }

    func enableLocalTestingPro() { }
    func disableLocalTestingPro() { }
#endif
}
