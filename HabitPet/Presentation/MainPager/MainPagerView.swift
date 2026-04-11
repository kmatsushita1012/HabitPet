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
            .navigationTitle(viewModel.currentHabitTitle)
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
            HabitTopStatusRow(
                habit: habit,
                totalCount: totalCount,
                timelineStatus: goalTimelineStatus
            )
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

private struct HabitTopStatusRow: View {
    let habit: Habit
    let totalCount: Int
    let timelineStatus: MainPagerViewModel.GoalTimelineStatus

    private let spacing: CGFloat = 12

    var body: some View {
        GeometryReader { proxy in
            let totalWidth = max(proxy.size.width - spacing, 0)
            let imageWidth = totalWidth * (2.0 / 3.0)
            let statusWidth = totalWidth * (1.0 / 3.0)
            let rowHeight = proxy.size.height

            HStack(alignment: .top, spacing: spacing) {
                HabitCharacterImageView(habit: habit, totalCount: totalCount)
                    .frame(width: imageWidth, height: rowHeight)
                HabitOverallStatusCard(habit: habit, timelineStatus: timelineStatus)
                    .frame(width: statusWidth, height: rowHeight)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .aspectRatio(2.0, contentMode: .fit)
    }
}

private struct HabitOverallStatusCard: View {
    let habit: Habit
    let timelineStatus: MainPagerViewModel.GoalTimelineStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(habit.name ?? habit.kind.title)
                .font(.title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(habit.kind.title)
                .foregroundStyle(.secondary)

            LabeledContent("目標") {
                Text("\(habit.goalPerDay)\(habit.kind.unitTitle) / 日")
                    .monospacedDigit()
            }
            .foregroundStyle(.secondary)

            ProgressView(value: timelineStatus.progress)
                .tint(timelineStatus.isOverdue ? .red : .accentColor)

            Text(timelineStatus.caption)
                .font(.footnote)
                .foregroundStyle(timelineStatus.isOverdue ? .red : .secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 8))
    }
}

private struct HabitTodayStatusCard: View {
    let todayCount: Int
    let goalPerDay: Int
    let unit: String
    let onTapCountUp: () -> Void
    let onTapUndo: () -> Void

    @ScaledMetric(relativeTo: .body) private var controlHeight = 44.0

    var body: some View {
        let remaining = max(goalPerDay - todayCount, 0)
        let progress = goalPerDay > 0 ? min(Double(todayCount) / Double(goalPerDay), 1) : 0

        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("今日のステータス")
                    .font(.headline)
                LabeledContent("今日") {
                    Text("\(todayCount)\(unit)")
                        .monospacedDigit()
                }
                LabeledContent("残り") {
                    Text("\(remaining)\(unit)")
                        .monospacedDigit()
                }
                .foregroundStyle(.secondary)

                ProgressView(value: progress)
                    .tint(todayCount > goalPerDay ? .red : .accentColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Button(action: onTapCountUp) {
                    Label("増やす", systemImage: "plus")
                        .labelStyle(.iconOnly)
                        .frame(width: controlHeight, height: controlHeight)
                }
                .buttonStyle(.borderedProminent)

                Button(action: onTapUndo) {
                    Label("減らす", systemImage: "minus")
                        .labelStyle(.iconOnly)
                        .frame(width: controlHeight, height: controlHeight)
                }
                .tint(.red)
                .buttonStyle(.bordered)
                .disabled(todayCount == 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 8))
    }
}

private struct HabitHistoryChartCard: View {
    let unit: String
    let series: [MainPagerViewModel.DailyCountPoint]

    var body: some View {
        let maxCount = max(series.map(\.count).max() ?? 0, 1)

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
            .chartYScale(domain: 0...maxCount)
            .frame(maxWidth: .infinity)
            .aspectRatio(16.0 / 9.0, contentMode: .fit)

            if let latest = series.last {
                Text("直近: \(latest.count)\(unit)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 8))
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
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Image(systemName: "pawprint.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(.vertical, 24)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 8))
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
