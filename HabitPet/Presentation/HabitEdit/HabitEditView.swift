import SwiftUI

struct HabitEditView: View {
    @State var viewModel: HabitEditViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Form {
                Section(L10n.basicSection) {
                    TextField(
                        L10n.habitNamePlaceholder,
                        text: Binding(
                            get: { viewModel.nameInput },
                            set: { viewModel.onChangeName($0) }
                        )
                    )

                    Picker(
                        L10n.modeTitle,
                        selection: Binding(
                            get: { viewModel.selectedMode },
                            set: { viewModel.onChangeMode($0) }
                        )
                    ) {
                        Text(L10n.modeAvoid).tag(HabitMode.avoid)
                        Text(L10n.modeDoMore).tag(HabitMode.doMore)
                    }

                    TextField(
                        L10n.characterIDTitle,
                        text: Binding(
                            get: { viewModel.selectedCharacterID },
                            set: { viewModel.onChangeCharacter($0) }
                        )
                    )
                }

                Section(L10n.goalSection) {
                    TextField(
                        L10n.baselinePlaceholder,
                        text: Binding(
                            get: { viewModel.baselineInput },
                            set: { viewModel.onChangeBaseline($0) }
                        )
                    )
                    .keyboardType(.decimalPad)

                    Picker(
                        L10n.goalTypeTitle,
                        selection: Binding(
                            get: { viewModel.goalType },
                            set: { viewModel.onChangeGoalType($0) }
                        )
                    ) {
                        Text(L10n.goalTypeNone).tag(HabitGoalType.none)
                        Text(L10n.goalTypeCount).tag(HabitGoalType.count)
                        Text(L10n.goalTypeDate).tag(HabitGoalType.date)
                    }

                    switch viewModel.goalType {
                    case .none:
                        Text(L10n.goalTypeNoneDescription)
                            .foregroundStyle(.secondary)
                    case .count:
                        TextField(
                            L10n.goalValuePlaceholder,
                            text: Binding(
                                get: { viewModel.goalValueInput },
                                set: { viewModel.onChangeGoalValue($0) }
                            )
                        )
                        .keyboardType(.numberPad)
                    case .date:
                        DatePicker(
                            L10n.goalDateTitle,
                            selection: Binding(
                                get: { viewModel.goalDate ?? Date() },
                                set: { viewModel.onChangeGoalDate($0) }
                            ),
                            displayedComponents: [.date]
                        )
                    }
                }

                if viewModel.editingHabit != nil {
                    Section {
                        Button(L10n.archiveButton, role: .destructive) {
                            viewModel.isArchiveAlertPresented = true
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
                    .disabled(viewModel.nameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                dismiss()
            }
        }
    }
}

private enum L10n {
    static let basicSection = String(localized: "habit_edit.section.basic", defaultValue: "基本情報")
    static let habitNamePlaceholder = String(localized: "habit_edit.field.name", defaultValue: "習慣名")
    static let modeTitle = String(localized: "habit_edit.field.mode", defaultValue: "モード")
    static let modeAvoid = String(localized: "habit_edit.mode.avoid", defaultValue: "減らしたい")
    static let modeDoMore = String(localized: "habit_edit.mode.do_more", defaultValue: "増やしたい")
    static let characterIDTitle = String(localized: "habit_edit.field.character_id", defaultValue: "キャラクターID")
    static let goalSection = String(localized: "habit_edit.section.goal", defaultValue: "目標")
    static let baselinePlaceholder = String(localized: "habit_edit.field.baseline", defaultValue: "基準値（任意）")
    static let goalTypeTitle = String(localized: "habit_edit.field.goal_type", defaultValue: "目標タイプ")
    static let goalTypeNone = String(localized: "habit_edit.goal_type.none", defaultValue: "なし")
    static let goalTypeCount = String(localized: "habit_edit.goal_type.count", defaultValue: "回数")
    static let goalTypeDate = String(localized: "habit_edit.goal_type.date", defaultValue: "日付")
    static let goalTypeNoneDescription = String(localized: "habit_edit.goal_type.none.description", defaultValue: "目標は設定しません。")
    static let goalValuePlaceholder = String(localized: "habit_edit.field.goal_value", defaultValue: "目標回数")
    static let goalDateTitle = String(localized: "habit_edit.field.goal_date", defaultValue: "目標日")
    static let archiveButton = String(localized: "habit_edit.button.archive", defaultValue: "アーカイブ")
    static let newHabitTitle = String(localized: "habit_edit.title.new", defaultValue: "習慣を追加")
    static let editHabitTitle = String(localized: "habit_edit.title.edit", defaultValue: "習慣を編集")
    static let closeButton = String(localized: "common.button.close", defaultValue: "閉じる")
    static let saveButton = String(localized: "common.button.save", defaultValue: "保存")
    static let archiveAlertTitle = String(localized: "habit_edit.archive.alert.title", defaultValue: "習慣をアーカイブしますか？")
    static let archiveAlertMessage = String(localized: "habit_edit.archive.alert.message", defaultValue: "この習慣はメイン画面から非表示になります。")
    static let cancelButton = String(localized: "common.button.cancel", defaultValue: "キャンセル")
    static let errorTitle = String(localized: "common.error.title", defaultValue: "エラー")
    static let okButton = String(localized: "common.button.ok", defaultValue: "OK")
}

#Preview {
    HabitEditView(viewModel: HabitEditViewModel(habit: nil))
}
