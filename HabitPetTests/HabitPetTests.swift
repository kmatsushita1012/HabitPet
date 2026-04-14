//
//  HabitPetTests.swift
//  HabitPetTests
//
//  Created by 松下和也 on 2026/04/06.
//

import Testing
@testable import HabitPet

struct HabitPetTests {

    @Test func dayScoreWithGoal() async throws {
        #expect(habitDayScore(count: 0, goalPerDay: 3) == 0)
        #expect(habitDayScore(count: 2, goalPerDay: 3) == 0)
        #expect(habitDayScore(count: 4, goalPerDay: 3) == 2)
        #expect(habitDayScore(count: 6, goalPerDay: 3) == 3)
    }

    @Test func dayScoreWithoutGoal() async throws {
        #expect(habitDayScore(count: 0, goalPerDay: 0) == 0)
        #expect(habitDayScore(count: 1, goalPerDay: 0) == 1.5)
        #expect(habitDayScore(count: 2, goalPerDay: 0) == 2.5)
        #expect(habitDayScore(count: 3, goalPerDay: 0) == 3)
    }

    @Test func levelBoundaries() async throws {
        #expect(habitStateLevel(goalPerDay: 3, recentDailyCounts: [0, 0, 0, 0, 0, 0, 0]) == 1)
        #expect(habitStateLevel(goalPerDay: 3, recentDailyCounts: [1, 1, 1, 1, 1, 1, 1]) == 1)
        #expect(habitStateLevel(goalPerDay: 3, recentDailyCounts: [7, 7, 7, 7, 7, 7, 7]) == 5)
    }

    @Test func levelThresholdsRevised() async throws {
        // score = 0.526... -> Lv2
        #expect(habitStateLevel(goalPerDay: 3, recentDailyCounts: [4, 0, 0, 0, 0, 0, 0]) == 2)
        // score = 0.947... -> Lv3
        #expect(habitStateLevel(goalPerDay: 3, recentDailyCounts: [4, 4, 0, 0, 0, 0, 0]) == 3)
        // score = 1.526... -> Lv4
        #expect(habitStateLevel(goalPerDay: 3, recentDailyCounts: [4, 4, 4, 4, 0, 0, 0]) == 4)
        // score = 2.289... -> Lv5
        #expect(habitStateLevel(goalPerDay: 3, recentDailyCounts: [6, 6, 6, 6, 0, 0, 0]) == 5)
    }

    @Test func boundaryScoreOfZeroIsLevel1() async throws {
        // All days within goal should remain completely safe.
        #expect(habitStateLevel(goalPerDay: 3, recentDailyCounts: [3, 3, 3, 3, 3, 3, 3]) == 1)
    }

    @Test func boundaryScoreOfPointSevenIsLevel2() async throws {
        // 2.66 / 3.8 = 0.70
        let score = habitWeeklyScore(goalPerDay: 3, recentDailyCounts: [4, 4, 0, 0, 0, 1, 0])
        #expect(abs(score - 0.70) < 0.000_001)
        #expect(habitStateLevel(goalPerDay: 3, recentDailyCounts: [4, 4, 0, 0, 0, 1, 0]) == 2)
    }

}
