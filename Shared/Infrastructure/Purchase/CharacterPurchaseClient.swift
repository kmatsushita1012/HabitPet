import Dependencies
import Foundation
import StoreKit

struct CharacterEntitlementState: Sendable, Equatable {
    var allAccessPurchased: Bool
    var purchasedCharacterIDs: Set<String>

    func canUse(_ character: CharacterType) -> Bool {
        if character.isDefaultFree { return true }
        if allAccessPurchased { return true }
        return purchasedCharacterIDs.contains(character.rawValue)
    }
}

enum CharacterPurchaseResult: Sendable, Equatable {
    case success
    case pending
    case cancelled
}

enum CharacterPurchaseError: LocalizedError {
    case productNotFound
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "商品情報の取得に失敗しました。時間をおいて再度お試しください。"
        case .verificationFailed:
            return "購入確認に失敗しました。"
        }
    }
}

protocol CharacterPurchaseClientProtocol: Sendable {
    func entitlements() async -> CharacterEntitlementState
    func refreshEntitlements() async -> CharacterEntitlementState
    func purchaseSingleUnlock(for character: CharacterType) async throws -> CharacterPurchaseResult
    func purchaseAllAccess() async throws -> CharacterPurchaseResult
    func restore() async throws -> CharacterEntitlementState
}

struct CharacterPurchaseClient: CharacterPurchaseClientProtocol, Sendable {
    private enum ProductID {
        static let singleUnlockTicket = "habitpet.character.unlock.ticket"
        static let allAccess = "habitpet.characters.all_access"
    }

    private enum DefaultsKey {
        static let purchasedCharacters = "iap.purchasedCharacterIDs"
        static let allAccess = "iap.allAccessPurchased"
    }

    func entitlements() async -> CharacterEntitlementState {
        CharacterEntitlementState(
            allAccessPurchased: UserDefaults.standard.bool(forKey: DefaultsKey.allAccess),
            purchasedCharacterIDs: purchasedCharacterIDs()
        )
    }

    func refreshEntitlements() async -> CharacterEntitlementState {
        var allAccessPurchased = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == ProductID.allAccess, transaction.revocationDate == nil {
                allAccessPurchased = true
            }
        }

        UserDefaults.standard.set(allAccessPurchased, forKey: DefaultsKey.allAccess)

        return CharacterEntitlementState(
            allAccessPurchased: allAccessPurchased,
            purchasedCharacterIDs: purchasedCharacterIDs()
        )
    }

    func purchaseSingleUnlock(for character: CharacterType) async throws -> CharacterPurchaseResult {
        if character.isDefaultFree {
            return .success
        }

        let product = try await loadProduct(id: ProductID.singleUnlockTicket)
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                throw CharacterPurchaseError.verificationFailed
            }
            await transaction.finish()
            persistPurchasedCharacterID(character.rawValue)
            return .success
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    func purchaseAllAccess() async throws -> CharacterPurchaseResult {
        let product = try await loadProduct(id: ProductID.allAccess)
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                throw CharacterPurchaseError.verificationFailed
            }
            await transaction.finish()
            UserDefaults.standard.set(true, forKey: DefaultsKey.allAccess)
            return .success
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    func restore() async throws -> CharacterEntitlementState {
        try await AppStore.sync()
        return await refreshEntitlements()
    }

    private func loadProduct(id: String) async throws -> Product {
        let products = try await Product.products(for: [id])
        guard let product = products.first else {
            throw CharacterPurchaseError.productNotFound
        }
        return product
    }

    private func purchasedCharacterIDs() -> Set<String> {
        let rawValues = UserDefaults.standard.stringArray(forKey: DefaultsKey.purchasedCharacters) ?? []
        return Set(rawValues)
    }

    private func persistPurchasedCharacterID(_ rawValue: String) {
        var ids = purchasedCharacterIDs()
        ids.insert(rawValue)
        UserDefaults.standard.set(Array(ids), forKey: DefaultsKey.purchasedCharacters)
    }
}

private enum CharacterPurchaseClientKey: DependencyKey {
    static let liveValue: any CharacterPurchaseClientProtocol = CharacterPurchaseClient()
}

extension DependencyValues {
    var characterPurchaseClient: any CharacterPurchaseClientProtocol {
        get { self[CharacterPurchaseClientKey.self] }
        set { self[CharacterPurchaseClientKey.self] = newValue }
    }
}
