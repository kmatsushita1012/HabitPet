import AppIntents
import SQLiteData
import SwiftUI
import UIKit
import WidgetKit

private struct HabitCounterEntry: TimelineEntry {
    let date: Date
    let selectedHabitID: String?
}

struct HabitWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "表示する習慣"
    static var description = IntentDescription("ウィジェットで表示する習慣を選択します。")

    @Parameter(title: "習慣")
    var habit: HabitEntity?
}

struct HabitEntity: AppEntity, Identifiable {
    typealias ID = String

    let id: String
    let title: String

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "習慣")
    static var defaultQuery = HabitEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

struct HabitEntityQuery: EntityQuery {
    func entities(for identifiers: [HabitEntity.ID]) async throws -> [HabitEntity] {
        let habits = fetchActiveHabits()
        let map = Dictionary(uniqueKeysWithValues: habits.map { ($0.id.uuidString, $0) })
        return identifiers.compactMap { id in
            guard let habit = map[id] else { return nil }
            return HabitEntity(id: id, title: habit.name ?? habit.kind.title)
        }
    }

    func suggestedEntities() async throws -> [HabitEntity] {
        fetchActiveHabits().map { habit in
            HabitEntity(
                id: habit.id.uuidString,
                title: habit.name ?? habit.kind.title
            )
        }
    }

    private func fetchActiveHabits() -> [Habit] {
        do {
            let database = try appDatabase()
            return try database.read { db in
                try Habit
                    .where { $0.isArchived.eq(false) }
                    .order { $0.sortOrder.asc() }
                    .fetchAll(db)
            }
        } catch {
            return []
        }
    }
}

private struct HabitCounterProvider: AppIntentTimelineProvider {
    typealias Intent = HabitWidgetConfigurationIntent

    func placeholder(in context: Context) -> HabitCounterEntry {
        HabitCounterEntry(date: .now, selectedHabitID: nil)
    }

    func snapshot(for configuration: HabitWidgetConfigurationIntent, in context: Context) async -> HabitCounterEntry {
        HabitCounterEntry(
            date: .now,
            selectedHabitID: configuration.habit?.id
        )
    }

    func timeline(for configuration: HabitWidgetConfigurationIntent, in context: Context) async -> Timeline<HabitCounterEntry> {
        let entry = HabitCounterEntry(
            date: .now,
            selectedHabitID: configuration.habit?.id
        )
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(15 * 60)))
    }
}

struct HabitPetWidget: Widget {
    private let kind = "HabitPetWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: HabitWidgetConfigurationIntent.self, provider: HabitCounterProvider()) { entry in
            HabitPetWidgetView(entry: entry)
        }
        .configurationDisplayName("HabitPet カウンター")
        .description("今日のカウントをホーム画面から記録できます。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct HabitPetWidgetView: View {
    let entry: HabitCounterEntry

    @FetchAll(
        Habit
            .where { $0.isArchived.eq(false) }
            .order { $0.sortOrder.asc() }
    )
    private var habits

    @FetchAll(
        HabitEvent.all
    )
    private var activeEvents
    
    init(entry: HabitCounterEntry) {
        self.entry = entry
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            characterImage
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 72)
                .clipShape(.rect(cornerRadius: 8))

            HStack(spacing: 0) {
                if let habit = currentHabit {
                    VStack(alignment: .leading) {
                        Text(habit.kind.title)
                            .font(.callout.bold())
                            .lineLimit(1)
                        HStack {
                            Text("今日")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(currentCount)\(habit.kind.unitTitle)")
                                .font(.callout.bold())
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .foregroundStyle(WidgetTheme.primaryText)
                        }
                    }
                    Spacer(minLength: 0)
                    Button(intent: CountUpIntent(habitID: habit.id.uuidString)) {
                        Label("追加", systemImage: "plus")
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                } else {
                    Text("新しい習慣を作りましょう")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(WidgetTheme.panelFill)
            .clipShape(.rect(cornerRadius: 8))
        }
        .containerBackground(WidgetTheme.background, for: .widget)
        .widgetURL(openAppURL)
        // MARK: Widgetの余白は元から広いためpaddingはつけない
    }

    private var openAppURL: URL? {
        guard let habitID = currentHabit?.id.uuidString else { return URL(string: "habitpet://main") }
        return URL(string: "habitpet://habit?id=\(habitID)")
    }

    private var characterImage: Image {
        guard let habit = currentHabit else {
            return Image(systemName: "pawprint.fill")
        }
        let names = habitCharacterAssetNames(kind: habit.kind, character: habit.character, level: stateLevel)
        if let uiImage = WidgetCharacterImageLoader.load(named: names) {
            return Image(uiImage: uiImage)
        } else {
            return Image(systemName: "pawprint.fill")
        }
    }

    private var currentHabit: Habit? {
        if let selectedHabitID = entry.selectedHabitID,
           let selectedUUID = UUID(uuidString: selectedHabitID),
           let selected = habits.first(where: { $0.id == selectedUUID }) {
            return selected
        }
        return habits.first
    }
    
    private var stateLevel: Int {
        habitStateLevel(forTotalCount: currentCount)
    }

    private var currentCount: Int {
        guard let habitID = currentHabit?.id else { return 0 }
        return activeEvents
            .filter { $0.habitID == habitID && $0.revokedAt == nil }
            .reduce(into: 0) { partialResult, event in
                partialResult += event.delta
            }
    }
}

private enum WidgetTheme {
    static let background = LinearGradient(
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

    static let panelFill = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.33, green: 0.25, blue: 0.18, alpha: 0.46)
                : UIColor(red: 0.36, green: 0.27, blue: 0.18, alpha: 0.16)
        }
    )

    static let primaryText = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1.0)
                : UIColor.label
        }
    )
}

private enum WidgetCharacterImageLoader {
    static func load(named names: [String]) -> UIImage? {
        for name in names {
            if let image = UIImage(named: name, in: .main, compatibleWith: nil) {
                return image
            }
        }

        let appBundleURL = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        if let appBundle = Bundle(url: appBundleURL) {
            for name in names {
                if let image = UIImage(named: name, in: appBundle, compatibleWith: nil) {
                    return image
                }
            }
        }
        return nil
    }
}

struct CountUpIntent: AppIntent {
    static var title: LocalizedStringResource = "カウントを1増やす"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Habit ID")
    var habitID: String

    init() {
        self.habitID = ""
    }

    init(habitID: String) {
        self.habitID = habitID
    }

    func perform() async throws -> some IntentResult {
        guard let parsedHabitID = UUID(uuidString: habitID) else {
            return .result()
        }

        prepareDependencies {
            $0.defaultDatabase = try! appDatabase()
        }

        let useCase = HabitUseCase()
        try useCase.recordDelta(
            habitID: parsedHabitID,
            delta: 1,
            source: .widget,
            now: Date()
        )
        WidgetCenter.shared.reloadTimelines(ofKind: "HabitPetWidget")
        return .result()
    }
}
