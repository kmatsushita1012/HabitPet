import SwiftUI

struct HabitEditView: View {
    @State var viewModel: HabitEditViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Form {
                Section("Basic") {
                    TextField(
                        "Habit name",
                        text: Binding(
                            get: { viewModel.nameInput },
                            set: { viewModel.onChangeName($0) }
                        )
                    )

                    Picker(
                        "Mode",
                        selection: Binding(
                            get: { viewModel.selectedMode },
                            set: { viewModel.onChangeMode($0) }
                        )
                    ) {
                        Text("Avoid").tag(HabitMode.avoid)
                        Text("Do More").tag(HabitMode.doMore)
                    }

                    TextField(
                        "Character ID",
                        text: Binding(
                            get: { viewModel.selectedCharacterID },
                            set: { viewModel.onChangeCharacter($0) }
                        )
                    )
                }

                Section("Goal") {
                    TextField(
                        "Baseline (optional)",
                        text: Binding(
                            get: { viewModel.baselineInput },
                            set: { viewModel.onChangeBaseline($0) }
                        )
                    )
                    .keyboardType(.decimalPad)

                    Picker(
                        "Goal Type",
                        selection: Binding(
                            get: { viewModel.goalType },
                            set: { viewModel.onChangeGoalType($0) }
                        )
                    ) {
                        Text("None").tag(HabitGoalType.none)
                        Text("Count").tag(HabitGoalType.count)
                        Text("Date").tag(HabitGoalType.date)
                    }

                    TextField(
                        "Goal Value (optional)",
                        text: Binding(
                            get: { viewModel.goalValueInput },
                            set: { viewModel.onChangeGoalValue($0) }
                        )
                    )
                    .keyboardType(.numberPad)

                    DatePicker(
                        "Goal Date",
                        selection: Binding(
                            get: { viewModel.goalDate ?? Date() },
                            set: { viewModel.onChangeGoalDate($0) }
                        ),
                        displayedComponents: [.date]
                    )
                }

                if viewModel.editingHabit != nil {
                    Section {
                        Button("Archive", role: .destructive) {
                            viewModel.isArchiveAlertPresented = true
                        }
                    }
                }
            }
            .navigationTitle(viewModel.editingHabit == nil ? "New Habit" : "Edit Habit")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        viewModel.onTapSave()
                    }
                    .disabled(viewModel.nameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Archive Habit?", isPresented: $viewModel.isArchiveAlertPresented) {
                Button("Archive", role: .destructive) {
                    viewModel.onTapArchive()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This habit will be hidden from the main pager.")
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
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

#Preview {
    HabitEditView(viewModel: HabitEditViewModel(habit: nil))
}
