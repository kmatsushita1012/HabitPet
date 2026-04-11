import SwiftUI
import UIKit

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
                            HabitPageCard(
                                habit: habit,
                                todayCount: viewModel.todayCount(for: habit.id),
                                totalCount: viewModel.totalCount(for: habit.id),
                                onTapCountUp: { viewModel.onTapCountUp() },
                                onTapUndo: { viewModel.onTapUndoCount() }
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
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
                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        withAnimation(.snappy) {
                            viewModel.onTapPreviousPage()
                        }
                    } label: {
                        Label("前へ", systemImage: "chevron.left")
                    }
                    .disabled(!viewModel.canMoveToPreviousPage)

                    Spacer()

                    Button {
                        withAnimation(.snappy) {
                            viewModel.onTapNextPage()
                        }
                    } label: {
                        Label("次へ", systemImage: "chevron.right")
                    }
                    .disabled(!viewModel.canMoveToNextPage)
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

private struct HabitPageCard: View {
    let habit: Habit
    let todayCount: Int
    let totalCount: Int
    let onTapCountUp: () -> Void
    let onTapUndo: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // MARK: レイアウトは変更しないこと
            HabitCharacterImageView(habit: habit, totalCount: totalCount)
                .aspectRatio(1, contentMode: .fit)
            HStack{
                detailCard
                HabitStatusView(
                    todayCount: todayCount,
                    goalPerDay: habit.goalPerDay,
                    unit: habit.kind.unitTitle
                )
                // TODO: detailCardとHabitStatusViewの内容を統合して整理　より見やすく
            }
            // TODO: 過去の分析を含めた詳細なAnalyticsView
        }

        

        Spacer(minLength: 0)
    }

    @ViewBuilder
    var detailCard: some View {
        HStack{
            VStack(alignment: .leading, spacing: 6) {
                Text(habit.name ?? habit.kind.title)
                    .font(.title2.bold())
                Text(habit.character.title)
                    .foregroundStyle(.secondary)
                Text("種類: \(habit.kind.title)")
                    .foregroundStyle(.secondary)
                Text("今日の記録: \(todayCount)\(habit.kind.unitTitle)")
                    .font(.headline)
                    .monospacedDigit()
                
                HStack(spacing: 12) {
                    Button(action: onTapUndo) {
                        Label("取り消し", systemImage: "arrow.uturn.backward")
                            .labelStyle(.iconOnly)
                    }
                    .tint(.red)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(totalCount == 0)
                    
                    Button(action: onTapCountUp) {
                        Label("記録", systemImage: "plus")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .frame(alignment: .leading)
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            // 過去にわたっての棒グラフなどを追加
            // まだViewの1/2ぐらい余っている
        }
    }
}

private struct HabitStatusView: View {
    let todayCount: Int
    let goalPerDay: Int
    let unit: String

    var body: some View {
        let remaining = max(goalPerDay - todayCount, 0)
        let progress = goalPerDay > 0 ? min(Double(todayCount) / Double(goalPerDay), 1) : 0

        VStack(alignment: .leading, spacing: 6) {
            Text("進捗")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("今日の上限: \(goalPerDay)\(unit)")
                .foregroundStyle(.secondary)
            Text("残り: \(remaining)\(unit)")
                .monospacedDigit()
            ProgressView(value: progress)
                .tint(progress >= 1 ? .red : .accentColor)
                // TODO: もっと太く
        }
        .frame(alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
    }
}

private struct HabitCharacterImageView: View {
    let habit: Habit
    let totalCount: Int

    var body: some View {
    let level = habitStateLevel(forTotalCount: totalCount)
    let names = habitCharacterAssetNames(kind: habit.kind, character: habit.character, level: level)

        Group {
        if let image = AppCharacterImageLoader.load(named: names) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "pawprint.fill")
                .resizable()
                .scaledToFit()
            }
        }
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

#Preview {
    MainPagerView()
}
