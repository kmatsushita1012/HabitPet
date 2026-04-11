import Dependencies
import Foundation
import Observation

@MainActor
@Observable
final class HabitEditViewModel {
    // UI State
    var editingHabit: Habit?
    var nameInput: String
    var selectedMode: HabitMode
    var selectedCharacterID: String
    var baselineInput: String
    var goalType: HabitGoalType
    var goalValueInput: String
    var goalDate: Date?
    var isArchiveAlertPresented = false
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

    init(habit: Habit?) {
        editingHabit = habit
        nameInput = habit?.name ?? ""
        selectedMode = habit?.mode ?? .avoid
        selectedCharacterID = habit?.characterID ?? "hamster"
        baselineInput = habit?.baselineManualValue.map { String($0) } ?? ""
        goalType = habit?.goalType ?? .none
        goalValueInput = habit?.goalValue.map { String($0) } ?? ""
        goalDate = habit?.goalDate.flatMap { dateFormatter.date(from: $0) }
    }

    // Action methods
    func onAppearForCreate() {
        guard editingHabit == nil else { return }
        nameInput = ""
        selectedMode = .avoid
        selectedCharacterID = "hamster"
        baselineInput = ""
        goalType = .none
        goalValueInput = ""
        goalDate = nil
    }

    func onChangeName(_ value: String) {
        nameInput = value
    }

    func onChangeMode(_ mode: HabitMode) {
        selectedMode = mode
    }

    func onChangeCharacter(_ characterID: String) {
        selectedCharacterID = characterID
    }

    func onChangeBaseline(_ value: String) {
        baselineInput = value
    }

    func onChangeGoalType(_ type: HabitGoalType) {
        goalType = type
        switch type {
        case .none:
            goalValueInput = ""
            goalDate = nil
        case .count:
            goalDate = nil
        case .date:
            goalValueInput = ""
            if goalDate == nil {
                goalDate = Date()
            }
        }
    }

    func onChangeGoalValue(_ value: String) {
        goalValueInput = value
    }

    func onChangeGoalDate(_ date: Date?) {
        goalDate = date
    }

    func onTapSave() {
        Task {
            do {
                let goalDateString = goalDate.map { dateFormatter.string(from: $0) }
                let baselineValue = Double(baselineInput)
                let goalValue = Int(goalValueInput)
                let normalizedGoalValue: Int?
                let normalizedGoalDate: String?
                switch goalType {
                case .none:
                    normalizedGoalValue = nil
                    normalizedGoalDate = nil
                case .count:
                    normalizedGoalValue = goalValue
                    normalizedGoalDate = nil
                case .date:
                    normalizedGoalValue = nil
                    normalizedGoalDate = goalDateString
                }

                if var habit = editingHabit {
                    habit.name = nameInput
                    habit.mode = selectedMode
                    habit.characterID = selectedCharacterID
                    habit.countUnit = .count
                    habit.baselineSource = .manual
                    habit.baselineManualValue = baselineValue
                    habit.goalType = goalType
                    habit.goalValue = normalizedGoalValue
                    habit.goalDate = normalizedGoalDate
                    try habitUseCase.updateHabit(habit, now: Date())
                } else {
                    let draft = HabitDraft(
                        name: nameInput,
                        mode: selectedMode,
                        characterID: selectedCharacterID,
                        countUnit: .count,
                        baselineSource: .manual,
                        baselineManualValue: baselineValue,
                        goalType: goalType,
                        goalValue: normalizedGoalValue,
                        goalDate: normalizedGoalDate,
                        sortOrder: 0
                    )
                    _ = try habitUseCase.createHabit(draft, now: Date())
                }

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
                shouldDismiss = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
