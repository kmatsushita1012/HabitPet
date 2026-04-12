import Charts
import SwiftUI
import UIKit

struct MainPagerView: View {
    @State private var viewModel = MainPagerViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            ZStack {
                MainPagerTheme.pageBackground.ignoresSafeArea()

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
                                    recentDailySeries: viewModel.recentDailyCounts(for: habit, maxDays: 14),
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
            HabitHistoryChartCard(
                unit: habit.kind.unitTitle,
                goalPerDay: habit.goalPerDay,
                series: recentDailySeries
            )
        }
    }
}

private struct HabitTopStatusRow: View {
    let habit: Habit
    let totalCount: Int
    let timelineStatus: MainPagerViewModel.GoalTimelineStatus

    private let spacing: CGFloat = 12
    private let rowHeight: CGFloat = 180

    var body: some View {
        GeometryReader { proxy in
            let totalWidth = max(proxy.size.width - spacing, 0)
            let imageWidth = totalWidth * (2.0 / 3.0)
            let statusWidth = totalWidth * (1.0 / 3.0)

            HStack(alignment: .top, spacing: spacing) {
                HabitCharacterImageView(habit: habit, totalCount: totalCount)
                    .frame(width: imageWidth, height: rowHeight)
                    .clipShape(.rect(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(MainPagerTheme.cardStroke, lineWidth: 1)
                    )
                HabitOverallStatusCard(habit: habit, timelineStatus: timelineStatus)
                    .frame(width: statusWidth, height: rowHeight)
            }
            .frame(width: proxy.size.width, height: rowHeight, alignment: .leading)
        }
        .frame(height: rowHeight)
    }
}

private struct HabitOverallStatusCard: View {
    let habit: Habit
    let timelineStatus: MainPagerViewModel.GoalTimelineStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
        .background(MainPagerTheme.cardFill)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(MainPagerTheme.cardStroke, lineWidth: 1)
        )
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
        .background(MainPagerTheme.cardFill)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(MainPagerTheme.cardStroke, lineWidth: 1)
        )
        .clipShape(.rect(cornerRadius: 8))
    }
}

private struct HabitHistoryChartCard: View {
    let unit: String
    let goalPerDay: Int
    let series: [MainPagerViewModel.DailyCountPoint]

    var body: some View {
        let redLineBase = goalPerDay > 0 ? goalPerDay * 2 : 2
        let maxCount = max(series.map(\.count).max() ?? 0, redLineBase)

        VStack(alignment: .leading, spacing: 10) {
            Text("過去14日")
                .font(.headline)

            Chart(series) { point in
                BarMark(
                    x: .value("日付", point.date, unit: .day),
                    y: .value("記録", point.count)
                )
                .foregroundStyle(barColor(for: point.count))
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
        .background(MainPagerTheme.cardFill)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(MainPagerTheme.cardStroke, lineWidth: 1)
        )
        .clipShape(.rect(cornerRadius: 8))
    }

    private func barColor(for count: Int) -> Color {
        if goalPerDay <= 0 {
            if count >= 2 { return .red }
            if count == 1 { return .yellow }
            return .green
        }
        if count > goalPerDay * 2 { return .red }
        if count > goalPerDay { return .yellow }
        return .green
    }
}

private struct HabitCharacterImageView: View {
    let habit: Habit
    let totalCount: Int

    var body: some View {
        let level = habitStateLevel(forTotalCount: totalCount)
        let names = habitCharacterAssetNames(kind: habit.kind, character: habit.character, level: level)

        ZStack {
            if let image = AppCharacterImageLoader.load(named: names) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                Image(systemName: "pawprint.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(.vertical, 24)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MainPagerTheme.cardFill)
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

private enum MainPagerTheme {
    static let pageBackground = LinearGradient(
        colors: [
            Color(
                uiColor: UIColor { traits in
                    traits.userInterfaceStyle == .dark
                        ? UIColor(red: 0.16, green: 0.13, blue: 0.10, alpha: 1.0)
                        : UIColor(red: 0.94, green: 0.90, blue: 0.84, alpha: 1.0)
                }
            ),
            Color(
                uiColor: UIColor { traits in
                    traits.userInterfaceStyle == .dark
                        ? UIColor(red: 0.10, green: 0.08, blue: 0.06, alpha: 1.0)
                        : UIColor(red: 0.88, green: 0.80, blue: 0.70, alpha: 1.0)
                }
            ),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardFill = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.33, green: 0.25, blue: 0.18, alpha: 0.46)
                : UIColor(red: 0.36, green: 0.27, blue: 0.18, alpha: 0.16)
        }
    )
    static let cardStroke = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.66, green: 0.53, blue: 0.40, alpha: 0.42)
                : UIColor(red: 0.30, green: 0.23, blue: 0.16, alpha: 0.34)
        }
    )
}

#Preview {
    MainPagerView()
}
