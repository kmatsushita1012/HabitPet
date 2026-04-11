# Repository Guidelines

## Project Structure & Module Organization
`HabitPet/` contains the iOS app UI and app entry points, with feature views under `Presentation/`. Shared domain, use case, database, and data store code lives in `Shared/`. `HabitPetWidget/` contains the widget extension. Tests are split between `HabitPetTests/` for unit-level coverage and `HabitPetUITests/` for launch and UI flows. Design notes and asset conventions live in `docs/`, and source images live in `images/`.

## Build, Test, and Development Commands
Run commands from the repo root.

- `xcodebuild -project HabitPet.xcodeproj -scheme HabitPet build`  
  Builds the main app target.
- `xcodebuild -project HabitPet.xcodeproj -scheme HabitPetTests test`  
  Runs the Swift Testing unit target.
- `xcodebuild -project HabitPet.xcodeproj -scheme HabitPetUITests test`  
  Runs UI tests with XCTest.
- `xcodebuild -list -project HabitPet.xcodeproj`  
  Lists shared schemes and targets before scripting.

For local iteration, open `HabitPet.xcodeproj` in Xcode and run the `HabitPet` scheme on an iPhone simulator.

## Coding Style & Naming Conventions
This is a SwiftUI-first codebase. Follow existing Swift conventions: 4-space indentation, one top-level type per file, and `UpperCamelCase` for types with `lowerCamelCase` for properties and methods. Keep feature files grouped by screen, for example `HabitPet/Presentation/HabitEdit/HabitEditView.swift` and `HabitEditViewModel.swift`. Reuse the current layering: View/ViewModel in `HabitPet/Presentation`, business logic in `Shared/UseCase`, persistence in `Shared/Infrastructure` and `Shared/Database`.

## Testing Guidelines
`HabitPetTests` uses `import Testing`; prefer focused `@Test` cases for use cases, view models, and persistence behavior. `HabitPetUITests` uses XCTest for launch and interaction coverage. Name tests after the behavior they verify, for example `testLaunchPerformance()` or `@Test func createsHabit()`. Add tests for new logic in `Shared/` and for any user-visible workflow changes.

## Commit & Pull Request Guidelines
Recent history uses short, imperative commit subjects such as `Implement #2` and `docs: update design.md`. Keep commits scoped and readable; use prefixes like `docs:` when the change is documentation-only. PRs should include a brief summary, linked issue or task number, test notes, and screenshots for UI changes.

## Agent-Specific Instructions
Inspect before editing, make the smallest safe change, and avoid destructive git operations. Run git commands from the repo root only; do not use `git -C`.
