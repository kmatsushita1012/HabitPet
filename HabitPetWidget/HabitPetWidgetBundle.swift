import Dependencies
import SwiftUI
import WidgetKit

@main
struct HabitPetWidgetBundle: WidgetBundle {
    init() {
        prepareDependencies {
            $0.defaultDatabase = try! appDatabase()
        }
    }

    var body: some Widget {
        HabitPetWidget()
    }
}
