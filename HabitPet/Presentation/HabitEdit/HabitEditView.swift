import SwiftUI

struct HabitEditView: View {
    @State private var viewModel: HabitEditViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: HabitEditViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    editSection(title: L10n.kindSection) {
                        Picker(
                            L10n.kindTitle,
                            selection: Binding(
                                get: { viewModel.selectedKind },
                                set: { viewModel.onChangeKind($0) }
                            )
                        ) {
                            ForEach(HabitKind.allCases, id: \.self) { kind in
                                Text(kind.title).tag(kind)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    editSection(title: L10n.characterSection) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(viewModel.selectableCharacters, id: \.self) { character in
                                    Button {
                                        viewModel.onChangeCharacter(character)
                                    } label: {
                                        Text(character.title)
                                            .font(.subheadline.weight(.semibold))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(
                                                viewModel.selectedCharacter == character
                                                ? Color.accentColor.opacity(0.2)
                                                : Color(.secondarySystemBackground)
                                            )
                                            .clipShape(.rect(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(character.title)
                                    .accessibilityAddTraits(
                                        viewModel.selectedCharacter == character ? .isSelected : []
                                    )
                                }
                            }
                        }
                    }

                    editSection(title: L10n.nameSection) {
                        TextField(
                            L10n.namePlaceholder,
                            text: Binding(
                                get: { viewModel.nameInput },
                                set: { viewModel.onChangeName($0) }
                            )
                        )
                    }

                    editSection(title: L10n.goalSection) {
                        DatePicker(
                            L10n.goalDeadlineTitle,
                            selection: Binding(
                                get: { viewModel.goalDeadline },
                                set: { viewModel.onChangeGoalDeadline($0) }
                            ),
                            displayedComponents: [.date]
                        )
                        .environment(\.locale, .current)

                        LabeledContent("\(L10n.goalPerDayTitle)（\(viewModel.selectedKind.unitTitle)）") {
                            TextField(
                                "0",
                                text: Binding(
                                    get: { viewModel.goalPerDayInput },
                                    set: { viewModel.onChangeGoalPerDay($0) }
                                )
                            )
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(minWidth: 44)
                        }
                    }

                    if viewModel.editingHabit == nil {
                        yesterdayCountSection(viewModel: viewModel)
                    }

                    if viewModel.editingHabit != nil {
                        editSection {
                            Button(L10n.archiveButton, role: .destructive) {
                                viewModel.isArchiveAlertPresented = true
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
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

@ViewBuilder
private func yesterdayCountSection(viewModel: HabitEditViewModel) -> some View {
    let title = "\(L10n.yesterdayCountTitle)（\(viewModel.selectedKind.unitTitle)）"

    editSection(title: L10n.yesterdaySection, footer: L10n.yesterdayFooter) {
        LabeledContent(title) {
            TextField(
                L10n.yesterdaySimplePlaceholder,
                text: Binding(
                    get: { viewModel.yesterdayCountInput },
                    set: { viewModel.onChangeYesterdayCount($0) }
                )
            )
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .frame(minWidth: 44)
        }
    }
}

@ViewBuilder
private func editSection(
    title: String? = nil,
    footer: String? = nil,
    @ViewBuilder content: () -> some View
) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        if let title {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }

        VStack(alignment: .leading, spacing: 12) {
            content()
        }

        if let footer {
            Text(footer)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(Color(.system))
    .clipShape(.rect(cornerRadius: 8))
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
