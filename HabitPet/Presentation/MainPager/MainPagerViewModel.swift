import Dependencies
import Foundation
import Observation
import SQLiteData

@MainActor
@Observable
final class MainPagerViewModel {
    // UI State
    var selectedPageIndex: Int = 0
    var isEditPresented = false
    var isCreatePresented = false
    var editingHabit: Habit?
    var quickCount: Int = 0
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
    @Dependency(\.habitUseCase) private var habitUseCase

    // Action methods
    func onAppear() {
        quickCount = WidgetCountStore.currentCount()
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

    func onDismissEdit() {
        isEditPresented = false
        editingHabit = nil
    }

    func onDismissCreate() {
        isCreatePresented = false
    }

    func onTapCountUp() {
        guard !habits.isEmpty else { return }
        let safeIndex = min(max(selectedPageIndex, 0), habits.count - 1)
        let habit = habits[safeIndex]

        Task {
            do {
                try habitUseCase.recordDelta(
                    habitID: habit.id,
                    delta: 1,
                    source: .app,
                    now: Date()
                )
                quickCount = WidgetCountStore.increment()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func onTapUndoCount() {
        guard !habits.isEmpty else { return }
        let safeIndex = min(max(selectedPageIndex, 0), habits.count - 1)
        let habit = habits[safeIndex]
        guard quickCount > 0 else { return }

        Task {
            do {
                try habitUseCase.undoDelta(habitID: habit.id, count: 1, now: Date())
                quickCount = WidgetCountStore.decrement()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private enum WidgetCountStore {
    static let appGroupID = "group.com.studiomk.HabitPet"
    static let countKey = "widget_count"
    static let sharedDefaults = UserDefaults(suiteName: appGroupID) ?? .standard

    static func currentCount() -> Int {
        sharedDefaults.integer(forKey: countKey)
    }

    @discardableResult
    static func increment() -> Int {
        let newValue = currentCount() + 1
        sharedDefaults.set(newValue, forKey: countKey)
        return newValue
    }

    @discardableResult
    static func decrement() -> Int {
        let newValue = max(0, currentCount() - 1)
        sharedDefaults.set(newValue, forKey: countKey)
        return newValue
    }
}
