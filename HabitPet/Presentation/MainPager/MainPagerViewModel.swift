import Dependencies
import Foundation
import Observation
import SQLiteData
import WidgetKit

@MainActor
@Observable
final class MainPagerViewModel {
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
}
