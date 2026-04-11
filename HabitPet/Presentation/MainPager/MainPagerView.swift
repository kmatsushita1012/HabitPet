import Charts
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
                                totalCount: viewModel.totalCount(for: habit.id),
                                todayCount: viewModel.todayCount(for: habit.id),
                                goalTimelineStatus: viewModel.goalTimelineStatus(for: habit),
                                recentDailySeries: viewModel.recentDailyCounts(for: habit.id, days: 14),
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
    let totalCount: Int
    let todayCount: Int
    let goalTimelineStatus: MainPagerViewModel.GoalTimelineStatus
    let recentDailySeries: [MainPagerViewModel.DailyCountPoint]
    let onTapCountUp: () -> Void
    let onTapUndo: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                HabitCharacterImageView(habit: habit, totalCount: totalCount)
                HabitOverallStatusCard(habit: habit, timelineStatus: goalTimelineStatus)
            }
            
            HabitTodayStatusCard(
                todayCount: todayCount,
                goalPerDay: habit.goalPerDay,
                unit: habit.kind.unitTitle,
                onTapCountUp: onTapCountUp,
                onTapUndo: onTapUndo
            )
            HabitHistoryChartCard(unit: habit.kind.unitTitle, series: recentDailySeries)
        }
    }
}

private struct HabitOverallStatusCard: View {
    let habit: Habit
    let timelineStatus: MainPagerViewModel.GoalTimelineStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(habit.name ?? habit.kind.title)
                .font(.title2.bold())
            Text("種類: \(habit.kind.title)")
                .foregroundStyle(.secondary)
            Text("目標: \(habit.goalPerDay)\(habit.kind.unitTitle)/日")
                .foregroundStyle(.secondary)

            ProgressView(value: timelineStatus.progress)
                .tint(timelineStatus.isOverdue ? .red : .accentColor)

            Text(timelineStatus.caption)
                .font(.footnote)
                .foregroundStyle(timelineStatus.isOverdue ? .red : .secondary)
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(alignment: .leading)
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 24))
    }
}

private struct HabitTodayStatusCard: View {
    let todayCount: Int
    let goalPerDay: Int
    let unit: String
    let onTapCountUp: () -> Void
    let onTapUndo: () -> Void

    var body: some View {
        let remaining = max(goalPerDay - todayCount, 0)

        HStack {
            VStack(alignment: .leading, spacing: 10) {
                Text("今日のステータス")
                    .font(.headline)
                Text("今日: \(todayCount)\(unit) / 上限: \(goalPerDay)\(unit)")
                    .monospacedDigit()
                Text("残り: \(remaining)\(unit)")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 12) {
                Button(action: onTapCountUp) {
                    Image(systemName: "plus")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(.circle)
                
                Button(action: onTapUndo) {
                    Image(systemName: "minus")
                        .frame(width: 32, height: 32)
                }
                .tint(.red)
                .buttonStyle(.bordered)
                .clipShape(.circle)
                .disabled(todayCount == 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 24))
    }
}

private struct HabitHistoryChartCard: View {
    let unit: String
    let series: [MainPagerViewModel.DailyCountPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("過去14日")
                .font(.headline)

            Chart(series) { point in
                BarMark(
                    x: .value("日付", point.date, unit: .day),
                    y: .value("記録", point.count)
                )
                .foregroundStyle(.teal)
            }
            .chartYScale(domain: 0...(max(series.map(\.count).max() ?? 0, 5)))

            if let latest = series.last {
                Text("直近: \(latest.count)\(unit)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 24))
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
        .aspectRatio(4 / 3, contentMode: .fit)
        .clipped()
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
