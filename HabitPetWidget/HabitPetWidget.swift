import AppIntents
import SQLiteData
import SwiftUI
import UIKit
import WidgetKit

private struct HabitCounterEntry: TimelineEntry {
    let date: Date
}

private struct HabitCounterProvider: TimelineProvider {
    func placeholder(in context: Context) -> HabitCounterEntry {
        HabitCounterEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (HabitCounterEntry) -> Void) {
        completion(HabitCounterEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitCounterEntry>) -> Void) {
        let entry = HabitCounterEntry(date: .now)
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(15 * 60))))
    }
}

struct HabitPetWidget: Widget {
    private let kind = "HabitPetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HabitCounterProvider()) { entry in
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                characterImage
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 72)
                Spacer()
            }
            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Text("\(currentCount)\(currentHabit?.kind.unitTitle ?? "回")")
                    .font(.callout.bold())
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                if let habitID = currentHabit?.id.uuidString {
                    Button(intent: CountUpIntent(habitID: habitID)) {
                        Label("追加", systemImage: "plus")
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .containerBackground(.fill.tertiary, for: .widget)
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
        habits.first
    }

    private var currentCount: Int {
        guard let habitID = currentHabit?.id else { return 0 }
        return activeEvents
            .filter { $0.habitID == habitID && $0.revokedAt == nil }
            .reduce(into: 0) { partialResult, event in
                partialResult += event.delta
            }
    }
    
    private var stateLevel: Int {
        habitStateLevel(forTotalCount: currentCount)
    }
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
