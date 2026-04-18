import Dependencies
import Foundation
import Observation

@MainActor
@Observable
final class PurchaseCenterViewModel {
    enum Outcome: Sendable, Equatable {
        case unlocked
        case pending
        case cancelled
        case failed
    }

    var selectedCharacter: CharacterType?
    var products: [CharacterPurchaseProduct] = []
    var entitlements = CharacterEntitlementState(
        allAccessPurchased: false,
        purchasedCharacterIDs: [],
        remainingSingleUnlockTickets: 0
    )
    var isLoading = false
    var isProcessing = false
    var errorMessage: String?

    @ObservationIgnored
    @Dependency(\.characterPurchaseClient) private var purchaseClient

    init(selectedCharacter: CharacterType? = nil) {
        self.selectedCharacter = selectedCharacter
    }

    var singleUnlockProduct: CharacterPurchaseProduct? {
        products.first(where: { $0.kind == .singleUnlockTicket })
    }

    var allAccessProduct: CharacterPurchaseProduct? {
        products.first(where: { $0.kind == .allAccess })
    }

    var selectedCharacterIsUnlocked: Bool {
        guard let selectedCharacter else { return false }
        return entitlements.canUse(selectedCharacter)
    }

    var remainingSingleUnlockTickets: Int {
        entitlements.remainingSingleUnlockTickets
    }

    var shouldUseTicketForSelectedCharacter: Bool {
        remainingSingleUnlockTickets > 0
    }

    func onAppear() {
        Task {
            await refreshAll()
        }
    }

    func refreshAll() async {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await purchaseClient.loadProducts()
            entitlements = await purchaseClient.refreshEntitlements()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func purchaseSelectedCharacter() async -> Outcome {
        guard let selectedCharacter else { return .failed }
        guard !isProcessing else { return .failed }
        isProcessing = true
        defer { isProcessing = false }

        do {
            let result = try await purchaseClient.purchaseSingleUnlock(for: selectedCharacter)
            entitlements = await purchaseClient.refreshEntitlements()
            return map(result)
        } catch {
            errorMessage = error.localizedDescription
            return .failed
        }
    }

    func purchaseSingleUnlockTicket() async -> Outcome {
        guard !isProcessing else { return .failed }
        isProcessing = true
        defer { isProcessing = false }

        do {
            let result = try await purchaseClient.purchaseSingleUnlockTicket()
            entitlements = await purchaseClient.refreshEntitlements()
            return map(result)
        } catch {
            errorMessage = error.localizedDescription
            return .failed
        }
    }

    func purchaseAllAccess() async -> Outcome {
        guard !isProcessing else { return .failed }
        isProcessing = true
        defer { isProcessing = false }

        do {
            let result = try await purchaseClient.purchaseAllAccess()
            entitlements = await purchaseClient.refreshEntitlements()
            return map(result)
        } catch {
            errorMessage = error.localizedDescription
            return .failed
        }
    }

    func restorePurchases() async -> Outcome {
        guard !isProcessing else { return .failed }
        isProcessing = true
        defer { isProcessing = false }

        do {
            entitlements = try await purchaseClient.restore()
            return .unlocked
        } catch {
            errorMessage = error.localizedDescription
            return .failed
        }
    }

    private func map(_ result: CharacterPurchaseResult) -> Outcome {
        switch result {
        case .success:
            return .unlocked
        case .pending:
            errorMessage = L10n.pendingMessage
            return .pending
        case .cancelled:
            return .cancelled
        }
    }
}

private enum L10n {
    static let pendingMessage = String(
        localized: "purchase.center.pending",
        defaultValue: "購入処理は保留中です。承認後に再度お試しください。"
    )
}
