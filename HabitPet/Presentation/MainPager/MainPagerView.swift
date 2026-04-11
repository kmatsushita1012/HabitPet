import SwiftUI

struct MainPagerView: View {
    @State private var viewModel = MainPagerViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Group {
                if viewModel.habits.isEmpty {
                    ContentUnavailableView(
                        "習慣がまだありません",
                        systemImage: "pawprint",
                        description: Text("右上の + から最初の習慣を作成してください。")
                    )
                } else {
                    TabView(selection: $viewModel.selectedPageIndex) {
                        ForEach(Array(viewModel.habits.enumerated()), id: \.element.id) { index, habit in
                            let totalCount = viewModel.totalCount(for: habit.id)
                            VStack(spacing: 12) {
                                Image("character_\(habit.characterID)_lv\(habitStateLevel(forTotalCount: totalCount))")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 120, height: 120)

                                Text(habit.name)
                                    .font(.title2.bold())
                                Text("キャラクター: \(habit.characterID)")
                                    .foregroundStyle(.secondary)

                                Text("クイック記録（総和）: \(totalCount)")
                                    .font(.headline)
                                    .monospacedDigit()

                                HStack(spacing: 12) {
                                    Button {
                                        viewModel.onTapCountUp()
                                    } label: {
                                        Label("+1 記録", systemImage: "plus.circle.fill")
                                    }
                                    .buttonStyle(.borderedProminent)

                                    Button {
                                        viewModel.onTapUndoCount()
                                    } label: {
                                        Label("取り消し", systemImage: "arrow.uturn.backward.circle")
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(totalCount == 0)
                                }
                            }
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .onChange(of: viewModel.selectedPageIndex) { _, newValue in
                        viewModel.onPageChanged(newValue)
                    }
                }
            }
            .navigationTitle("HabitPet")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.onTapEdit()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel(String(localized: "main_pager.button.edit", defaultValue: "編集"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.onTapAddPage()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(String(localized: "main_pager.button.add", defaultValue: "追加"))
                }
            }
            .alert("エラー", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            viewModel.onAppDidBecomeActive()
        }
        .sheet(
            isPresented: $viewModel.isCreatePresented,
            onDismiss: { viewModel.onDismissCreate() }
        ) {
            HabitEditView(viewModel: HabitEditViewModel(habit: nil))
        }
        .sheet(
            isPresented: $viewModel.isEditPresented,
            onDismiss: { viewModel.onDismissEdit() }
        ) {
            if let habit = viewModel.editingHabit {
                HabitEditView(viewModel: HabitEditViewModel(habit: habit))
            } else {
                ContentUnavailableView("編集対象が見つかりません", systemImage: "exclamationmark.circle")
            }
        }
    }
}

#Preview {
    MainPagerView()
}
