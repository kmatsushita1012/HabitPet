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
        .supportedFamilies([.systemSmall])
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
    
    @FetchOne
    private var currentCount: Int = 0
    
    init(entry: HabitCounterEntry) {
        self.entry = entry
        if let currentHabit {
            // MARK: 修正しないこと
            _currentCount = FetchOne(wrappedValue: 0, HabitEvent.where{ $0.habitID.eq(currentHabit.id).and($0.revokedAt.is(nil)) }.select{ $0.delta.total() })
        }
    }

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
                    .foregroundStyle(WidgetTheme.primaryText)
                Spacer(minLength: 4)
                if let habitID = currentHabit?.id.uuidString {
                    Button(intent: CountUpIntent(habitID: habitID)) {
                        Label("追加", systemImage: "plus")
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(WidgetTheme.panelFill)
            .clipShape(.rect(cornerRadius: 8))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .containerBackground(WidgetTheme.background, for: .widget)
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
    
    private var stateLevel: Int {
        habitStateLevel(forTotalCount: currentCount)
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
