import Dependencies
import Foundation
import Observation
import SQLiteData
import WidgetKit

@MainActor
@Observable
final class MainPagerViewModel {
    struct DailyCountPoint: Sendable, Identifiable {
        var id: Date { date }
        let date: Date
        let count: Int
    }

    struct GoalTimelineStatus: Sendable {
        let progress: Double
        let caption: String
        let isOverdue: Bool
    }

    // UI State
    var selectedPageIndex: Int = 0
    var isEditPresented = false
    var isCreatePresented = false
    var editingHabit: Habit?
    var errorMessage: String?

    // Entity State
    @ObservationIgnored
    @FetchAll(
        Habit
            .where { $0.isArchived.eq(false) }
            .order { $0.sortOrder.asc() }
    )
    var habits

    @ObservationIgnored
    @FetchAll(
        HabitEvent.all
    )
    var activeEvents

    @ObservationIgnored
    @Dependency(\.habitUseCase) private var habitUseCase

    // Action methods
    func onAppear() {
        reloadData()
    }

    func onAppDidBecomeActive() {
        reloadData()
    }

    func onPageChanged(_ index: Int) {
        selectedPageIndex = index
    }

    func onTapEdit() {
        guard !habits.isEmpty else { return }
        let safeIndex = min(max(selectedPageIndex, 0), habits.count - 1)
        editingHabit = habits[safeIndex]
        isEditPresented = true
    }

    func onTapAddPage() {
        editingHabit = nil
        isCreatePresented = true
    }

    func onTapPreviousPage() {
        guard canMoveToPreviousPage else { return }
        selectedPageIndex -= 1
    }

    func onTapNextPage() {
        guard canMoveToNextPage else { return }
        selectedPageIndex += 1
    }

    func onDismissEdit() {
        isEditPresented = false
        editingHabit = nil
    }

    func onDismissCreate() {
        isCreatePresented = false
    }

    func onTapCountUp() {
        guard let habit = selectedHabit else { return }

        Task {
            do {
                try habitUseCase.recordDelta(
                    habitID: habit.id,
                    delta: 1,
                    source: .app,
                    now: Date()
                )
                try await $activeEvents.load()
                WidgetCenter.shared.reloadTimelines(ofKind: "HabitPetWidget")
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func onTapUndoCount() {
        guard let habit = selectedHabit else { return }
        guard selectedHabitTotalCount > 0 else { return }

        Task {
            do {
                try habitUseCase.undoDelta(habitID: habit.id, count: 1, now: Date())
                try await $activeEvents.load()
                WidgetCenter.shared.reloadTimelines(ofKind: "HabitPetWidget")
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // Utilities
    var selectedHabitTotalCount: Int {
        guard let habitID = selectedHabit?.id else { return 0 }
        return totalCount(for: habitID)
    }

    var canMoveToPreviousPage: Bool {
        selectedPageIndex > 0
    }

    var canMoveToNextPage: Bool {
        !habits.isEmpty && selectedPageIndex < habits.count - 1
    }

    var currentHabitTitle: String {
        guard let habit = selectedHabit else { return "HabitPet" }
        return habit.name ?? habit.kind.title
    }

    func todayCount(for habitID: Habit.ID) -> Int {
        let calendar = Calendar.current
        return activeEvents
            .filter {
                $0.habitID == habitID &&
                $0.revokedAt == nil &&
                calendar.isDateInToday($0.occurredAt)
            }
            .reduce(into: 0) { partialResult, event in
                partialResult += event.delta
            }
    }

    func recentDailyCounts(for habitID: Habit.ID, days: Int) -> [DailyCountPoint] {
        guard days > 0 else { return [] }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: today) else {
            return []
        }

        var dailyMap: [Date: Int] = [:]
        for event in activeEvents where event.habitID == habitID && event.revokedAt == nil {
            let day = calendar.startOfDay(for: event.occurredAt)
            guard day >= startDate && day <= today else { continue }
            dailyMap[day, default: 0] += event.delta
        }

        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { return nil }
            return DailyCountPoint(date: date, count: dailyMap[date, default: 0])
        }
    }

    func goalTimelineStatus(for habit: Habit) -> GoalTimelineStatus {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let deadline = Self.goalDeadlineFormatter.date(from: habit.goalDeadline) else {
            return GoalTimelineStatus(progress: 0, caption: "目標日を確認できません", isOverdue: false)
        }

        let deadlineDay = calendar.startOfDay(for: deadline)
        let startDay = calendar.startOfDay(for: habit.createdAt)
        let totalDays = max(calendar.dateComponents([.day], from: startDay, to: deadlineDay).day ?? 0, 1)
        let elapsedDays = max(calendar.dateComponents([.day], from: startDay, to: today).day ?? 0, 0)
        let remainingDays = calendar.dateComponents([.day], from: today, to: deadlineDay).day ?? 0
        let progress = min(max(Double(elapsedDays) / Double(totalDays), 0), 1)
        let isOverdue = today > deadlineDay

        let caption: String
        if isOverdue {
            caption = "目標日を過ぎています"
        } else if remainingDays == 0 {
            caption = "目標日まであと0日"
        } else {
            caption = "目標日まであと\(remainingDays)日"
        }

        return GoalTimelineStatus(progress: progress, caption: caption, isOverdue: isOverdue)
    }

    func totalCount(for habitID: Habit.ID) -> Int {
        activeEvents
            .filter { $0.habitID == habitID && $0.revokedAt == nil }
            .reduce(into: 0) { partialResult, event in
                partialResult += event.delta
            }
    }

    private var selectedHabit: Habit? {
        guard !habits.isEmpty else { return nil }
        let safeIndex = min(max(selectedPageIndex, 0), habits.count - 1)
        return habits[safeIndex]
    }

    private func reloadData() {
        Task {
            try await loadEntities()
        }
    }

    private func loadEntities() async throws {
        try await $habits.load()
        try await $activeEvents.load()
    }

    private static let goalDeadlineFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
