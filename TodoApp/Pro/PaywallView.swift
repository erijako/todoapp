import StoreKit
import SwiftUI

/// The Pro paywall, in the Calm & Soft style. Honest and quiet: the close button is always
/// visible, prices are spelled out, and there is no countdown or fake urgency.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProStore.self) private var store

    @State private var selectedID = ProProduct.yearly
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var pendingNotice = false
    @State private var thanks = false

    private var selected: Product? { store.product(selectedID) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Theme.focusGround.ignoresSafeArea()

            if thanks {
                thankYou
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                ScrollView {
                    VStack(spacing: 22) {
                        hero
                        benefits
                        plans
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 56)
                    .padding(.bottom, 12)
                }
                .scrollIndicators(.hidden)
                .safeAreaInset(edge: .bottom) { purchaseBar }
            }

            closeButton
        }
        .foregroundStyle(Theme.ink)
        .animation(.spring(duration: 0.35), value: thanks)
        .sensoryFeedback(.success, trigger: thanks)
        .task {
            if store.loadState != .loaded { await store.loadProducts() }
        }
        .onChange(of: store.isPro) {
            // Bought or restored from somewhere else (e.g. another device).
            if store.isPro && !thanks { celebrate() }
        }
        .alert(Text("Something went wrong"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert(Text("Waiting for approval"), isPresented: $pendingNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your purchase needs approval (for example Ask to Buy). Pro unlocks as soon as it's approved.")
        }
    }

    // MARK: Pieces

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.body.weight(.bold))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 44, height: 44)
                .background(Theme.paper, in: Circle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, 16)
        .padding(.top, 8)
        .accessibilityLabel(Text("Close"))
    }

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.paper)
                Circle()
                    .stroke(Theme.track, lineWidth: 9)
                    .padding(5)
                Circle()
                    .trim(from: 0, to: 0.68)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(5)
                Image(systemName: "hourglass")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
            .frame(width: 96, height: 96)
            .shadow(color: Theme.accent.opacity(0.18), radius: 16, y: 8)
            .accessibilityHidden(true)

            EyebrowText("Pro")
            Text("Make time visible")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            Text("A gentle timer you can see, right where you look, so time stops sneaking away.")
                .font(.body)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 16) {
            BenefitRow(symbol: "timer", title: "Visual focus timer",
                       detail: "Watch time pass instead of guessing. Start with just 2 minutes.")
            BenefitRow(symbol: "lock.iphone", title: "On your lock screen",
                       detail: "A Live Activity and Dynamic Island countdown with your current step.")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    @ViewBuilder
    private var plans: some View {
        switch store.loadState {
        case .loaded:
            VStack(spacing: 10) {
                ForEach(store.products, id: \.id) { product in
                    PlanCard(
                        product: product,
                        isSelected: product.id == selectedID,
                        hasTrial: store.trialEligible.contains(product.id)
                    ) {
                        selectedID = product.id
                    }
                }
            }
        case .failed:
            VStack(spacing: 10) {
                Text("Couldn't reach the App Store. Check your connection and try again.")
                    .font(.body)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                SoftButton(title: "Try again") {
                    Task { await store.loadProducts() }
                }
                .frame(width: 180)
            }
            .padding(.vertical, 8)
        case .idle, .loading:
            ProgressView()
                .padding(.vertical, 28)
        }
    }

    private var purchaseBar: some View {
        VStack(spacing: 10) {
            Button {
                buy()
            } label: {
                ZStack {
                    if isWorking {
                        ProgressView().tint(Theme.onAccent)
                    } else {
                        ctaTitle
                    }
                }
                .font(.title3.weight(.bold))
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.primaryButton, style: .continuous))
                .foregroundStyle(Theme.onAccent)
                .shadow(color: Theme.accent.opacity(0.25), radius: 10, y: 8)
            }
            .buttonStyle(.plain)
            .disabled(selected == nil || isWorking)
            .opacity(selected == nil ? 0.5 : 1)

            if let selected {
                finePrint(for: selected)
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }

            if store.canSimulate {
                Button {
                    store.simulatePurchase()
                } label: {
                    Label("Simulate purchase (test builds only)", systemImage: "hammer")
                        .font(.footnote.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                                .strokeBorder(Theme.track, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accent)
                .disabled(isWorking)
            }

            HStack(spacing: 18) {
                Button("Restore purchases") { restore() }
                Link("Terms", destination: Legal.terms)
                Link("Privacy", destination: Legal.privacy)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.inkSoft)
            .disabled(isWorking)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .background(Theme.focusGround.opacity(0.96))
    }

    @ViewBuilder
    private var ctaTitle: some View {
        if let selected, store.trialEligible.contains(selected.id),
           let offer = selected.subscription?.introductoryOffer {
            Text("Try free for \(offer.period.trialLength)")
        } else if selected?.type == .nonConsumable {
            Text("Get Pro forever")
        } else {
            Text("Continue")
        }
    }

    private func finePrint(for product: Product) -> Text {
        let price = product.displayPrice
        if let subscription = product.subscription {
            let period = subscription.subscriptionPeriod.unit == .year ? Text("year") : Text("month")
            if store.trialEligible.contains(product.id), let offer = subscription.introductoryOffer {
                return Text("Free for \(offer.period.trialLength), then \(price) per \(period). Cancel anytime in Settings.")
            }
            return Text("\(price) per \(period). Renews automatically. Cancel anytime in Settings.")
        }
        return Text("One payment of \(price). Yours to keep.")
    }

    private var thankYou: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(Theme.peachInk)
            Text("Welcome to Pro")
                .font(.largeTitle.weight(.bold))
            Text("Thank you. Your focus timer is ready whenever you are.")
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            SoftButton(title: "Let's go") { dismiss() }
                .frame(width: 180)
                .padding(.top, 6)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Actions

    private func buy() {
        guard let product = selected else { return }
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                switch try await store.purchase(product) {
                case .purchased: celebrate()
                case .pending: pendingNotice = true
                case .cancelled: break
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func restore() {
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await store.restore()
                if !store.isPro {
                    errorMessage = String(localized: "We couldn't find an earlier Pro purchase for this Apple ID.")
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func celebrate() {
        thanks = true
    }
}

// MARK: - Components

private struct BenefitRow: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.body.weight(.bold))
                .foregroundStyle(Theme.accent)
                .frame(width: 40, height: 40)
                .background(Theme.currentRow, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.bold))
                Text(detail)
                    .font(.body)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PlanCard: View {
    let product: Product
    let isSelected: Bool
    let hasTrial: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Theme.accent : Theme.checkStroke)
                    .contentTransition(.symbolEffect(.replace))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(name)
                            .font(.body.weight(.bold))
                        if hasTrial, let offer = product.subscription?.introductoryOffer {
                            Text("\(offer.period.trialLength) free")
                                .font(.footnote.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Theme.peach, in: Capsule())
                                .foregroundStyle(Theme.peachInk)
                        }
                    }
                    if let note {
                        note
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(product.displayPrice)
                        .font(.body.weight(.bold))
                    periodLabel
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .padding(16)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent : Color.clear, lineWidth: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.25), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var name: LocalizedStringKey {
        switch product.id {
        case ProProduct.yearly: "Yearly"
        case ProProduct.monthly: "Monthly"
        default: "Lifetime"
        }
    }

    private var note: Text? {
        switch product.id {
        case ProProduct.yearly:
            let perMonth = (product.price / 12).formatted(product.priceFormatStyle)
            return Text("Just \(perMonth) a month")
        case ProProduct.lifetime:
            return Text("Pay once, keep it forever")
        default:
            return nil
        }
    }

    @ViewBuilder
    private var periodLabel: some View {
        switch product.subscription?.subscriptionPeriod.unit {
        case .year: Text("per year")
        case .month: Text("per month")
        case .week: Text("per week")
        case .day: Text("per day")
        default: Text("once")
        }
    }
}

extension Product.SubscriptionPeriod {
    /// "7 days", "1 week", "1 month" for trial copy.
    var trialLength: String {
        switch unit {
        case .day: String(localized: "\(value) days")
        case .week: String(localized: "\(value * 7) days")
        case .month: value == 1 ? String(localized: "1 month") : String(localized: "\(value) months")
        case .year: value == 1 ? String(localized: "1 year") : String(localized: "\(value) years")
        @unknown default: String(localized: "\(value) days")
        }
    }
}
