//
//  HabitPetApp.swift
//  HabitPet
//
//  Created by 松下和也 on 2026/04/06.
//

import Dependencies
import SQLiteData
import SwiftUI

@main
struct HabitPetApp: App {
    init() {
        prepareDependencies {
            $0.defaultDatabase = try! appDatabase()
        }
    }

    var body: some Scene {
        WindowGroup {
            MainPagerView()
                .tint(.green)
        }
    }
}
