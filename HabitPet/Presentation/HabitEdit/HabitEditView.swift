import SwiftUI
import UIKit

struct HabitEditView: View {
    @State private var viewModel: HabitEditViewModel
    @Environment(\.dismiss) private var dismiss
    private let onComplete: ((HabitEditViewModel.CompletionResult) -> Void)?

    init(
        viewModel: HabitEditViewModel,
        onComplete: ((HabitEditViewModel.CompletionResult) -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onComplete = onComplete
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Form {
                HabitKindSection(
                    selectedKind: viewModel.selectedKind,
                    onChangeKind: { viewModel.onChangeKind($0) }
                )

                HabitCharacterSection(
                    selectedKind: viewModel.selectedKind,
                    selectedCharacter: viewModel.selectedCharacter,
                    selectableCharacters: viewModel.selectableCharacters,
                    onChangeCharacter: { viewModel.onChangeCharacter($0) }
                )

                HabitNameSection(
                    nameInput: viewModel.nameInput,
                    onChangeName: { viewModel.onChangeName($0) }
                )

                HabitGoalSection(
                    selectedKind: viewModel.selectedKind,
                    goalDeadline: viewModel.goalDeadline,
                    goalPerDayInput: viewModel.goalPerDayInput,
                    onChangeGoalDeadline: { viewModel.onChangeGoalDeadline($0) },
                    onChangeGoalPerDay: { viewModel.onChangeGoalPerDay($0) }
                )

                if viewModel.editingHabit == nil {
                    HabitYesterdaySection(
                        selectedKind: viewModel.selectedKind,
                        yesterdayCountInput: viewModel.yesterdayCountInput,
                        onChangeYesterdayCount: { viewModel.onChangeYesterdayCount($0) }
                    )
                }

                if viewModel.editingHabit != nil {
                    Section {
                        if FeatureFlags.habitLifecycleActionsEnabled {
                            Button(L10n.archiveButton, role: .destructive) {
                                viewModel.isArchiveAlertPresented = true
                            }
                        }

                        Button(L10n.deleteButton, role: .destructive) {
                            viewModel.isDeleteAlertPresented = true
                        }
                    }
                }
            }
            .navigationTitle(viewModel.editingHabit == nil ? L10n.newHabitTitle : L10n.editHabitTitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(L10n.closeButton)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.onTapSave()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel(L10n.saveButton)
                    .buttonStyle(.borderedProminent)
                }
            }
            .alert(L10n.archiveAlertTitle, isPresented: $viewModel.isArchiveAlertPresented) {
                Button(L10n.archiveButton, role: .destructive) {
                    viewModel.onTapArchive()
                }
                Button(L10n.cancelButton, role: .cancel) {}
            } message: {
                Text(L10n.archiveAlertMessage)
            }
            .alert(L10n.deleteAlertTitle, isPresented: $viewModel.isDeleteAlertPresented) {
                Button(L10n.deleteButton, role: .destructive) {
                    viewModel.onTapDelete()
                }
                Button(L10n.cancelButton, role: .cancel) {}
            } message: {
                Text(L10n.deleteAlertMessage)
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
            viewModel.onAppearForCreate()
        }
        .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss {
                if let completionResult = viewModel.completionResult {
                    onComplete?(completionResult)
                }
                dismiss()
            }
        }
    }
}

private struct HabitKindSection: View {
    let selectedKind: HabitKind
    let onChangeKind: (HabitKind) -> Void

    var body: some View {
        Section(L10n.kindSection) {
            Picker(
                L10n.kindTitle,
                selection: Binding(get: { selectedKind }, set: onChangeKind)
            ) {
                ForEach(HabitKind.selectableKinds(including: selectedKind), id: \.self) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.menu)
        }
    }
}

private struct HabitCharacterSection: View {
    let selectedKind: HabitKind
    let selectedCharacter: CharacterType
    let selectableCharacters: [CharacterType]
    let onChangeCharacter: (CharacterType) -> Void

    var body: some View {
        Section(L10n.characterSection) {
            CharacterPreviewImageView(kind: selectedKind, character: selectedCharacter)

            Picker(
                L10n.characterSection,
                selection: Binding(
                    get: { selectedCharacter.rawValue },
                    set: { rawValue in
                        if let character = CharacterType(rawValue: rawValue) {
                            onChangeCharacter(character)
                        }
                    }
                )
            ) {
                ForEach(selectableCharacters, id: \.rawValue) { character in
                    Text(character.title).tag(character.rawValue)
                }
            }
        }
    }
}

private struct HabitNameSection: View {
    let nameInput: String
    let onChangeName: (String) -> Void

    var body: some View {
        Section(L10n.nameSection) {
            TextField(
                L10n.namePlaceholder,
                text: Binding(get: { nameInput }, set: onChangeName)
            )
        }
    }
}

private struct HabitGoalSection: View {
    let selectedKind: HabitKind
    let goalDeadline: Date
    let goalPerDayInput: String
    let onChangeGoalDeadline: (Date) -> Void
    let onChangeGoalPerDay: (String) -> Void

    var body: some View {
        Section(L10n.goalSection) {
            DatePicker(
                L10n.goalDeadlineTitle,
                selection: Binding(get: { goalDeadline }, set: onChangeGoalDeadline),
                displayedComponents: [.date]
            )

            LabeledContent("\(L10n.goalPerDayTitle)（\(selectedKind.unitTitle)）") {
                TextField(
                    "0",
                    text: Binding(get: { goalPerDayInput }, set: onChangeGoalPerDay)
                )
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 44)
            }
        }
    }
}

private struct HabitYesterdaySection: View {
    let selectedKind: HabitKind
    let yesterdayCountInput: String
    let onChangeYesterdayCount: (String) -> Void

    var body: some View {
        Section {
            LabeledContent("\(L10n.yesterdayCountTitle)（\(selectedKind.unitTitle)）") {
                TextField(
                    L10n.yesterdaySimplePlaceholder,
                    text: Binding(get: { yesterdayCountInput }, set: onChangeYesterdayCount)
                )
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 44)
            }
        } header: {
            Text(L10n.yesterdaySection)
        } footer: {
            Text(L10n.yesterdayFooter)
        }
    }
}

private struct CharacterPreviewImageView: View {
    let kind: HabitKind
    let character: CharacterType

    var body: some View {
        let names = habitCharacterAssetNames(kind: kind, character: character, level: 1)
        let previewWidth: CGFloat = 128
        let previewHeight: CGFloat = 96

        HStack {
            Spacer(minLength: 0)
            ZStack {
                if let image = AppCharacterImageLoader.load(named: names) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "pawprint.fill")
                        .resizable()
                        .scaledToFill()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: previewWidth, height: previewHeight)
            .background(
                Color(uiColor: .secondarySystemBackground),
                in: .rect(cornerRadius: 8, style: .continuous)
            )
            .clipShape(.rect(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            )
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}

private enum AppCharacterImageLoader {
    static func load(named names: [String]) -> UIImage? {
        for name in names {
            if let image = UIImage(named: name, in: .main, compatibleWith: nil) {
                return image
            }
        }
        return nil
    }
}

private enum L10n {
    static let kindSection = String(localized: "habit_edit.section.kind", defaultValue: "種類")
    static let kindTitle = String(localized: "habit_edit.field.kind", defaultValue: "種類")
    static let characterSection = String(localized: "habit_edit.section.character", defaultValue: "キャラクター")
    static let nameSection = String(localized: "habit_edit.section.name", defaultValue: "習慣名（任意）")
    static let namePlaceholder = String(localized: "habit_edit.field.name", defaultValue: "タイトル（例: 夜の1本をやめる）")
    static let goalSection = String(localized: "habit_edit.section.goal", defaultValue: "目標")
    static let goalDeadlineTitle = String(localized: "habit_edit.field.goal_deadline", defaultValue: "何日まで")
    static let goalPerDayTitle = String(localized: "habit_edit.field.goal_per_day", defaultValue: "1日あたり上限")
    static let yesterdaySection = String(localized: "habit_edit.section.yesterday", defaultValue: "昨日の記録")
    static let yesterdayCountTitle = String(localized: "habit_edit.field.yesterday_count", defaultValue: "昨日の記録")
    static let yesterdaySimplePlaceholder = String(localized: "habit_edit.field.yesterday_simple", defaultValue: "入力")
    static let yesterdayFooter = String(localized: "habit_edit.field.yesterday_footer", defaultValue: "保存時に「昨日」のイベントとして登録されます。")
    static let archiveButton = String(localized: "habit_edit.button.archive", defaultValue: "アーカイブ")
    static let deleteButton = String(localized: "habit_edit.button.delete", defaultValue: "削除")
    static let newHabitTitle = String(localized: "habit_edit.title.new", defaultValue: "習慣を追加")
    static let editHabitTitle = String(localized: "habit_edit.title.edit", defaultValue: "習慣を編集")
    static let closeButton = String(localized: "common.button.close", defaultValue: "閉じる")
    static let saveButton = String(localized: "common.button.save", defaultValue: "保存")
    static let archiveAlertTitle = String(localized: "habit_edit.archive.alert.title", defaultValue: "習慣をアーカイブしますか？")
    static let archiveAlertMessage = String(localized: "habit_edit.archive.alert.message", defaultValue: "この習慣はメイン画面から非表示になります。")
    static let deleteAlertTitle = String(localized: "habit_edit.delete.alert.title", defaultValue: "習慣を削除しますか？")
    static let deleteAlertMessage = String(localized: "habit_edit.delete.alert.message", defaultValue: "この操作は元に戻せません。")
    static let cancelButton = String(localized: "common.button.cancel", defaultValue: "キャンセル")
    static let errorTitle = String(localized: "common.error.title", defaultValue: "エラー")
    static let okButton = String(localized: "common.button.ok", defaultValue: "OK")
}

private enum FeatureFlags {
    // アーカイブ一覧画面を追加するまで非表示にしておく
    static let habitLifecycleActionsEnabled = false
}

#Preview {
    HabitEditView(viewModel: HabitEditViewModel(habit: nil))
}
