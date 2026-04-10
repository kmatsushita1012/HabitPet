import AppIntents
import SwiftUI
import UIKit
import WidgetKit

private struct HabitCounterEntry: TimelineEntry {
    let date: Date
    let count: Int
}

private struct HabitCounterProvider: TimelineProvider {
    func placeholder(in context: Context) -> HabitCounterEntry {
        HabitCounterEntry(date: .now, count: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (HabitCounterEntry) -> Void) {
        completion(HabitCounterEntry(date: .now, count: WidgetCountStore.currentCount()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitCounterEntry>) -> Void) {
        let entry = HabitCounterEntry(date: .now, count: WidgetCountStore.currentCount())
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                characterImage
                    .resizable()
                    .scaledToFit()
                Spacer()
            }
            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Text("\(entry.count)本")
                    .font(.callout.bold())
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 6)
                Button(intent: CountUpIntent()) {
                    Text("+")
                        .font(.caption.bold())
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var characterImage: Image {
        let name = "character_hamster_lv\(stateLevel)"
        if let uiImage = WidgetCharacterImageLoader.load(named: name) {
            return Image(uiImage: uiImage)
        } else {
            return Image(systemName: "pawprint.fill")
        }
    }

    private var stateLevel: Int {
        switch entry.count {
        case ..<5:
            return 1
        case ..<10:
            return 2
        case ..<20:
            return 3
        case ..<30:
            return 4
        default:
            return 5
        }
    }
}

private enum WidgetCharacterImageLoader {
    static func load(named name: String) -> UIImage? {
        if let image = UIImage(named: name, in: .main, compatibleWith: nil) {
            return image
        }

        let appBundleURL = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        if let appBundle = Bundle(url: appBundleURL),
           let image = UIImage(named: name, in: appBundle, compatibleWith: nil) {
            return image
        }
        return nil
    }
}

struct CountUpIntent: AppIntent {
    static var title: LocalizedStringResource = "カウントを1増やす"

    func perform() async throws -> some IntentResult {
        _ = WidgetCountStore.increment()
        WidgetCenter.shared.reloadTimelines(ofKind: "HabitPetWidget")
        return .result()
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
}
