import SwiftUI

struct PurchasePaywallSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PurchaseCenterViewModel
    let onPurchaseCompleted: () -> Void

    init(selectedCharacter: CharacterType, onPurchaseCompleted: @escaping () -> Void) {
        _viewModel = State(initialValue: PurchaseCenterViewModel(selectedCharacter: selectedCharacter))
        self.onPurchaseCompleted = onPurchaseCompleted
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            List {
                PurchaseHeaderSection(selectedCharacter: viewModel.selectedCharacter)

                if let singleUnlockProduct = viewModel.singleUnlockProduct,
                   let selectedCharacter = viewModel.selectedCharacter,
                   !viewModel.entitlements.canUse(selectedCharacter) {
                    PurchaseProductRow(
                        title: singleUnlockProduct.title,
                        description: singleUnlockProduct.description,
                        purchaseType: L10n.singleUnlockType,
                        price: singleUnlockProduct.displayPrice,
                        buttonTitle: L10n.singleUnlockButton(selectedCharacter.title)
                    ) {
                        Task {
                            let outcome = await viewModel.purchaseSelectedCharacter()
                            if outcome == .unlocked, viewModel.selectedCharacterIsUnlocked {
                                onPurchaseCompleted()
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isProcessing)
                }

                if let allAccessProduct = viewModel.allAccessProduct, !viewModel.entitlements.allAccessPurchased {
                    PurchaseProductRow(
                        title: allAccessProduct.title,
                        description: allAccessProduct.description,
                        purchaseType: L10n.allAccessType,
                        price: allAccessProduct.displayPrice,
                        buttonTitle: L10n.allAccessButton
                    ) {
                        Task {
                            let outcome = await viewModel.purchaseAllAccess()
                            if outcome == .unlocked, viewModel.selectedCharacterIsUnlocked {
                                onPurchaseCompleted()
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isProcessing)
                }

                PurchaseActionsSection(
                    onTapRestore: {
                        Task {
                            let _ = await viewModel.restorePurchases()
                            if viewModel.selectedCharacterIsUnlocked {
                                onPurchaseCompleted()
                                dismiss()
                            }
                        }
                    },
                    isDisabled: viewModel.isProcessing
                )
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .navigationTitle(L10n.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.closeButton) {
                        dismiss()
                    }
                }
            }
            .alert(L10n.errorTitle, isPresented: .constant(viewModel.errorMessage != nil)) {
                Button(L10n.okButton) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
    }
}

struct PurchaseManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = PurchaseCenterViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            List {
                Section(L10n.managementStatusTitle) {
                    LabeledContent(L10n.allAccessStatusLabel) {
                        Text(viewModel.entitlements.allAccessPurchased ? L10n.enabled : L10n.disabled)
                    }
                    NavigationLink {
                        PurchaseUnlockedCharactersView(
                            purchasedCharacterIDs: viewModel.entitlements.purchasedCharacterIDs
                        )
                    } label: {
                        LabeledContent(L10n.unlockedCharactersLabel) {
                            Text(unlockedCharacterSummary(viewModel.entitlements.purchasedCharacterIDs))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let allAccessProduct = viewModel.allAccessProduct, !viewModel.entitlements.allAccessPurchased {
                    PurchaseProductRow(
                        title: allAccessProduct.title,
                        description: allAccessProduct.description,
                        purchaseType: L10n.allAccessType,
                        price: allAccessProduct.displayPrice,
                        buttonTitle: L10n.allAccessButton
                    ) {
                        Task {
                            _ = await viewModel.purchaseAllAccess()
                        }
                    }
                    .disabled(viewModel.isProcessing)
                }

                PurchaseActionsSection(
                    onTapRestore: {
                        Task {
                            _ = await viewModel.restorePurchases()
                        }
                    },
                    isDisabled: viewModel.isProcessing
                )
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .navigationTitle(L10n.managementTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.closeButton) {
                        dismiss()
                    }
                }
            }
            .alert(L10n.errorTitle, isPresented: .constant(viewModel.errorMessage != nil)) {
                Button(L10n.okButton) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
    }

    private func unlockedCharacterSummary(_ ids: Set<String>) -> String {
        guard !ids.isEmpty else { return L10n.none }
        return L10n.unlockedCharactersCount(ids.count)
    }
}

private struct PurchaseUnlockedCharactersView: View {
    let purchasedCharacterIDs: Set<String>

    private var purchasedCharacterNames: [String] {
        purchasedCharacterIDs
            .map { CharacterType(rawValue: $0)?.title ?? $0 }
            .sorted()
    }

    var body: some View {
        List {
            Section(L10n.unlockedCharactersListTitle) {
                if purchasedCharacterNames.isEmpty {
                    Text(L10n.none)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(purchasedCharacterNames, id: \.self) { name in
                        Text(name)
                    }
                }
            }
        }
        .navigationTitle(L10n.unlockedCharactersDetailTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PurchaseHeaderSection: View {
    let selectedCharacter: CharacterType?

    var body: some View {
        Section {
            Text(L10n.purchaseSummary)
            if let selectedCharacter {
                Text(L10n.selectedCharacter(selectedCharacter.title))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct PurchaseProductRow: View {
    let title: String
    let description: String
    let purchaseType: String
    let price: String
    let buttonTitle: String
    let onTapPurchase: () -> Void

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                LabeledContent(L10n.purchaseTypeLabel) {
                    Text(purchaseType)
                }
                LabeledContent(L10n.priceLabel) {
                    Text(price)
                }
                PurchaseLegalLinksInline()
                Button(buttonTitle, action: onTapPurchase)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

private struct PurchaseActionsSection: View {
    let onTapRestore: () -> Void
    let isDisabled: Bool

    var body: some View {
        Section {
            Button(L10n.restoreButton, action: onTapRestore)
                .disabled(isDisabled)
        }
    }
}

private struct PurchaseLegalLinksInline: View {
    var body: some View {
        HStack(spacing: 16) {
            Link(destination: PurchaseLegalLinks.termsOfUseURL) {
                Text(L10n.termsButton)
                    .font(.footnote)
                    .underline()
                    .foregroundStyle(.secondary)
            }
            Link(destination: PurchaseLegalLinks.privacyPolicyURL) {
                Text(L10n.privacyButton)
                    .font(.footnote)
                    .underline()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 2)
    }
}

private enum L10n {
    static let navigationTitle = String(localized: "purchase.sheet.title", defaultValue: "キャラクター解放")
    static let managementTitle = String(localized: "purchase.management.title", defaultValue: "購入管理")
    static let managementStatusTitle = String(localized: "purchase.management.status", defaultValue: "購入状態")
    static let purchaseSummary = String(localized: "purchase.sheet.summary", defaultValue: "保存前に課金内容をご確認ください。")
    static let purchaseTypeLabel = String(localized: "purchase.sheet.type", defaultValue: "購入タイプ")
    static let priceLabel = String(localized: "purchase.sheet.price", defaultValue: "価格")
    static let singleUnlockType = String(localized: "purchase.sheet.type.single", defaultValue: "消費型（都度購入）")
    static let allAccessType = String(localized: "purchase.sheet.type.all", defaultValue: "買い切り（永続解放）")
    static let allAccessButton = String(localized: "purchase.sheet.button.all", defaultValue: "購入")
    static let restoreButton = String(localized: "purchase.sheet.button.restore", defaultValue: "購入を復元")
    static let closeButton = String(localized: "common.button.close", defaultValue: "閉じる")
    static let errorTitle = String(localized: "common.error.title", defaultValue: "エラー")
    static let okButton = String(localized: "common.button.ok", defaultValue: "OK")
    static let termsButton = String(localized: "purchase.sheet.terms", defaultValue: "利用規約（EULA）")
    static let privacyButton = String(localized: "purchase.sheet.privacy", defaultValue: "プライバシーポリシー")
    static let allAccessStatusLabel = String(localized: "purchase.management.status.all", defaultValue: "全キャラ解放")
    static let unlockedCharactersLabel = String(localized: "purchase.management.status.characters", defaultValue: "個別解放キャラ")
    static let unlockedCharactersListTitle = String(localized: "purchase.management.characters.list", defaultValue: "購入済みキャラクター")
    static let unlockedCharactersDetailTitle = String(localized: "purchase.management.characters.detail_title", defaultValue: "購入済みキャラ一覧")
    static let enabled = String(localized: "common.state.enabled", defaultValue: "有効")
    static let disabled = String(localized: "common.state.disabled", defaultValue: "未購入")
    static let none = String(localized: "common.none", defaultValue: "なし")

    static func singleUnlockButton(_ characterTitle: String) -> String {
        String(localized: "purchase.sheet.button.single", defaultValue: "\(characterTitle)を解放")
    }

    static func selectedCharacter(_ characterTitle: String) -> String {
        String(localized: "purchase.sheet.selected", defaultValue: "選択中: \(characterTitle)")
    }

    static func unlockedCharactersCount(_ count: Int) -> String {
        String(localized: "purchase.management.characters.count", defaultValue: "\(count)件")
    }
}
