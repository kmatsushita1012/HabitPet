import Observation
import SQLiteData

@MainActor
@Observable
final class MainPagerViewModel {
    // UI State
    var selectedPageIndex: Int = 0
    var isEditPresented = false
    var isCreatePresented = false

    // Entity State
    @ObservationIgnored
    @FetchAll(
        Habit
            .where { $0.isArchived.eq(false) }
            .order { $0.sortOrder.asc() }
    )
    var habits

    // Action methods
    func onAppear() {}

    func onPageChanged(_ index: Int) {
        selectedPageIndex = index
    }

    func onTapEdit() {
        isEditPresented = true
    }

    func onTapAddPage() {
        isCreatePresented = true
    }
}
