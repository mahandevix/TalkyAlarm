import SwiftUI
import StoreKit

struct PaywallSheet: View {
    let reason: String
    @ObservedObject var subscriptionService: SubscriptionService
    let onClose: () -> Void
    @State private var statusMessage: String?
    @State private var isPurchasing = false
    @State private var isRestoring = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                featuresSection
                Text(L10n.tr("paywall.price"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                productSection
                statusSection
                Spacer()
            }
            .padding(20)
            .navigationTitle(L10n.tr("common.upgrade"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.tr("common.close")) {
                        onClose()
                    }
                }
            }
            .task {
                if subscriptionService.products.isEmpty {
                    await subscriptionService.loadProducts()
                }
                await subscriptionService.refreshEntitlements()
            }
            .onChange(of: subscriptionService.tier) { _, newTier in
                if newTier == .pro {
                    onClose()
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("paywall.title"))
                .font(.title2.weight(.semibold))
            Text(reason)
                .foregroundStyle(.secondary)
        }
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(L10n.tr("paywall.feature.unlimited"), systemImage: "checkmark.circle.fill")
            Label(L10n.tr("paywall.feature.recorded_voice"), systemImage: "checkmark.circle.fill")
            Label(L10n.tr("paywall.feature.natural_voice"), systemImage: "checkmark.circle.fill")
            Label(L10n.tr("paywall.feature.medicine_repeats"), systemImage: "checkmark.circle.fill")
            Label(L10n.tr("paywall.feature.backup"), systemImage: "checkmark.circle.fill")
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private var productSection: some View {
        if subscriptionService.isLoadingProducts {
            ProgressView(L10n.tr("paywall.loading"))
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if subscriptionService.orderedProducts.isEmpty {
            if subscriptionService.isLocalTestModeAvailable {
                localTestModeSection
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr("paywall.no_products"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button(L10n.tr("common.retry")) {
                        Task {
                            await subscriptionService.loadProducts()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(subscriptionService.orderedProducts, id: \.id) { product in
                    planButton(for: product)
                }

                Button(isRestoring ? L10n.tr("paywall.restoring") : L10n.tr("paywall.restore")) {
                    restore()
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
            }
        }
    }

    private var localTestModeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("paywall.local_test_mode"))
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                subscriptionService.enableLocalTestingPro()
                statusMessage = L10n.tr("paywall.purchase.success")
                onClose()
            } label: {
                HStack {
                    Text(L10n.tr("paywall.product.monthly"))
                    Spacer()
                    Text(L10n.tr("paywall.local_test.monthly_price"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)

            Button {
                subscriptionService.enableLocalTestingPro()
                statusMessage = L10n.tr("paywall.purchase.success")
                onClose()
            } label: {
                HStack {
                    Text(L10n.tr("paywall.product.yearly"))
                    Spacer()
                    Text(L10n.tr("paywall.local_test.yearly_price"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)

            if subscriptionService.tier == .pro {
                Button(L10n.tr("paywall.local_test.reset")) {
                    subscriptionService.disableLocalTestingPro()
                    statusMessage = L10n.tr("paywall.local_test.reset_done")
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if let statusMessage {
            Text(statusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var isBusy: Bool {
        isPurchasing || isRestoring
    }

    @ViewBuilder
    private func planButton(for product: Product) -> some View {
        if subscriptionService.isRecommended(product) {
            Button {
                purchase(product)
            } label: {
                planButtonLabel(for: product)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isBusy)
        } else {
            Button {
                purchase(product)
            } label: {
                planButtonLabel(for: product)
            }
            .buttonStyle(.bordered)
            .disabled(isBusy)
        }
    }

    private func planButtonLabel(for product: Product) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(subscriptionService.productTitle(product))
                    .font(.headline)
                if subscriptionService.isRecommended(product) {
                    Text(L10n.tr("paywall.product.recommended"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(product.displayPrice)
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func purchase(_ product: Product) {
        Task {
            isPurchasing = true
            defer { isPurchasing = false }

            let outcome = await subscriptionService.purchase(product)
            switch outcome {
            case .success:
                statusMessage = L10n.tr("paywall.purchase.success")
                onClose()
            case .pending:
                statusMessage = L10n.tr("paywall.purchase.pending")
            case .cancelled:
                statusMessage = L10n.tr("paywall.purchase.cancelled")
            case .failed(let message):
                statusMessage = L10n.format("paywall.purchase.error.generic", message)
            }
        }
    }

    private func restore() {
        Task {
            isRestoring = true
            defer { isRestoring = false }

            if let message = await subscriptionService.restorePurchases() {
                statusMessage = L10n.format("paywall.purchase.error.generic", message)
            } else if subscriptionService.tier == .pro {
                statusMessage = L10n.tr("paywall.purchase.success")
                onClose()
            } else {
                statusMessage = L10n.tr("paywall.restore.no_purchases")
            }
        }
    }
}
