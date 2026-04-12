import Dependencies
import Foundation
import Observation
import WidgetKit

@MainActor
@Observable
final class HabitEditViewModel {
    // UI State
    var editingHabit: Habit?
    var selectedKind: HabitKind
    var selectedCharacter: CharacterType
    var nameInput: String
    var goalDeadline: Date
    var goalPerDayInput: String
    var yesterdayCountInput: String
    var isArchiveAlertPresented = false
    var isDeleteAlertPresented = false
    var errorMessage: String?
    var shouldDismiss = false

    @ObservationIgnored
    @Dependency(\.habitUseCase) private var habitUseCase

    @ObservationIgnored
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    @ObservationIgnored
    private let calendar = Calendar(identifier: .gregorian)

    init(habit: Habit?) {
        let initialKind = habit?.kind ?? .nonSmoking
        let availableCharacters = CharacterType.candidates(for: initialKind)
        let initialCharacter = habit?.character ?? availableCharacters.first ?? .hamster
        let resolvedCharacter = availableCharacters.contains(initialCharacter)
            ? initialCharacter
            : (availableCharacters.first ?? .hamster)
        let resolvedGoalDeadline = Self.parseGoalDeadline(
            habit?.goalDeadline,
            formatter: dateFormatter
        ) ?? Self.defaultGoalDeadline(calendar: calendar)

        editingHabit = habit
        selectedKind = initialKind
        selectedCharacter = resolvedCharacter
        nameInput = habit?.name ?? ""
        goalPerDayInput = String(habit?.goalPerDay ?? 0)
        yesterdayCountInput = ""
        goalDeadline = resolvedGoalDeadline
    }

    // Action methods
    func onAppearForCreate() {
        guard editingHabit == nil else { return }
        selectedKind = .nonSmoking
        selectedCharacter = CharacterType.candidates(for: .nonSmoking).first ?? .hamster
        nameInput = ""
        goalDeadline = Self.defaultGoalDeadline(calendar: calendar)
        goalPerDayInput = "0"
        yesterdayCountInput = ""
    }

    func onChangeKind(_ kind: HabitKind) {
        selectedKind = kind
        let candidates = CharacterType.candidates(for: kind)
        if !candidates.contains(selectedCharacter) {
            selectedCharacter = candidates.first ?? .hamster
        }
    }

    func onChangeCharacter(_ character: CharacterType) {
        selectedCharacter = character
    }

    func onChangeName(_ value: String) {
        nameInput = value
    }

    func onChangeGoalDeadline(_ date: Date) {
        goalDeadline = date
    }

    func onChangeGoalPerDay(_ value: String) {
        goalPerDayInput = value
    }

    func onChangeYesterdayCount(_ value: String) {
        yesterdayCountInput = value
    }

    func onTapSave() {
        Task {
            do {
                let goalDeadlineString = dateFormatter.string(from: goalDeadline)
                let goalPerDay = max(0, Int(goalPerDayInput) ?? 0)
                let trimmedName = nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                let normalizedName = trimmedName.isEmpty ? nil : trimmedName

                if var habit = editingHabit {
                    habit.kind = selectedKind
                    habit.character = selectedCharacter
                    habit.name = normalizedName
                    habit.goalDeadline = goalDeadlineString
                    habit.goalPerDay = goalPerDay
                    try habitUseCase.updateHabit(habit, now: Date())
                } else {
                    let draft = HabitDraft(
                        kind: selectedKind,
                        character: selectedCharacter,
                        name: normalizedName,
                        goalDeadline: goalDeadlineString,
                        goalPerDay: goalPerDay,
                        sortOrder: 0
                    )
                    let yesterdayCount = max(0, Int(yesterdayCountInput) ?? 0)
                    _ = try habitUseCase.createHabit(
                        draft,
                        yesterdayCount: yesterdayCount,
                        now: Date()
                    )
                }

                WidgetCenter.shared.reloadTimelines(ofKind: "HabitPetWidget")
                shouldDismiss = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func onTapArchive() {
        guard let editingHabit else { return }
        Task {
            do {
                try habitUseCase.archiveHabit(editingHabit, now: Date())
                WidgetCenter.shared.reloadTimelines(ofKind: "HabitPetWidget")
                shouldDismiss = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func onTapDelete() {
        guard let editingHabit else { return }
        Task {
            do {
                try habitUseCase.deleteHabit(editingHabit)
                WidgetCenter.shared.reloadTimelines(ofKind: "HabitPetWidget")
                shouldDismiss = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // Utilities
    var selectableCharacters: [CharacterType] {
        CharacterType.candidates(for: selectedKind)
    }

    private static func defaultGoalDeadline(calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    }

    private static func parseGoalDeadline(_ raw: String?, formatter: DateFormatter) -> Date? {
        guard let raw else { return nil }
        return formatter.date(from: raw)
    }
}
