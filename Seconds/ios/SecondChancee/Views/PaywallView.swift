import SwiftUI
import RevenueCat
import StoreKit

struct PaywallView: View {
    let appState: AppState
    let onSuccess: () -> Void

    @Environment(\.openURL) private var openURL

    @State private var offerings: Offerings?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showOfferingsSetupHelp = false
    @State private var isPurchasing = false
    @State private var selectedPackage: Package?

    /// Prefer RevenueCat’s current offering; fall back to any offering with packages.
    private var activeOffering: Offering? {
        Self.resolveActiveOffering(from: offerings)
    }

    private static func resolveActiveOffering(from offerings: Offerings?) -> Offering? {
        guard let o = offerings else { return nil }
        if let current = o.current, !current.availablePackages.isEmpty {
            return current
        }
        return o.all.values.first { !$0.availablePackages.isEmpty } ?? o.all.values.first
    }

    private var paywallBackground: Color {
        Color(red: 0.10, green: 0.086, blue: 0.078)
    }

    var body: some View {
        ZStack {
            paywallBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 28)

                    headlineBlock
                        .padding(.horizontal, 24)
                        .padding(.bottom, 36)

                    featureSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)

                    subscriptionSection
                        .padding(.horizontal, 20)

                    if let errorMessage {
                        VStack(spacing: 10) {
                            Text(errorMessage)
                                .foregroundStyle(AppTheme.subtleGray)
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                            if showOfferingsSetupHelp {
                                Button("Learn how to fix this") {
                                    if let url = URL(string: "https://rev.cat/why-are-offerings-empty") {
                                        openURL(url)
                                    }
                                }
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(AppTheme.terracotta)
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 14)
                    }

                    ctaButton
                        .padding(.horizontal, 20)
                        .padding(.top, 28)

                    footerLinks
                        .padding(.top, 28)
                        .padding(.bottom, 40)
                }
            }
        }
        .task {
            await loadOfferings()
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        Text("SECOND CHANCE")
            .font(.system(size: 11, weight: .semibold, design: .serif))
            .tracking(3.2)
            .foregroundStyle(AppTheme.terracotta)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Headline

    private var headlineBlock: some View {
        VStack(spacing: 18) {
            Text("Unlock Your Sanctuary")
                .font(.system(size: 32, weight: .regular, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.warmWhite)
                .fixedSize(horizontal: false, vertical: true)

            Text("To maintain this private, ad-free space for your recovery journey, we require a subscription for full access to all features.")
                .font(.system(size: 16, weight: .regular, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.warmWhite.opacity(0.92))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Features

    private var featureSection: some View {
        VStack(spacing: 12) {
            PaywallFeatureCard(
                icon: "book.fill",
                title: "FULL JOURNAL & TOOLS",
                subtitle: "Unlimited access to journaling, analysis, and your recovery data"
            )
            PaywallFeatureCard(
                icon: "chart.line.uptrend.xyaxis",
                title: "ADVANCED JOURNEY ANALYSIS",
                subtitle: "Deeper insights into your check-ins"
            )
            PaywallFeatureCard(
                icon: "person.3.fill",
                title: "COMMUNITY SUPPORT",
                subtitle: "Help keep our collective sanctuary thriving."
            )
        }
    }

    // MARK: - Packages

    @ViewBuilder
    private var subscriptionSection: some View {
        if isLoading {
            ProgressView()
                .tint(AppTheme.terracotta)
                .padding(.vertical, 36)
        } else if let offering = activeOffering, !offering.availablePackages.isEmpty {
            let subs = offering.availablePackages.filter { !PaywallPackageHelpers.isLifetime($0) }
            let lifes = offering.availablePackages.filter { PaywallPackageHelpers.isLifetime($0) }

            VStack(spacing: 14) {
                ForEach(subs, id: \.identifier) { package in
                    let copy = PaywallPackageHelpers.paywallCopy(for: package)
                    PaywallPricingCard(
                        package: package,
                        label: copy.label,
                        periodSuffix: copy.periodSuffix,
                        isYearlyStyle: PaywallPackageHelpers.isYearlyHighlight(package),
                        isSelected: selectedPackage?.identifier == package.identifier
                    ) {
                        selectedPackage = package
                    }
                }

                ForEach(lifes, id: \.identifier) { package in
                    lifetimeRow(package: package)
                }
            }
        } else if offerings != nil {
            // Loaded but no packages (misconfigured RevenueCat / StoreKit)
            Text("No subscription products are available yet. Configure offerings and products in RevenueCat and App Store Connect, then try again.")
                .font(.footnote)
                .foregroundStyle(AppTheme.subtleGray)
                .multilineTextAlignment(.center)
                .padding(.vertical, 8)
        } else {
            // Failed before load or still no data — show design placeholders (non-purchasable)
            VStack(spacing: 14) {
                PaywallPlaceholderCard(
                    label: "MONTHLY SUPPORT",
                    price: "$4.99",
                    period: "/month",
                    isYearlyStyle: false,
                    badge: nil
                )
                PaywallPlaceholderCard(
                    label: "YEARLY SANCTUARY",
                    price: "$39.99",
                    period: "/year",
                    isYearlyStyle: true,
                    badge: "MOST SUSTAINABLE"
                )
                Text(AttributedString.buildLifetimeLine(price: "$149"))
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
            }
        }
    }

    private func lifetimeRow(package: Package) -> some View {
        Button {
            selectedPackage = package
        } label: {
            Text(AttributedString.buildLifetimeLine(price: package.localizedPriceString))
                .font(.system(size: 14, weight: .regular, design: .serif))
                .multilineTextAlignment(.center)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(selectedPackage?.identifier == package.identifier ? AppTheme.terracotta.opacity(0.12) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button {
            purchaseTapped()
        } label: {
            Group {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("GET FULL ACCESS")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Color.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(AppTheme.terracotta)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isPurchasing)
    }

    private func defaultPackageForPurchase() -> Package? {
        guard let offering = activeOffering else { return nil }
        let packages = offering.availablePackages
        return packages.first(where: { PaywallPackageHelpers.isYearlyHighlight($0) })
            ?? packages.first(where: { $0.packageType == .monthly })
            ?? packages.first
    }

    private func purchaseTapped() {
        guard let offering = activeOffering, !offering.availablePackages.isEmpty else {
            errorMessage = PaywallCopy.unavailableShort
            showOfferingsSetupHelp = true
            return
        }
        guard let pkg = selectedPackage ?? defaultPackageForPurchase() else {
            errorMessage = "Could not determine a subscription package."
            showOfferingsSetupHelp = false
            return
        }
        purchase(package: pkg)
    }

    private var footerLinks: some View {
        HStack(spacing: 0) {
            Button("RESTORE PURCHASE") {
                restore()
            }
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(AppTheme.subtleGray)

            Spacer()

            Button("PRIVACY POLICY") {
                if let url = URL(string: "https://secondchance.app/privacy") {
                    openURL(url)
                }
            }
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(AppTheme.subtleGray)
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Actions

    private func loadOfferings() async {
        isLoading = true
        errorMessage = nil
        showOfferingsSetupHelp = false
        defer { isLoading = false }
        do {
            let loaded = try await SubscriptionService.shared.fetchOfferings()
            offerings = loaded
            if let offering = Self.resolveActiveOffering(from: loaded) {
                selectedPackage = offering.availablePackages.first(where: { PaywallPackageHelpers.isYearlyHighlight($0) })
                    ?? offering.availablePackages.first(where: { $0.packageType == .monthly })
                    ?? offering.availablePackages.first
            }
        } catch {
            offerings = nil
            errorMessage = PaywallCopy.offeringsLoadFailed
            showOfferingsSetupHelp = true
        }
    }

    private func purchase(package: Package) {
        isPurchasing = true
        errorMessage = nil
        showOfferingsSetupHelp = false
        Task { @MainActor in
            defer { isPurchasing = false }
            do {
                try await SubscriptionService.shared.purchase(package: package)
                if await SubscriptionService.shared.isEntitlementActiveInRevenueCat() {
                    await SubscriptionService.shared.syncSubscriptionStatus(appState: appState)
                    let unlocked = SubscriptionService.shared.isSubscribed || appState.currentUser?.isSubscribed == true
                    if unlocked {
                        onSuccess()
                    } else {
                        errorMessage = "Could not save premium status to your account. Check your connection and try again."
                    }
                } else {
                    errorMessage = "Purchase completed but premium access wasn’t unlocked. Try Restore, or check the “\(SubscriptionService.entitlementIdentifier)” entitlement in RevenueCat."
                    showOfferingsSetupHelp = false
                }
            } catch {
                errorMessage = Self.friendlyPurchaseError(error)
                showOfferingsSetupHelp = false
            }
        }
    }

    private func restore() {
        isPurchasing = true
        errorMessage = nil
        showOfferingsSetupHelp = false
        Task { @MainActor in
            defer { isPurchasing = false }
            do {
                try await SubscriptionService.shared.restorePurchases()
                await SubscriptionService.shared.syncSubscriptionStatus(appState: appState)
                let unlocked = SubscriptionService.shared.isSubscribed || appState.currentUser?.isSubscribed == true
                if unlocked {
                    onSuccess()
                } else {
                    errorMessage = "No active subscription found."
                }
            } catch {
                errorMessage = Self.friendlyPurchaseError(error)
            }
        }
    }

    private static func friendlyPurchaseError(_ error: Error) -> String {
        if let sk = error as? SKError {
            switch sk.code {
            case .paymentCancelled:
                return "Purchase was cancelled."
            case .paymentNotAllowed:
                return "Purchases aren’t allowed on this device."
            case .storeProductNotAvailable:
                return "This product isn’t available right now."
            default:
                break
            }
        }
        if let ns = error as NSError?, let underlying = ns.userInfo[NSUnderlyingErrorKey] as? Error {
            return friendlyPurchaseError(underlying)
        }
        let d = error.localizedDescription
        if d.count > 160 {
            return "Something went wrong. Please try again."
        }
        return d
    }
}

// MARK: - Copy

private enum PaywallCopy {
    /// Shown when RevenueCat can’t fetch products (App Store Connect / RevenueCat mismatch).
    static let offeringsLoadFailed =
        "We couldn’t load real prices from the App Store. Add your subscription products in App Store Connect, link them in RevenueCat, and wait until they’re ready to test."

    static let unavailableShort =
        "Subscription options aren’t available yet. Connect products in App Store Connect and RevenueCat first."
}

// MARK: - RevenueCat package helpers (custom packages often don’t match PackageType.monthly / .annual)

private enum PaywallPackageHelpers {
    static func isLifetime(_ p: Package) -> Bool {
        if p.packageType == .lifetime { return true }
        let id = p.identifier.lowercased()
        return id.contains("lifetime") || id.contains("life_time") || id.contains("life-time")
    }

    static func isYearlyHighlight(_ p: Package) -> Bool {
        if p.packageType == .annual { return true }
        let id = p.identifier.lowercased()
        return id.contains("annual") || id.contains("year") || id.contains("yearly")
    }

    static func paywallCopy(for p: Package) -> (label: String, periodSuffix: String) {
        switch p.packageType {
        case .monthly:
            return ("MONTHLY SUPPORT", "/month")
        case .annual:
            return ("YEARLY SANCTUARY", "/year")
        case .weekly:
            return ("WEEKLY SUPPORT", "/week")
        case .sixMonth:
            return ("6-MONTH SUPPORT", "/6 mo")
        case .threeMonth:
            return ("3-MONTH SUPPORT", "/3 mo")
        case .twoMonth:
            return ("2-MONTH SUPPORT", "/2 mo")
        default:
            let id = p.identifier.lowercased()
            if id.contains("month") { return ("MONTHLY SUPPORT", "/month") }
            if id.contains("annual") || id.contains("year") || id.contains("yearly") {
                return ("YEARLY SANCTUARY", "/year")
            }
            if id.contains("week") { return ("WEEKLY SUPPORT", "/week") }
            let title = p.storeProduct.localizedTitle
            if title.isEmpty {
                return ("SUBSCRIPTION", "")
            }
            return (title.uppercased(), "")
        }
    }
}

// MARK: - Feature row

private struct PaywallFeatureCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(AppTheme.terracotta)
                .frame(width: 3)
                .padding(.vertical, 14)
                .padding(.leading, 0)

            HStack(alignment: .center, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(AppTheme.terracotta)
                    .frame(width: 28, alignment: .center)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(AppTheme.warmWhite)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(AppTheme.terracotta.opacity(0.95))
                }

                Spacer(minLength: 0)
            }
            .padding(.leading, 14)
            .padding(.trailing, 18)
            .padding(.vertical, 16)
        }
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Pricing cards

private struct PaywallPricingCard: View {
    let package: Package
    let label: String
    let periodSuffix: String
    let isYearlyStyle: Bool
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(AppTheme.subtleGray)

                    HStack(alignment: .lastTextBaseline, spacing: 5) {
                        Text(package.localizedPriceString)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(AppTheme.warmWhite)
                        Text(periodSuffix)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(AppTheme.subtleGray)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(borderColor, lineWidth: borderWidth)
                )

                if isYearlyStyle {
                    Text("MOST SUSTAINABLE")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.terracotta)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .offset(x: -12, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var borderColor: Color {
        if isSelected {
            return AppTheme.terracotta.opacity(0.92)
        }
        return Color.white.opacity(0.10)
    }

    private var borderWidth: CGFloat {
        isSelected ? 2.25 : 1
    }
}

private struct PaywallPlaceholderCard: View {
    let label: String
    let price: String
    let period: String
    let isYearlyStyle: Bool
    let badge: String?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(AppTheme.subtleGray)

                HStack(alignment: .lastTextBaseline, spacing: 5) {
                    Text(price)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AppTheme.warmWhite)
                    Text(period)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(AppTheme.subtleGray)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )

            if let badge {
                Text(badge)
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.terracotta)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .offset(x: -12, y: -8)
            }
        }
    }
}

// MARK: - Attributed string helper

private extension AttributedString {
    static func buildLifetimeLine(price: String) -> AttributedString {
        var base = AttributedString("Lifetime Access for ")
        base.foregroundColor = AppTheme.subtleGray
        var pricePart = AttributedString(price)
        pricePart.foregroundColor = AppTheme.warmWhite
        pricePart.font = .system(size: 14, weight: .semibold, design: .serif)
        base.append(pricePart)
        return base
    }
}
